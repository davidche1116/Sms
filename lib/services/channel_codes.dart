/// MethodChannel `com.davidche1116.sms/smsApp` 协议字面量与类型化返回值。
///
/// 与 Kotlin `ChannelCodes` 一一对应。**协议字符串保持不变**，
/// 业务代码只准引用本文件常量 / 枚举，禁止散落裸字面量。
library;

import '../generated/app_localizations.dart';

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

  /// 有数据但部分子查询失败：true。与 `error` 互斥（error 非空时必为 false）。
  static const String keyPartial = 'partial';

  /// 部分失败明细 `[{code, message}]`；message 为固定文案，不含 URI/路径。
  static const String keyWarnings = 'warnings';

  // ---- querySms warnings[].code ----
  /// SMS 主表/子箱查询被 SecurityException 拒绝。
  static const String warnSmsUriSecurity = 'sms_uri_security';

  /// SMS 主表/子箱查询其它异常。
  static const String warnSmsUriFailed = 'sms_uri_failed';

  /// MMS 主表/子箱查询被 SecurityException 拒绝。
  static const String warnMmsUriSecurity = 'mms_uri_security';

  /// MMS 主表/子箱查询其它异常。
  static const String warnMmsUriFailed = 'mms_uri_failed';

  /// `content://mms/addr`（地址过滤预取 / 号码富化）失败。
  static const String warnMmsAddrFailed = 'mms_addr_failed';

  /// `content://mms/part`（正文摘要富化）失败。
  static const String warnMmsPartFailed = 'mms_part_failed';

  /// 保留值：形态异常/未知 code 的安全默认（解析兜底，线值同 `unknown`）。
  static const String warnUnknown = 'unknown';

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

  /// 入参行形态非法（非 Map）：按原下标记失败，不丢弃、不打乱 index。
  static const String insertErrorInvalid = 'invalid';

  /// 保留值：形态异常/未知 code 的安全默认（解析兜底）。
  static const String insertErrorUnknown = 'unknown';

  // ---- deleteSmsBatch error 字段 / errors[].code ----
  // Map：{ok, deleted, failed, error, errors:[{index, code, message}]}。
  // error 为整批级：null|not_default|failed|unknown；index 为入参 targets 下标。
  /// 非默认短信应用，整批未执行。
  static const String deleteErrorNotDefault = 'not_default';

  /// 原生异常（delete 抛出），该目标/该批失败。
  static const String deleteErrorFailed = 'failed';

  /// 保留值：形态异常/未知 code 的安全默认（解析兜底）。
  static const String deleteErrorUnknown = 'unknown';
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

/// `querySms` 部分失败明细（`warnings[]` 一项）。
///
/// [code] 见 `ChannelCodes.warn*`；[message] 为原生固定文案，**不含** URI /
/// 文件路径 / 异常堆栈，可安全打日志或展示。
class QueryWarning {
  const QueryWarning({required this.code, this.message});

  /// `sms_uri_security` / `sms_uri_failed` / `mms_uri_security` /
  /// `mms_uri_failed` / `mms_addr_failed` / `mms_part_failed`（未知线值原样保留）。
  final String code;

  /// 原生补充说明，可空。
  final String? message;

  /// 线协议 Map → 明细；字段缺失/形态异常时给安全默认。
  static QueryWarning fromWire(Object? raw) {
    if (raw is! Map) {
      return const QueryWarning(code: ChannelCodes.warnUnknown);
    }
    final m = raw.cast<Object?, Object?>();
    return QueryWarning(
      code: m[ChannelCodes.keyCode]?.toString() ?? ChannelCodes.warnUnknown,
      message: m[ChannelCodes.keyMessage]?.toString(),
    );
  }

  @override
  String toString() => 'QueryWarning(code: $code, message: $message)';

  @override
  bool operator ==(Object other) =>
      other is QueryWarning && other.code == code && other.message == message;

  @override
  int get hashCode => Object.hash(code, message);
}

/// 批量写（删除 / 插入）失败原因。
///
/// `insertSmsBatch` / `deleteSmsBatch` 新线协议均可区分 [notDefault] 与 [native]；
/// [notDefaultOrError] 仅出现于旧 `int?` 线协议 / 通道异常等不可区分场景。
enum BatchFailure {
  /// 旧 `int?` 协议的 null、或形态异常：非默认 / 原生失败（不可区分）。
  notDefaultOrError,

  /// 明确「非默认短信应用」（整批未执行）。
  notDefault,

  /// 明确原生异常 / 删除或插入失败（非 not_default）。
  native,
}

/// 批量写单行失败明细（`insertSmsBatch` / `deleteSmsBatch` 共用）。
class InsertRowError {
  const InsertRowError({
    required this.index,
    required this.code,
    this.message,
  });

  /// 对应入参下标（0-based）；-1 = 整批级错误（如非默认）。
  final int index;

  /// [ChannelCodes.insertErrorNotDefault] / [ChannelCodes.insertErrorFailed] /
  /// [ChannelCodes.insertErrorInvalid] / [ChannelCodes.insertErrorUnknown]。
  final String code;

