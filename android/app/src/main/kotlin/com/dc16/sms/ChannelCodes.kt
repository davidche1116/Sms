package com.dc16.sms

/**
 * MethodChannel `com.dc16.sms/smsApp` 协议字面量。
 *
 * 与 Dart `channel_codes.dart` 的 `ChannelCodes` 一一对应。
 * **协议字符串保持不变**；`MainActivity` / `SmsAccess` 只准引用本对象，
 * 禁止散落裸字面量。
 */
object ChannelCodes {
  // ---- MethodChannel 方法名（线协议字符串，两端必须一致）----
  const val METHOD_HAS_READ_SMS_PERMISSION = "hasReadSmsPermission"
  const val METHOD_REQUEST_READ_SMS = "requestReadSms"
  const val METHOD_IS_DEFAULT_SMS = "isDefaultSms"
  const val METHOD_SET_DEFAULT_SMS = "setDefaultSms"
  const val METHOD_RESTORE_DEFAULT_SMS = "restoreDefaultSms"
  const val METHOD_OPEN_DEFAULT_SMS_SETTINGS = "openDefaultSmsSettings"
  const val METHOD_OPEN_APP_SETTINGS = "openAppSettings"
  const val METHOD_IS_MIUI = "isMiui"
  const val METHOD_MIUI_NOTIFICATION_SMS_STATE = "miuiNotificationSmsState"
  const val METHOD_OPEN_MIUI_PERMISSION_EDITOR = "openMiuiPermissionEditor"
  const val METHOD_INSERT_TEST_SMS = "insertTestSms"
  const val METHOD_DELETE_TEST_SMS_BY_PREFIX = "deleteTestSmsByPrefix"
  const val METHOD_QUERY_SMS = "querySms"
  const val METHOD_DELETE_SMS_BATCH = "deleteSmsBatch"
  const val METHOD_INSERT_SMS_BATCH = "insertSmsBatch"

  // ---- setDefaultSms ----
  const val SET_DEFAULT_HAD = "had"
  const val SET_DEFAULT_NO = "no"
  const val ERROR = "error"

  // ---- restoreDefaultSms（"error" 复用 [ERROR]）----
  const val RESTORE_NOT_DEFAULT = "not_default"
  const val RESTORE_SETTINGS = "settings"

  // ---- miuiNotificationSmsState ----
  // 当前实现只产生 ALLOW / LIKELY_OFF / UNKNOWN；IGNORE / DENY 为历史兼容值。
  const val MIUI_ALLOW = "allow"
  const val MIUI_LIKELY_OFF = "likely_off"
  const val MIUI_IGNORE = "ignore"
  const val MIUI_DENY = "deny"
  const val MIUI_UNKNOWN = "unknown"

  // ---- querySms 的 error 字段（null = 成功）----
  const val QUERY_ERROR_PERMISSION = "permission"
  const val QUERY_ERROR_UNKNOWN = "unknown"

  // ---- MethodChannel error code（error() 的 errorCode）----
  /** Activity 销毁/引擎重建，挂起的 Result 被取消回包。Dart 映射为 timeout 语义。 */
  const val ERROR_LIFECYCLE = "lifecycle"

  // ---- insertTestSms / deleteTestSmsByPrefix 载荷键 ----
  const val KEY_OK = "ok"
  const val KEY_IDS = "ids"
  const val KEY_DELETED = "deleted"

  // ---- querySms 载荷键 ----
  const val KEY_MESSAGES = "messages"
  const val KEY_TOTAL = "total"
  const val KEY_ERROR = "error"

  /** 有数据但部分子查询失败：true。与 [KEY_ERROR] 互斥（error 非空时必为 false）。 */
  const val KEY_PARTIAL = "partial"

  /** 部分失败明细 `[{code, message}]`；message 为固定文案，不含 URI/路径。 */
  const val KEY_WARNINGS = "warnings"

  // ---- querySms warnings[].code ----
  // message 一律固定文案（见 SmsAccess.warningOf），禁止携带 exception.message / URI / 路径。
  /** SMS 主表/子箱查询被 SecurityException 拒绝。 */
  const val WARN_SMS_URI_SECURITY = "sms_uri_security"

  /** SMS 主表/子箱查询其它异常。 */
  const val WARN_SMS_URI_FAILED = "sms_uri_failed"

  /** MMS 主表/子箱查询被 SecurityException 拒绝。 */
  const val WARN_MMS_URI_SECURITY = "mms_uri_security"

  /** MMS 主表/子箱查询其它异常。 */
  const val WARN_MMS_URI_FAILED = "mms_uri_failed"

  /** `content://mms/addr`（地址过滤预取 / 号码富化）失败。 */
  const val WARN_MMS_ADDR_FAILED = "mms_addr_failed"

  /** `content://mms/part`（正文摘要富化）失败。 */
  const val WARN_MMS_PART_FAILED = "mms_part_failed"

  /** 保留值：形态异常/未知 code 的安全默认（Dart 解析兜底，线值同 `unknown`）。 */
  const val WARN_UNKNOWN = "unknown"

  // ---- insertSmsBatch 载荷键 ----
  // 返回 Map：{ok, inserted, failed, errors:[{index, code, message}]}。
  // index 为入参 rows 下标（0-based）；-1 表示整批级错误（如非默认）。
  const val KEY_INSERTED = "inserted"
  const val KEY_FAILED = "failed"
  const val KEY_ERRORS = "errors"
  const val KEY_INDEX = "index"
  const val KEY_CODE = "code"
  const val KEY_MESSAGE = "message"

  // ---- insertSmsBatch errors[].code ----
  /** 非默认短信应用，整批未执行。 */
  const val INSERT_ERROR_NOT_DEFAULT = "not_default"

  /** 单行插入失败（insert 回 null 或抛异常）。 */
  const val INSERT_ERROR_FAILED = "failed"

  /** 入参行形态非法（非 Map）：按原下标记失败，不丢弃、不打乱 index。 */
  const val INSERT_ERROR_INVALID = "invalid"

  /** 保留值：形态异常/未知 code 的安全默认（Dart 解析兜底）。 */
  const val INSERT_ERROR_UNKNOWN = "unknown"

  // ---- deleteSmsBatch error 字段 / errors[].code ----
  // 返回 Map：{ok, deleted, failed, error, errors:[{index, code, message}]}。
  // error 为整批级：null|not_default|failed|unknown；index 为入参 targets 下标。
  /** 非默认短信应用，整批未执行。 */
  const val DELETE_ERROR_NOT_DEFAULT = "not_default"

  /** 原生异常（delete 抛出），该目标/该批失败。 */
  const val DELETE_ERROR_FAILED = "failed"

  /** 保留值：形态异常/未知 code 的安全默认（Dart 解析兜底）。 */
  const val DELETE_ERROR_UNKNOWN = "unknown"
}
