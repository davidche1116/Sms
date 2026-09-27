/// MethodChannel `com.davidche1116.sms/smsApp` 协议字面量与类型化返回值。
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

  // ---- MethodChannel error code（PlatformException.code）----
  /// Activity 销毁/引擎重建，挂起的 Result 被取消（Kotlin `ERROR_LIFECYCLE`）。
  static const String errorLifecycle = 'lifecycle';

  // ---- insertTestSms / deleteTestSmsByPrefix 载荷键 ----
  static const String keyOk = 'ok';
  static const String keyIds = 'ids';
  static const String keyDeleted = 'deleted';

  // ---- querySms 载荷键 ----
  static const String keyMessages = 'messages';
  static const String keyTotal = 'total';
  static const String keyError = 'error';

  // ---- insertSmsBatch 载荷键 ----
  // Map：{ok, inserted, failed, errors:[{index, code, message}]}。
  // index 为入参 rows 下标（0-based）；-1 表示整批级错误（如非默认）。
  static const String keyInserted = 'inserted';
  static const String keyFailed = 'failed';
  static const String keyErrors = 'errors';
  static const String keyIndex = 'index';
  static const String keyCode = 'code';
  static const String keyMessage = 'message';

  // ---- insertSmsBatch errors[].code ----
  /// 非默认短信应用，整批未执行。
  static const String insertErrorNotDefault = 'not_default';

  /// 单行插入失败（insert 回 null 或抛异常）。
  static const String insertErrorFailed = 'failed';

  /// 保留值：形态异常/未知 code 的安全默认（解析兜底）。
  static const String insertErrorUnknown = 'unknown';
}

/// `setDefaultSms` 返回。
enum DefaultSmsResult {
  /// `'had'`：已是默认短信应用。
  alreadyDefault,

  /// `'no'`：已发起角色请求或已打开系统设置。
  requested,

  /// 系统未在时限内返回（Activity 销毁 / 弹窗久置不回）。
  /// 非线值：仅 Dart 超时路径产生，UI 应提示可去设置手动开启。
  timeout,

  /// `'error'`：失败（含未知线值）。
  error;

  /// 线字符串 → 枚举；未知值映射到 [error]。
  /// 注意：[timeout] 不经过线协议，由 Dart 超时包装产生。
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
/// `deleteSmsBatch` 线协议仍只回 `int?`（null=失败），「非默认」与「原生异常」
/// 不可区分，只见 [notDefaultOrError]。
/// `insertSmsBatch` 新线协议可区分，见 [InsertBatchResult]。
enum BatchFailure {
  /// 通道返回 null 或调用抛错：非默认短信应用 / 原生失败（不可区分）。
  notDefaultOrError,

  /// 明确「非默认短信应用」（insertSmsBatch errors 含 not_default）。
  notDefault,

  /// 明确原生插入失败（非 not_default）。
  native,
}

/// `insertSmsBatch` 单行失败明细。
class InsertRowError {
  const InsertRowError({
    required this.index,
    required this.code,
    this.message,
  });

  /// 对应入参 rows 下标（0-based）；-1 = 整批级错误（如非默认）。
  final int index;

  /// [ChannelCodes.insertErrorNotDefault] / [ChannelCodes.insertErrorFailed] /
  /// [ChannelCodes.insertErrorUnknown]。
  final String code;

  /// 原生补充说明，可能为 null。
  final String? message;

  /// 线协议 Map → 明细；字段缺失/形态异常时给安全默认。
  static InsertRowError fromWire(Object? raw) {
    if (raw is! Map) {
      return const InsertRowError(
        index: -1,
        code: ChannelCodes.insertErrorUnknown,
      );
    }
    final m = raw.cast<Object?, Object?>();
    return InsertRowError(
      index: (m[ChannelCodes.keyIndex] as num?)?.toInt() ?? -1,
      code: m[ChannelCodes.keyCode]?.toString() ?? ChannelCodes.insertErrorUnknown,
      message: m[ChannelCodes.keyMessage]?.toString(),
    );
  }

  @override
  String toString() =>
      'InsertRowError(index: $index, code: $code, message: $message)';
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
///
/// 线协议 Map `{ok, inserted, failed, errors}`；兼容旧 `int?`（int=全成条数，
/// null=失败）。部分成功时 ok=true 且 failed>0，明细见 [errors]。
class InsertBatchResult {
  const InsertBatchResult({
    this.inserted = 0,
    this.failed = 0,
    this.errors = const [],
    this.failure,
  });

  /// 成功（可含部分失败，failed/errors 仍回报）。
  const InsertBatchResult.ok(
    int inserted, {
    int failed = 0,
    List<InsertRowError> errors = const [],
  }) : this(inserted: inserted, failed: failed, errors: errors);

  /// 整批失败；可携带线协议上的 failed/errors 明细。
  const InsertBatchResult.failed([
    BatchFailure failure = BatchFailure.notDefaultOrError,
  ]) : this(failure: failure);

  /// 成功插入条数。
  final int inserted;

  /// 失败条数（部分成功时 >0；整批失败时保留线协议计数）。
  final int failed;

  /// 逐行失败明细，index 对应入参 rows 下标。
  final List<InsertRowError> errors;

  /// null=成功（可含部分失败）；否则整批失败原因。
  final BatchFailure? failure;

  bool get ok => failure == null;

  /// 线协议任意形态 → 结果。
  ///
  /// - Map：新契约，解析 ok/inserted/failed/errors；
  /// - int：旧契约全成，inserted=n；
  /// - null / 其他：整批失败。
  static InsertBatchResult fromWire(Object? raw) {
    if (raw == null) return const InsertBatchResult.failed();
    if (raw is num) return InsertBatchResult.ok(raw.toInt());
    if (raw is Map) {
      final m = raw.cast<Object?, Object?>();
      final okFlag = m[ChannelCodes.keyOk] == true;
      final inserted = (m[ChannelCodes.keyInserted] as num?)?.toInt() ?? 0;
      final failed = (m[ChannelCodes.keyFailed] as num?)?.toInt() ?? 0;
      final errors = [
        for (final e in (m[ChannelCodes.keyErrors] as List? ?? const []))
          InsertRowError.fromWire(e),
      ];
      if (okFlag) {
        return InsertBatchResult.ok(inserted, failed: failed, errors: errors);
      }
      final notDefault = errors.any(
        (e) => e.code == ChannelCodes.insertErrorNotDefault,
      );
      return InsertBatchResult(
        inserted: inserted,
        failed: failed,
        errors: errors,
        failure: notDefault ? BatchFailure.notDefault : BatchFailure.native,
      );
    }
    return const InsertBatchResult.failed();
  }
}
