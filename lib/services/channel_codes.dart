/// MethodChannel `com.dc16.sms/smsApp` 协议字面量与类型化返回值。
///
/// 与 Kotlin `ChannelCodes` 一一对应。**协议字符串保持不变**，
/// 业务代码只准引用本文件常量 / 枚举，禁止散落裸字面量。
library;

/// 通道协议字面量（线格式，勿改值）。
abstract final class ChannelCodes {
  // ---- setDefaultSms ----
  static const String setDefaultHad = 'had';
  static const String setDefaultNo = 'no';
  static const String error = 'error';

  // ---- restoreDefaultSms ----
  static const String restoreNotDefault = 'not_default';
  static const String restoreSettings = 'settings';
  // 'error' 复用 [error]。

  // ---- miuiNotificationSmsState ----
  static const String miuiAllow = 'allow';
  static const String miuiLikelyOff = 'likely_off';
  static const String miuiIgnore = 'ignore';
  static const String miuiDeny = 'deny';
  static const String miuiUnknown = 'unknown';

  // ---- querySms 的 error 字段（null = 成功）----
  static const String queryErrorPermission = 'permission';
  static const String queryErrorUnknown = 'unknown';

  // ---- insertTestSms / deleteTestSmsByPrefix 载荷键 ----
  static const String keyOk = 'ok';
  static const String keyIds = 'ids';
  static const String keyDeleted = 'deleted';

  // ---- querySms 载荷键 ----
  static const String keyMessages = 'messages';
  static const String keyTotal = 'total';
  static const String keyError = 'error';
}

/// `setDefaultSms` 返回。
enum DefaultSmsResult {
  /// `'had'`：已是默认短信应用。
  alreadyDefault,

  /// `'no'`：已发起角色请求或已打开系统设置。
  requested,

  /// `'error'`：失败（含未知线值）。
  error;

  /// 线字符串 → 枚举；未知值映射到 [error]。
  static DefaultSmsResult fromWire(String? raw) => switch (raw) {
    ChannelCodes.setDefaultHad => DefaultSmsResult.alreadyDefault,
    ChannelCodes.setDefaultNo => DefaultSmsResult.requested,
    _ => DefaultSmsResult.error,
  };
}

/// `restoreDefaultSms` 返回。
enum RestoreDefaultResult {
  /// `'not_default'`：本就不是默认短信应用。
  notDefault,

  /// `'settings'`：已打开系统「默认应用」设置页。
  openedSettings,

  /// `'error'`：打开失败（含未知线值）。
  error;

  /// 线字符串 → 枚举；未知值映射到 [error]。
  static RestoreDefaultResult fromWire(String? raw) => switch (raw) {
    ChannelCodes.restoreNotDefault => RestoreDefaultResult.notDefault,
    ChannelCodes.restoreSettings => RestoreDefaultResult.openedSettings,
    _ => RestoreDefaultResult.error,
  };
}

/// `miuiNotificationSmsState` 返回。
///
/// 当前 Kotlin 实现只产生 `allow` / `likely_off` / `unknown`；
/// `ignore` / `deny` 为历史兼容值，UI 仍需分支。
enum MiuiNotifState {
  /// `'allow'`：通知类短信已开通。
  allow,

  /// `'likely_off'`：大概率未开通。
  likelyOff,

  /// `'ignore'`：历史兼容（AppOps MODE_IGNORED 语义）。
  ignore,

  /// `'deny'`：历史兼容（AppOps MODE_ERRORED 语义）。
  deny,

  /// `'unknown'`：探测不到（含未知线值）。
  unknown;

  /// 线字符串 → 枚举；未知值映射到 [unknown]。
  static MiuiNotifState fromWire(String? raw) => switch (raw) {
    ChannelCodes.miuiAllow => MiuiNotifState.allow,
    ChannelCodes.miuiLikelyOff => MiuiNotifState.likelyOff,
    ChannelCodes.miuiIgnore => MiuiNotifState.ignore,
    ChannelCodes.miuiDeny => MiuiNotifState.deny,
    _ => MiuiNotifState.unknown,
  };
}

/// `querySms` 的 `error` 字段。
enum QueryError {
  /// `null`：成功（`messages` 可为空）。
  none,

  /// `'permission'`：无读能力且非默认。
  permission,

  /// `'unknown'`：其他失败（含未知线值）。
  unknown;

  /// 线值 → 枚举；`null` → [none]，未知字符串 → [unknown]。
  static QueryError fromWire(Object? raw) => switch (raw) {
    null => QueryError.none,
    ChannelCodes.queryErrorPermission => QueryError.permission,
    ChannelCodes.queryErrorUnknown => QueryError.unknown,
    _ => QueryError.unknown,
  };
}

/// 批量写（删除 / 插入）失败原因。
///
/// 线协议只回 `int?`（null=失败），「非默认」与「原生异常」不可区分。
enum BatchFailure {
  /// 通道返回 null 或调用抛错：非默认短信应用 / 原生失败。
  notDefaultOrError,
}

/// `deleteSmsBatch` 结果。
class DeleteBatchResult {
  const DeleteBatchResult.ok(this.deleted) : failure = null;
  const DeleteBatchResult.failed([
    this.failure = BatchFailure.notDefaultOrError,
  ]) : deleted = 0;

  /// 实际删除行数（成功时 ≥ 0）。
  final int deleted;

  /// null=成功；否则失败原因。
  final BatchFailure? failure;

  bool get ok => failure == null;
}

/// `insertSmsBatch` 结果。
class InsertBatchResult {
  const InsertBatchResult.ok(this.inserted) : failure = null;
  const InsertBatchResult.failed([
    this.failure = BatchFailure.notDefaultOrError,
  ]) : inserted = 0;

  /// 成功插入条数。
  final int inserted;

  /// null=成功；否则失败原因。
  final BatchFailure? failure;

  bool get ok => failure == null;
}