  /// 原生补充说明，可能为 null。仅供日志，**不要**直接展示给用户
  /// （可能是系统异常英文/系统语言文案）；UI 请用 [labelOf]。
  final String? message;

  /// 按 [code] 映射本地化文案；未知 code 回落到「未知错误」。
  String labelOf(AppLocalizations l10n) => switch (code) {
    // insert/delete 共用 `not_default` / `failed` / `unknown` 线值
    ChannelCodes.insertErrorNotDefault => l10n.insertErrNotDefault,
    ChannelCodes.insertErrorFailed => l10n.insertErrFailed,
    ChannelCodes.insertErrorInvalid => l10n.insertErrInvalid,
    ChannelCodes.deleteErrorUnknown => l10n.deleteErrUnknown,
    _ => l10n.insertErrUnknown,
  };

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
///
/// 线协议 Map `{ok, deleted, failed, error, errors}`；兼容旧 `int?`（int=全成条数，
/// null=失败）。部分成功时 ok=true 且 failed>0，明细见 [errors]。
class DeleteBatchResult {
  const DeleteBatchResult({
    this.deleted = 0,
    this.failed = 0,
    this.errors = const [],
    this.failure,
  });

  /// 成功（可含部分失败，failed/errors 仍回报）。
  const DeleteBatchResult.ok(
    int deleted, {
    int failed = 0,
    List<InsertRowError> errors = const [],
  }) : this(deleted: deleted, failed: failed, errors: errors);

  /// 整批失败；可携带线协议上的 deleted/failed/errors 明细。
  const DeleteBatchResult.failed([
    BatchFailure failure = BatchFailure.notDefaultOrError,
  ]) : this(failure: failure);

  /// 实际删除行数（成功时 ≥ 0；部分成功时为已删条数）。
  final int deleted;

  /// 失败条数（部分成功时 >0；整批失败时保留线协议计数）。
  final int failed;

  /// 逐条失败明细，index 对应入参 targets 下标。
  final List<InsertRowError> errors;

  /// null=成功（可含部分失败）；否则整批失败原因（线协议 `error` 字段）。
  final BatchFailure? failure;

  bool get ok => failure == null;

  /// 线协议任意形态 → 结果。
  ///
  /// - Map：新契约，解析 ok/deleted/failed/error/errors；
  /// - int：旧契约全成，deleted=n；
  /// - null / 其他：整批失败（不可区分，[BatchFailure.notDefaultOrError]）。
  static DeleteBatchResult fromWire(Object? raw) {
    if (raw == null) return const DeleteBatchResult.failed();
    if (raw is num) return DeleteBatchResult.ok(raw.toInt());
    if (raw is Map) {
      final m = raw.cast<Object?, Object?>();
      final okFlag = m[ChannelCodes.keyOk] == true;
      final deleted = (m[ChannelCodes.keyDeleted] as num?)?.toInt() ?? 0;
      final failed = (m[ChannelCodes.keyFailed] as num?)?.toInt() ?? 0;
      final errors = [
        for (final e in (m[ChannelCodes.keyErrors] as List? ?? const []))
          InsertRowError.fromWire(e),
      ];
      if (okFlag) {
        return DeleteBatchResult.ok(deleted, failed: failed, errors: errors);
      }
      final errorRaw = m[ChannelCodes.keyError];
      return DeleteBatchResult(
        deleted: deleted,
        failed: failed,
        errors: errors,
        failure: switch (errorRaw) {
          ChannelCodes.deleteErrorNotDefault => BatchFailure.notDefault,
          ChannelCodes.deleteErrorFailed => BatchFailure.native,
          ChannelCodes.deleteErrorUnknown => BatchFailure.notDefaultOrError,
          _ => errors.any(
              (e) => e.code == ChannelCodes.deleteErrorNotDefault,
            )
              ? BatchFailure.notDefault
              : BatchFailure.notDefaultOrError,
        },
      );
    }
    return const DeleteBatchResult.failed();
  }
}

/// 分块删除停止原因（[DeleteChunkResult.reason]）。
enum DeleteStopReason {
  /// 全部块已发出并完成。
  none,

  /// 某块失败，其后块未发出。
  failed,

  /// 用户取消，其后块未发出（已发出的不撤回）。
  cancelled,
}

/// `deleteSmsBatchChunked` 结果：顺序前缀式进度，中断后已删的可安全移出列表。
class DeleteChunkResult {
  const DeleteChunkResult({
    required this.deleted,
    required this.total,
    this.reason = DeleteStopReason.none,
    this.failure,
  });

  /// 已成功完成块的条数。块按目标列表原序发出，故等于入参可删列表的前缀长。
  final int deleted;

  /// 目标总数（已滤掉无 id 行）。
  final int total;

  /// 停止原因；[DeleteStopReason.none] 且 deleted==total 为完整成功。
  final DeleteStopReason reason;

  /// [DeleteStopReason.failed] 时的失败原因；其余为 null。
  final BatchFailure? failure;

  /// 是否完整删完。
  bool get complete => reason == DeleteStopReason.none && deleted >= total;
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
