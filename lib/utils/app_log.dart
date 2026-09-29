import 'dart:developer' as developer;

/// 应用日志工具：使用 `dart:developer.log`，在 release 构建中同样输出
/// （区别于 `debugPrint`，后者在 release 中被移除）。
///
/// 日志名称统一为 `sms`，便于在 logcat / 日志聚合中过滤。
class AppLog {
  AppLog._();

  /// Debug 级别（level 900）。
  static void d(String msg) => developer.log(msg, name: 'sms', level: 900);

  /// Warning 级别（level 1000），可附带错误对象。
  static void w(String msg, [Object? error]) =>
      developer.log(msg, name: 'sms', level: 1000, error: error);

  /// Error 级别（level 1100），可附带错误对象。
  static void e(String msg, [Object? error]) =>
      developer.log(msg, name: 'sms', level: 1100, error: error);
}
