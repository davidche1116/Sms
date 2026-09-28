import 'dart:async';

import 'package:flutter/material.dart';
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
/// - [queryResult]：整包覆盖 `querySms` 返回（如 `{messages, error}`）；
///   其 `messages` 同样按已删 id 过滤，保证删后 `_load()` 列表一致。
/// - [onDelete]：`deleteSmsBatch` 钩子，入参为原生 id 列表；返回值可以是：
///   - `null` / `0` 以下：旧协议失败；
///   - `int`：旧协议全成条数；
///   - `Map`：新协议 `{ok, deleted, failed, error, errors}`。
///   默认全成功。可为 async（测试里用 Completer 悬住某块，观察进度/取消）。
/// - [handlers]：按方法名追加/覆盖返回（如 MIUI 相关方法）。
void mockHomeChannel({
  Object? queryResult,
  FutureOr<Object?> Function(List<int> ids)? onDelete,
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
        if (queryResult != null) {
          // 与默认路径一致：已删 id 不再回传，避免删后 _load() 又把行带回来。
          final map = Map<Object?, Object?>.from(queryResult as Map);
          final messages = (map['messages'] as List?) ?? const [];
          map['messages'] = [
            for (final r in messages)
              if (!deleted.contains((r as Map)['_id'])) r,
          ];
          return map;
        }
        return {
          'messages': sampleRows()
              .where((r) => !deleted.contains(r['_id']))
              .toList(),
          'error': null,
        };
      case 'deleteSmsBatch':
        // 线协议：[{id, is_mms}]（也兼容旧 List<int>）
        final raw = (call.arguments as List?) ?? const [];
        final ids = <int>[];
        for (final e in raw) {
          if (e is Map) {
            final id = (e['id'] as num?)?.toInt();
            if (id != null) ids.add(id);
          } else if (e is num) {
            ids.add(e.toInt());
          }
        }
        if (onDelete != null) {
          final r = await onDelete(ids);
          // 全成才把 id 记为已删（部分失败的不回传，保持保守）
          final ok = r is Map
              ? r['ok'] == true && (r['failed'] as num? ?? 0) == 0
              : r is int && r >= 0;
          if (ok) deleted.addAll(ids);
          return r;
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
          'messages':
              queryRows ??
              (hasReadSms ? sampleRows() : <Map<String, dynamic>>[]),
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
/// 默认把测试 locale 固定为 `zh`，与既有中文断言一致；用例可自行覆盖。
void setUpHomeHarness() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockHomeChannel();
  });
  tearDown(clearAppChannelHandler);
}

/// 挂载首页并走完首帧/主题动画（勿用 pumpAndSettle，首页可能有待机动画）。
///
/// 默认中文；英文用例传 `locale: Locale('en')`。
Future<void> pumpHome(
  WidgetTester tester, {
  Locale locale = const Locale('zh'),
}) async {
  await tester.pumpWidget(SmsApp(locale: locale));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}
