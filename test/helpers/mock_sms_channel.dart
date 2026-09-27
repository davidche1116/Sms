import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sms/app.dart';

import 'app_channel.dart';

export 'app_channel.dart';

/// 样例短信时间锚点（固定，避免依赖真实时钟）。
final sampleToday = DateTime(2026, 9, 26, 11, 2);
final sampleYesterday = DateTime(2026, 9, 25, 9, 0);
final sampleOlder = DateTime(2026, 8, 1, 8, 0);

/// 首页固定 4 行：3 条有 id + 1 条无 id 防御行（不可选中/滑删）。
List<Map<String, dynamic>> sampleRows() => [
  {
    '_id': 1,
    'thread_id': 1,
    'address': '10010',
    'body': '【流量提醒】测试短信',
    'date': sampleToday.millisecondsSinceEpoch,
    'read': 1,
    'type': 1,
    'sub_id': 1,
  },
  {
    '_id': 2,
    'thread_id': 2,
    'address': '10086',
    'body': '验证码 8888，勿泄露',
    'date': sampleYesterday.millisecondsSinceEpoch,
    'read': 0,
    'type': 1,
    'sub_id': 1,
  },
  {
    '_id': 3,
    'thread_id': 3,
    'address': '13800000000',
    'body': '已发送：好的，收到',
    'date': sampleOlder.millisecondsSinceEpoch,
    'read': 1,
    'type': 2,
    'sub_id': 2,
  },
  {
    // 无 id 行：防御路径，不可选中
    'thread_id': 4,
    'address': '10000',
    'body': '无 id 行',
    'date': sampleToday.millisecondsSinceEpoch,
    'read': 1,
    'type': 1,
    'sub_id': 1,
  },
];

/// 首页默认场景：有读权限、默认短信、返回 [sampleRows]（删除成功后缩减）。
///
/// - [queryResult]：整包覆盖 `querySms` 返回（如 `{messages, error}`）。
/// - [onDelete]：`deleteSmsBatch` 钩子，返回 null 表示删除失败；默认全成功。
/// - [handlers]：按方法名追加/覆盖返回（如 MIUI 相关方法）。
void mockHomeChannel({
  Object? queryResult,
  int? Function(List<int> ids)? onDelete,
  Map<String, Future<Object?> Function(MethodCall call)>? handlers,
}) {
  final deleted = <int>{};
  setAppChannelHandler((call) async {
    final override = handlers?[call.method];
    if (override != null) return override(call);
    switch (call.method) {
      case 'hasReadSmsPermission':
        return true;
      case 'isDefaultSms':
        return true;
      case 'querySms':
        if (queryResult != null) return queryResult;
        return {
          'messages':
              sampleRows().where((r) => !deleted.contains(r['_id'])).toList(),
          'error': null,
        };
      case 'deleteSmsBatch':
        final ids = (call.arguments as List).cast<int>();
        if (onDelete != null) {
          final n = onDelete(ids);
          if (n != null) deleted.addAll(ids);
          return n;
        }
        deleted.addAll(ids);
        return ids.length;
      default:
        return null;
    }
  });
}

/// MIUI 引导场景：按需给出权限/默认/MIUI 状态，querySms 默认按 [hasReadSms] 返回。
void mockMiuiChannel({
  required bool hasReadSms,
  bool isDefaultSms = true,
  required String miuiNotifState,
  bool requestReadSmsResult = true,
  void Function()? onOpenMiuiEditor,
  List<Map<String, dynamic>>? queryRows,
  String queryError = 'permission',
}) {
  setAppChannelHandler((call) async {
    switch (call.method) {
      case 'hasReadSmsPermission':
        return hasReadSms;
      case 'isDefaultSms':
        return isDefaultSms;
      case 'requestReadSms':
        return requestReadSmsResult;
      case 'isMiui':
        return true;
      case 'miuiNotificationSmsState':
        return miuiNotifState;
      case 'openMiuiPermissionEditor':
        onOpenMiuiEditor?.call();
        return true;
      case 'querySms':
        return {
          'messages': queryRows ?? (hasReadSms ? sampleRows() : <Map<String, dynamic>>[]),
          'error': hasReadSms ? null : queryError,
        };
      default:
        return null;
    }
  });
}

/// 首页 widget 标准夹具：空 Prefs + 默认通道 mock，测试结束清 handler。
///
/// 需在 `main()` 顶部调用一次；Prefs 每条用例重置，避免主题/隐藏列表泄漏。
void setUpHomeHarness() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockHomeChannel();
  });
  tearDown(clearAppChannelHandler);
}

/// 挂载首页并走完首帧/主题动画（勿用 pumpAndSettle，首页可能有待机动画）。
Future<void> pumpHome(WidgetTester tester) async {
  await tester.pumpWidget(const SmsApp());
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}
