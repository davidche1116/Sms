import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sms_advanced/sms_advanced.dart';

/// 短信数据访问层：统一封装 sms_advanced 插件与默认短信应用平台通道，
/// UI 层不直接接触 MethodChannel 与插件查询/删除 API，便于替换底层实现
/// （如未来用自写 platform channel 替换 sms_advanced 时只改这里）。
class SmsRepository {
  static const MethodChannel _platform = MethodChannel('com.dc16.sms/smsApp');
  static const String defaultPackageId = 'com.dc16.sms';

  /// 读取设备上的全部短信。
  Future<List<SmsMessage>> getAllSms() => SmsQuery().getAllSms;

  /// 按号码查询该地址的全部短信。
  ///
  /// 必须显式传全部类型：`querySms` 的 kinds 默认是 `[SmsQueryKind.Inbox]`，
  /// 不传就只回收件箱，与"全部短信"（Sent+Inbox+Draft）口径不一致，
  /// 用户会看到"同号码"结果比预期少。
  Future<List<SmsMessage>> queryByAddress(String? address) =>
      SmsQuery().querySms(address: address, kinds: SmsQueryKind.values);

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
