/// MethodChannel 线协议解析函数：线值 → 类型化返回值。
///
/// 所有 `fromWire` 解析逻辑集中于此，与协议常量（[channel_codes.dart]）和
/// 类型定义（[wire_types.dart]）分离。
library;

import 'channel_codes.dart';
import 'wire_types.dart';

/// `setDefaultSms` 线字符串 → 枚举；未知值映射到 [DefaultSmsResult.error]。
///
/// 注意：[DefaultSmsResult.timeout] 不经过线协议，由 Dart 超时包装产生。
DefaultSmsResult parseDefaultSmsResult(String? raw) => switch (raw) {
  ChannelCodes.setDefaultHad => DefaultSmsResult.alreadyDefault,
  ChannelCodes.setDefaultNo => DefaultSmsResult.requested,
  _ => DefaultSmsResult.error,
};

/// `restoreDefaultSms` 线字符串 → 枚举；未知值映射到 [RestoreDefaultResult.error]。
RestoreDefaultResult parseRestoreDefaultResult(String? raw) => switch (raw) {
  ChannelCodes.restoreNotDefault => RestoreDefaultResult.notDefault,
  ChannelCodes.restoreSettings => RestoreDefaultResult.openedSettings,
  _ => RestoreDefaultResult.error,
};

/// `miuiNotificationSmsState` 线字符串 → 枚举；未知值映射到 [MiuiNotifState.unknown]。
MiuiNotifState parseMiuiNotifState(String? raw) => switch (raw) {
  ChannelCodes.miuiAllow => MiuiNotifState.allow,
  ChannelCodes.miuiLikelyOff => MiuiNotifState.likelyOff,
  ChannelCodes.miuiIgnore => MiuiNotifState.ignore,
  ChannelCodes.miuiDeny => MiuiNotifState.deny,
  _ => MiuiNotifState.unknown,
};

/// `querySms` 的 `error` 字段线值 → 枚举；`null` → [QueryError.none]，未知字符串 → [QueryError.unknown]。
QueryError parseQueryError(Object? raw) => switch (raw) {
  null => QueryError.none,
  ChannelCodes.queryErrorPermission => QueryError.permission,
  ChannelCodes.queryErrorUnknown => QueryError.unknown,
  _ => QueryError.unknown,
};

/// `querySms` warnings[] 项线协议 Map → 明细；字段缺失/形态异常时给安全默认。
QueryWarning parseQueryWarning(Object? raw) {
  if (raw is! Map) {
    return const QueryWarning(code: ChannelCodes.warnUnknown);
  }
  final m = raw.cast<Object?, Object?>();
  return QueryWarning(
    code: m[ChannelCodes.keyCode]?.toString() ?? ChannelCodes.warnUnknown,
    message: m[ChannelCodes.keyMessage]?.toString(),
  );
}

/// 批量写单行失败明细线协议 Map → 明细；字段缺失/形态异常时给安全默认。
InsertRowError parseInsertRowError(Object? raw) {
  if (raw is! Map) {
    return const InsertRowError(
      index: -1,
      code: ChannelCodes.insertErrorUnknown,
    );
  }
  final m = raw.cast<Object?, Object?>();
  return InsertRowError(
    index: (m[ChannelCodes.keyIndex] as num?)?.toInt() ?? -1,
    code:
        m[ChannelCodes.keyCode]?.toString() ?? ChannelCodes.insertErrorUnknown,
    message: m[ChannelCodes.keyMessage]?.toString(),
  );
}

/// `deleteSmsBatch` 线协议任意形态 → 结果。
///
/// - Map：新契约，解析 ok/deleted/failed/error/errors；
/// - int：旧契约全成，deleted=n；
/// - null / 其他：整批失败（不可区分，[BatchFailure.notDefaultOrError]）。
DeleteBatchResult parseDeleteBatchResult(Object? raw) {
  if (raw == null) return const DeleteBatchResult.failed();
  if (raw is num) return DeleteBatchResult.ok(raw.toInt());
  if (raw is Map) {
    final m = raw.cast<Object?, Object?>();
    final okFlag = m[ChannelCodes.keyOk] == true;
    final deleted = (m[ChannelCodes.keyDeleted] as num?)?.toInt() ?? 0;
    final failed = (m[ChannelCodes.keyFailed] as num?)?.toInt() ?? 0;
    final errors = [
      for (final e in (m[ChannelCodes.keyErrors] as List? ?? const []))
        parseInsertRowError(e),
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
        _ =>
          errors.any((e) => e.code == ChannelCodes.deleteErrorNotDefault)
              ? BatchFailure.notDefault
              : BatchFailure.notDefaultOrError,
      },
    );
  }
  return const DeleteBatchResult.failed();
}

/// `insertSmsBatch` 线协议任意形态 → 结果。
///
/// - Map：新契约，解析 ok/inserted/failed/errors；
/// - int：旧契约全成，inserted=n；
/// - null / 其他：整批失败。
InsertBatchResult parseInsertBatchResult(Object? raw) {
  if (raw == null) return const InsertBatchResult.failed();
  if (raw is num) return InsertBatchResult.ok(raw.toInt());
  if (raw is Map) {
    final m = raw.cast<Object?, Object?>();
    final okFlag = m[ChannelCodes.keyOk] == true;
    final inserted = (m[ChannelCodes.keyInserted] as num?)?.toInt() ?? 0;
    final failed = (m[ChannelCodes.keyFailed] as num?)?.toInt() ?? 0;
    final errors = [
      for (final e in (m[ChannelCodes.keyErrors] as List? ?? const []))
        parseInsertRowError(e),
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
