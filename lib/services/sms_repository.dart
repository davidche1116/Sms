import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sms_advanced/sms_advanced.dart';

/// 平台拒绝读取短信（无 READ_SMS 等）。
///
/// 与"查询失败"区分开：调用方应提示去授权，而不是笼统的"操作失败"。
class SmsQueryPermissionException implements Exception {
  const SmsQueryPermissionException();

  @override
  String toString() => 'SmsQueryPermissionException';
}

/// 短信数据访问层：统一封装 sms_advanced 插件与默认短信应用平台通道，
/// UI 层不直接接触 MethodChannel 与插件查询/删除 API，便于替换底层实现
/// （如未来用自写 platform channel 替换 sms_advanced 时只改这里）。
class SmsRepository {
  static const MethodChannel _platform = MethodChannel('com.dc16.sms/smsApp');
  static const String defaultPackageId = 'com.dc16.sms';

  /// 读取设备上的全部短信。
  Future<List<SmsMessage>> getAllSms() => _querySms();

  /// 按号码查询该地址的全部短信。
  ///
  /// 必须覆盖全部类型（Sent+Inbox+Draft）：插件 `querySms` 的 kinds 默认是
  /// `[SmsQueryKind.Inbox]`，不传就只回收件箱，与"全部短信"口径不一致。
  Future<List<SmsMessage>> queryByAddress(String? address) =>
      _querySms(address: address);

  /// 统一查询入口：只走原生多 URI；原生通道缺失时才回退插件。
  ///
  /// 刻意不「原生 + 插件合并」：sms_advanced 的 `readSms` 会对任意列
  /// `getInt`，碰到 `creator` 等文本列抛出的异常没有被它自己接住，会直接
  /// 把进程打崩（掉默认短信后该列更容易有值，表现为闪退）。插件只作
  /// MissingPluginException 时的兜底，平时不调用。
  Future<List<SmsMessage>> _querySms({String? address}) async {
    try {
      return await _querySmsNative(address);
    } on MissingPluginException catch (e) {
      debugPrint('querySms native missing, fall back to plugin: $e');
      return _querySmsViaPlugin(address);
    }
  }

  Future<List<SmsMessage>> _querySmsNative(String? address) async {
    final dynamic raw = await _platform.invokeMethod<dynamic>(
      'querySms',
      address == null || address.isEmpty
          ? null
          : <String, dynamic>{'address': address},
    );
    if (raw is! Map) {
      throw StateError('querySms returned unexpected payload: $raw');
    }
    final dynamic error = raw['error'];
    if (error == 'permission') {
      throw const SmsQueryPermissionException();
    }
    if (error != null) {
      throw PlatformException(code: 'querySms', message: '$error');
    }
    final List<dynamic> rows =
        (raw['messages'] as List<dynamic>?) ?? const <dynamic>[];
    return rows
        .map(
          (dynamic row) =>
              _fromNativeRow(Map<dynamic, dynamic>.from(row as Map)),
        )
        .toList(growable: false);
  }

  /// 安全解析原生行：不用 `SmsMessage.fromJson`。
  ///
  /// `fromJson` 在 `containsKey('date')` 且值为 null 时会
  /// `DateTime.fromMillisecondsSinceEpoch(null)` 直接抛错；原生侧会把
  /// 空列以 null 放进 map，必须自己判空。
  static SmsMessage _fromNativeRow(Map<dynamic, dynamic> data) {
    return SmsMessage(
      data['address'] as String?,
      data['body'] as String?,
      id: (data['_id'] as num?)?.toInt(),
      threadId: (data['thread_id'] as num?)?.toInt(),
      sim: (data['sub_id'] as num?)?.toInt(),
      read: (data['read'] as num?) == 1,
      date: _dateFrom(data['date']),
      dateSent: _dateFrom(data['date_sent']),
      kind: _kindFromType((data['type'] as num?)?.toInt()),
    );
  }

  static DateTime? _dateFrom(Object? value) {
    if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    return null;
  }

