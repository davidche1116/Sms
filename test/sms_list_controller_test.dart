import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sms/controllers/sms_list_controller.dart';
import 'package:sms/l10n/generated/app_localizations_en.dart';
import 'package:sms_advanced/sms_advanced.dart';

const MethodChannel permissionChannel = MethodChannel(
  'flutter.baseflow.com/permissions/methods',
);
const MethodChannel queryChannel = MethodChannel(
  'plugins.elyudde.com/querySMS',
  JSONMethodCodec(),
);
const MethodChannel appChannel = MethodChannel('com.dc16.sms/smsApp');
const MethodChannel removeChannel = MethodChannel('elyudde.sms.remove.channel');

/// 两条带 id/threadId 的短信，供查询 mock 返回。
const List<Map<String, dynamic>> twoMessages = <Map<String, dynamic>>[
  <String, dynamic>{
    '_id': 1,
    'thread_id': 10,
    'address': '10086',
    'body': 'first',
    'sub_id': 0,
    'read': 1,
    'date': 1789000000000,
    'date_sent': 1789000000000,
  },
  <String, dynamic>{
    '_id': 2,
    'thread_id': 20,
    'address': '10010',
    'body': 'second',
    'sub_id': 1,
    'read': 1,
    'date': 1789000001000,
    'date_sent': 1789000001000,
  },
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> messages;
  late SmsListController controller;

  void setChannelHandler(
    MethodChannel channel,
    Future<dynamic> Function(MethodCall)? handler,
  ) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, handler);
  }

  /// 权限已授权 + 查询返回 twoMessages。
  void mockGrantedQuery({Object? queryResult}) {
    setChannelHandler(permissionChannel, (MethodCall call) async => 1);
    setChannelHandler(queryChannel, (MethodCall call) async {
      if (queryResult != null) throw queryResult;
      // 回退路径会按 Inbox/Sent/Draft 各查一次；只在收件箱返回数据，
      // 保证列表长度可预期。
      return call.method == 'getInbox' ? twoMessages : <Map<String, dynamic>>[];
    });
    // 原生 querySms 未注册时 MissingPluginException → 回退插件。
    setChannelHandler(appChannel, (MethodCall call) async {
      if (call.method == 'querySms') {
        throw MissingPluginException('querySms');
      }
      return null;
    });
  }

  setUp(() {
    messages = <String>[];
    controller = SmsListController(
      l10n: AppLocalizationsEn(),
      onMessage: messages.add,
    );
    mockGrantedQuery();
  });

  tearDown(() {
    controller.dispose();
    for (final MethodChannel channel in <MethodChannel>[
      permissionChannel,
      queryChannel,
      appChannel,
      removeChannel,
    ]) {
      setChannelHandler(channel, null);
    }
  });

  group('queryAll', () {
    test('查询成功：列表填充且加载态复位', () async {
      await controller.queryAll();

      expect(controller.count, 2);
      expect(controller.loading.value, false);
      expect(controller.messages.value.first.id, 2); // 按日期降序
    });

    test('平台查询失败：列表清空、加载态复位并给出提示', () async {
      mockGrantedQuery(queryResult: PlatformException(code: 'boom'));

      await controller.queryAll();

      expect(controller.isEmpty, true);
      expect(controller.loading.value, false);
      expect(messages, contains('Operation Failed'));
    });

    test('无权限且查询为空时提示权限缺失', () async {
      // 回归：掉默认短信后部分 ROM 会把 Permission.sms 误报为拒绝。
      // 查询仍会执行；空结果 + 未授权才提示权限，而不是直接跳过查询。
      setChannelHandler(permissionChannel, (MethodCall call) async => 0);
      setChannelHandler(appChannel, (MethodCall call) async {
        if (call.method == 'querySms') {
          throw MissingPluginException('querySms');
        }
        return null;
      });
      setChannelHandler(queryChannel, (MethodCall call) async {
        return <Map<String, dynamic>>[];
      });

      await controller.queryAll();

      expect(controller.isEmpty, true);
      expect(controller.loading.value, false);
      expect(messages.first, contains('permission'));
    });

    test('权限状态误报为拒绝时仍能读出短信', () async {
      // 核心回归：READ_SMS 可用但 Permission.sms.isGranted 为 false，
      // 不得因此跳过查询导致"有权限却读不到短信"。
      setChannelHandler(appChannel, (MethodCall call) async {
        if (call.method == 'querySms') {
          throw MissingPluginException('querySms');
        }
        return null;
      });
      setChannelHandler(queryChannel, (MethodCall call) async {
        return call.method == 'getInbox'
            ? twoMessages
            : <Map<String, dynamic>>[];
      });
      setChannelHandler(permissionChannel, (MethodCall call) async => 0);

      await controller.queryAll();

      expect(controller.count, 2);
      expect(messages, isEmpty);
    });

    test('原生 querySms 返回数据时直接使用', () async {
      setChannelHandler(appChannel, (MethodCall call) async {
        if (call.method == 'querySms') {
          return <String, dynamic>{'messages': twoMessages, 'error': null};
        }
        return null;
      });

      await controller.queryAll();

      expect(controller.count, 2);
    });

    test('原生 querySms 返回 permission 时提示权限', () async {
      setChannelHandler(appChannel, (MethodCall call) async {
        if (call.method == 'querySms') {
          return <String, dynamic>{
            'messages': <dynamic>[],
            'error': 'permission',
          };
        }
        return null;
      });

      await controller.queryAll();

      expect(controller.isEmpty, true);
      expect(messages.first, contains('permission'));
    });
  });

  group('removeFromList', () {
    test('返回原下标并缩短列表，不在列表中的项返回 -1', () async {
      await controller.queryAll();
      final SmsMessage target = controller.messages.value.first;

      expect(controller.removeFromList(target), 0);
      expect(controller.count, 1);
      expect(controller.removeFromList(target), -1);
    });
  });

  group('deleteAll', () {
    test('优先走原生批量删除', () async {
      await controller.queryAll();
      int removeCalls = 0;
      setChannelHandler(appChannel, (MethodCall call) async {
        expect(call.method, 'deleteSmsBatch');
        return 2;
      });
      setChannelHandler(removeChannel, (MethodCall call) async {
        removeCalls++;
        return true;
      });

      final int failed = await controller.deleteAll();

      expect(failed, 0);
      // 批量路径不应再触发逐条删除。
      expect(removeCalls, 0);
    });

    test('原生批量返回 null 时回退逐条删除', () async {
      await controller.queryAll();
      int removeCalls = 0;
      setChannelHandler(appChannel, (MethodCall call) async => null);
      setChannelHandler(removeChannel, (MethodCall call) async {
        removeCalls++;
        return true;
      });

      final int failed = await controller.deleteAll();

      expect(failed, 0);
      expect(removeCalls, 2);
    });

    test('回退路径响应取消，停止后续删除', () async {
      await controller.queryAll();
      int removeCalls = 0;
      setChannelHandler(appChannel, (MethodCall call) async => null);
      setChannelHandler(removeChannel, (MethodCall call) async {
        removeCalls++;
        return true;
      });

      final int failed = await controller.deleteAll(
        shouldCancel: () => removeCalls >= 1,
      );

      expect(failed, 0);
      expect(removeCalls, 1);
    });

    test('缺 id 的条目计入失败而不是崩溃', () async {
      await controller.queryAll();
      // 手工塞入一条无 id 的短信。
      controller.messages.value = <SmsMessage>[
        ...controller.messages.value,
        SmsMessage('10000', 'no id'),
      ];
      setChannelHandler(appChannel, (MethodCall call) async => 2);

      // 无 id 的一条计入失败，两条正常删除。
      expect(await controller.deleteAll(), 1);
    });

    test('删除条数与快照不一致时按差值计入失败', () async {
      await controller.queryAll();
      setChannelHandler(appChannel, (MethodCall call) async => 1);

      // 提交 2 条，只删掉 1 条。
      expect(await controller.deleteAll(), 1);
    });
  });

  group('ensureDefaultSmsApp', () {
    test('无法判定时拦截并提示操作失败，不误报"非默认"', () async {
      setChannelHandler(appChannel, (MethodCall call) async => '');

      expect(await controller.ensureDefaultSmsApp(), false);
      expect(messages, contains('Operation Failed'));
    });

    test('明确非默认时提示去设置页', () async {
      setChannelHandler(appChannel, (MethodCall call) async {
        return 'com.android.mms';
      });

      expect(await controller.ensureDefaultSmsApp(), false);
      expect(messages.first, contains('default SMS app'));
    });
  });

  group('selection', () {
    test('enterSelectionMode 进入多选并清空旧选择', () async {
      await controller.queryAll();
      final SmsMessage first = controller.messages.value.first;
      final SmsMessage second = controller.messages.value.last;

      controller.enterSelectionMode(first);
      expect(controller.selectionMode, true);
      expect(controller.selectedCount, 1);
      expect(controller.isSelected(first), true);

      controller.enterSelectionMode(second);
      // 重新进入应清空此前选择，只保留新传入的条目。
      expect(controller.selectedCount, 1);
      expect(controller.isSelected(first), false);
      expect(controller.isSelected(second), true);
    });

    test('toggleSelection 切换选中态', () async {
      await controller.queryAll();
      final SmsMessage first = controller.messages.value.first;

      controller.enterSelectionMode();
      expect(controller.selectedCount, 0);

      controller.toggleSelection(first);
      expect(controller.isSelected(first), true);
      controller.toggleSelection(first);
      expect(controller.isSelected(first), false);
    });

    test('selectAll 选中当前列表全部', () async {
      await controller.queryAll();
      controller.enterSelectionMode();

      controller.selectAll();

      expect(controller.selectedCount, controller.count);
      expect(controller.messages.value.every(controller.isSelected), true);
    });

    test('exitSelectionMode 退出多选并清空选择', () async {
      await controller.queryAll();
      final SmsMessage first = controller.messages.value.first;
      controller.enterSelectionMode(first);

      controller.exitSelectionMode();

      expect(controller.selectionMode, false);
      expect(controller.selectedCount, 0);
      expect(controller.isSelected(first), false);
    });

    test('整表刷新（查询）后退出多选模式，避免选中"看不见"的条目', () async {
      await controller.queryAll();
      final SmsMessage first = controller.messages.value.first;
      controller.enterSelectionMode(first);

      // 任意一次查询都会触发 _replaceAll，应退出多选模式。
      await controller.querySameAddress(first);

      expect(controller.selectionMode, false);
      expect(controller.selectedCount, 0);
    });

    test('deleteSelected 只删除已选、走原生批量删除', () async {
      await controller.queryAll();
      final SmsMessage first = controller.messages.value.first;
      controller.enterSelectionMode(first);

      List<List<dynamic>?> batchArgs = <List<dynamic>?>[];
      setChannelHandler(appChannel, (MethodCall call) async {
        batchArgs.add(call.arguments as List<dynamic>?);
        return 1; // 只删 1 条（即已选的那条）
      });

      final int failed = await controller.deleteSelected();

      // 列表有 2 条，只选了 1 条，删除 1 条成功 → 失败 0。
      expect(failed, 0);
      expect(batchArgs.single, hasLength(1));
    });
  });
}
