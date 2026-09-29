/// MethodChannel `com.dc16.sms/smsApp` 协议字面量（线格式，勿改值）。
///
/// 与 Kotlin `ChannelCodes` 一一对应。业务代码只准引用本文件常量，
/// 禁止散落裸字面量。
library;

/// 通道协议字面量（线格式，勿改值）。
abstract final class ChannelCodes {
  // ---- MethodChannel 方法名（线协议字符串，两端必须一致）----
  static const String methodHasReadSmsPermission = 'hasReadSmsPermission';
  static const String methodRequestReadSms = 'requestReadSms';
  static const String methodIsDefaultSms = 'isDefaultSms';
  static const String methodSetDefaultSms = 'setDefaultSms';
  static const String methodRestoreDefaultSms = 'restoreDefaultSms';
  static const String methodOpenDefaultSmsSettings = 'openDefaultSmsSettings';
  static const String methodOpenAppSettings = 'openAppSettings';
  static const String methodIsMiui = 'isMiui';
  static const String methodMiuiNotificationSmsState =
      'miuiNotificationSmsState';
  static const String methodOpenMiuiPermissionEditor =
      'openMiuiPermissionEditor';
  static const String methodInsertTestSms = 'insertTestSms';
  static const String methodDeleteTestSmsByPrefix = 'deleteTestSmsByPrefix';
  static const String methodQuerySms = 'querySms';
  static const String methodDeleteSmsBatch = 'deleteSmsBatch';
  static const String methodInsertSmsBatch = 'insertSmsBatch';

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