  /// 插件兜底：按类型分次查询且不排序，避免
  /// 1) 单类失败拖垮整次 getAllSms；
  /// 2) 插件 `SmsMessage.compareTo` 对 null id 强解包崩溃。
  Future<List<SmsMessage>> _querySmsViaPlugin(String? address) async {
    final List<SmsMessage> result = <SmsMessage>[];
    Object? lastError;
    for (final SmsQueryKind kind in SmsQueryKind.values) {
      try {
        result.addAll(
          await SmsQuery().querySms(
            address: address,
            kinds: <SmsQueryKind>[kind],
            sort: false,
          ),
        );
      } catch (e) {
        lastError = e;
        debugPrint('querySms plugin $kind failed: $e');
      }
    }
    if (result.isEmpty && lastError != null) {
      if (lastError is PlatformException &&
          (lastError.code == '#01' ||
              (lastError.message ?? '').toLowerCase().contains('permission'))) {
        throw const SmsQueryPermissionException();
      }
      // 保底抛出，让上层走"操作失败"而不是静默空列表。
      throw lastError is Exception ? lastError : Exception('$lastError');
    }
    return result;
  }

  /// Telephony.Sms.TYPE → 插件语义的 kind（收件箱/已发送/草稿）。
  static SmsMessageKind _kindFromType(int? type) {
    // 1=INBOX 2=SENT 3=DRAFT 4=OUTBOX 5=FAILED 6=QUEUED
    switch (type) {
      case 2:
      case 4:
      case 5:
      case 6:
        return SmsMessageKind.Sent;
      case 3:
        return SmsMessageKind.Draft;
      default:
        return SmsMessageKind.Received;
    }
  }

  /// 按 id + threadId 删除单条短信，返回 null/true/false 由插件语义决定。
  Future<bool?> removeSmsById(int id, int threadId) =>
      SmsRemover().removeSmsById(id, threadId);

  /// 批量删除短信，返回实际删除条数。
  ///
  /// 原生侧按 `_id IN (...)` 分批删除，把 N 次跨进程调用降到
  /// ceil(N / 900) 次。返回 `null` 表示平台侧不支持或删除失败，
  /// 调用方应回退到逐条删除。
  Future<int?> deleteSmsBatch(List<int> ids) async {
    try {
      return await _platform.invokeMethod<int>('deleteSmsBatch', ids);
    } on PlatformException catch (e) {
      debugPrint('deleteSmsBatch failed: ${e.message}');
      return null;
    } on MissingPluginException catch (e) {
      debugPrint('deleteSmsBatch missing: $e');
      return null;
    }
  }

  /// 当前应用是否为默认短信应用。
  ///
  /// 返回 `true` = 是默认；`false` = 明确不是默认（默认应用是别的包）；
  /// `null` = 无法判定（默认应用不可知，或平台调用缺失/异常）。
  /// 调用方据此区分提示，不把"拿不到"静默当成"不是默认"。
  Future<bool?> isDefaultSmsApp() async {
    try {
      final smsApp = await _platform.invokeMethod<String>('getDefaultSmsApp');
      if (smsApp == null || smsApp.isEmpty) return null;
      return smsApp == defaultPackageId;
    } on PlatformException catch (e) {
      debugPrint('getDefaultSmsApp failed: ${e.message}');
      return null;
    } on MissingPluginException catch (e) {
      // 方法缺失（如 iOS 或原生未注册该通道）属于"无法判定"，不是"不是默认"。
      debugPrint('getDefaultSmsApp missing: $e');
      return null;
    }
  }

  /// 发起"设为默认短信应用"的系统流程。
  Future<String?> setDefaultSmsApp() =>
      _platform.invokeMethod<String>('setDefaultSmsApp');

  /// 读取当前默认短信应用的包名。
  Future<String?> getDefaultSmsApp() =>
      _platform.invokeMethod<String>('getDefaultSmsApp');

  /// 恢复系统默认短信应用。
  Future<String?> resetDefaultSmsApp() =>
      _platform.invokeMethod<String>('resetDefaultSmsApp');
}
