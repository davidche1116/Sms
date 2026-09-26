import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sms/services/sms_repository.dart';
import 'package:sms_advanced/sms_advanced.dart';

/// sms_advanced 的查询通道（JSON 编解码）。
const MethodChannel queryChannel = MethodChannel(
  'plugins.elyudde.com/querySMS',
  JSONMethodCodec(),
);

/// 本项目自建的通道（默认 StandardMessageCodec）。
const MethodChannel appChannel = MethodChannel('com.dc16.sms/smsApp');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('queryByAddress', () {
    test('按全部短信类型查询（收件箱/已发送/草稿）', () async {
      final List<String> calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(queryChannel, (MethodCall call) async {
            calls.add(call.method);
            return <dynamic>[];
          });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(appChannel, (MethodCall call) async {
            if (call.method == 'querySms') {
              throw MissingPluginException('querySms');
            }
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(queryChannel, null);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(appChannel, null);
      });

      await SmsRepository().queryByAddress('10086');

      // 回归：插件 querySms 的 kinds 默认只含 Inbox，必须显式传全类型，
      // 否则"同号码"结果会漏掉已发送与草稿。
      expect(
        calls,
        unorderedEquals(<String>['getInbox', 'getSent', 'getDraft']),
      );
    });

    test('原生 querySms 可用时不再走插件', () async {
      final List<String> pluginCalls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(queryChannel, (MethodCall call) async {
            pluginCalls.add(call.method);
            return <dynamic>[];
          });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(appChannel, (MethodCall call) async {
            if (call.method != 'querySms') return null;
            expect(call.arguments, <String, dynamic>{'address': '10086'});
            return <String, dynamic>{
              'messages': <Map<String, dynamic>>[
                <String, dynamic>{
                  '_id': 1,
                  'thread_id': 1,
                  'address': '10086',
                  'body': 'hi',
                  'date': 1789000000000,
                  'type': 1,
                },
              ],
              'error': null,
            };
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(queryChannel, null);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(appChannel, null);
      });

      final List<SmsMessage> messages = await SmsRepository().queryByAddress(
        '10086',
      );

      expect(messages, hasLength(1));
      expect(messages.single.body, 'hi');
      expect(messages.single.kind, SmsMessageKind.Received);
      expect(pluginCalls, isEmpty);
    });

    test('原生 querySms 报 permission 时抛 SmsQueryPermissionException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(appChannel, (MethodCall call) async {
            return <String, dynamic>{
              'messages': <dynamic>[],
              'error': 'permission',
            };
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(appChannel, null),
      );

      await expectLater(
        SmsRepository().getAllSms(),
        throwsA(isA<SmsQueryPermissionException>()),
      );
    });

    test('date 为 null 的行不会让整次查询崩溃', () async {
      // 回归：SmsMessage.fromJson 对 containsKey('date') 且值为 null 会
      // DateTime.fromMillisecondsSinceEpoch(null) 抛错；原生侧空列就是 null。
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(appChannel, (MethodCall call) async {
            return <String, dynamic>{
              'messages': <Map<String, dynamic>>[
                <String, dynamic>{
                  '_id': 9,
                  'thread_id': 1,
                  'address': '10086',
                  'body': 'draft-like',
                  'date': null,
                  'date_sent': null,
                  'read': 0,
                  'type': 3,
                },
              ],
              'error': null,
            };
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(appChannel, null),
      );

      final List<SmsMessage> messages = await SmsRepository().getAllSms();

      expect(messages, hasLength(1));
      expect(messages.single.date, isNull);
      expect(messages.single.kind, SmsMessageKind.Draft);
    });
  });

  group('isDefaultSmsApp', () {
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(appChannel, null);
    });

    void mockGetDefaultSmsApp(Object? result) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(appChannel, (MethodCall call) async {
            expect(call.method, 'getDefaultSmsApp');
            if (result is Exception) throw result;
            return result;
          });
    }

    test('包名匹配时为 true', () async {
      mockGetDefaultSmsApp(SmsRepository.defaultPackageId);
      expect(await SmsRepository().isDefaultSmsApp(), true);
    });

    test('默认是别的应用时为 false', () async {
      mockGetDefaultSmsApp('com.android.mms');
      expect(await SmsRepository().isDefaultSmsApp(), false);
    });

    test('拿不到默认应用时返回 null（无法判定，而不是"非默认"）', () async {
      mockGetDefaultSmsApp('');
      expect(await SmsRepository().isDefaultSmsApp(), isNull);
    });

    test('平台异常时返回 null，由调用方 fail-safe 拦截', () async {
      // 回归：这一分支决定了"无法判定"是否会被误报成"不是默认短信应用"，
      // 误报会让用户白白去设置页切默认应用。
      mockGetDefaultSmsApp(PlatformException(code: 'error', message: 'boom'));
      expect(await SmsRepository().isDefaultSmsApp(), isNull);
    });

    test('通道缺失时返回 null', () async {
      expect(await SmsRepository().isDefaultSmsApp(), isNull);
    });
  });

  group('deleteSmsBatch', () {
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(appChannel, null);
    });

    test('原生返回删除条数', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(appChannel, (MethodCall call) async {
            expect(call.method, 'deleteSmsBatch');
            expect(call.arguments, <int>[1, 2, 3]);
            return 3;
          });

      expect(await SmsRepository().deleteSmsBatch(<int>[1, 2, 3]), 3);
    });

    test('平台侧缺失时返回 null，调用方回退逐条删除', () async {
      // 通道未注册会抛 MissingPluginException，必须被吃掉而不是冒泡。
      expect(await SmsRepository().deleteSmsBatch(<int>[1]), isNull);
    });
  });
}
