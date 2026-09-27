package com.davidche1116.sms

/**
 * MethodChannel `com.davidche1116.sms/smsApp` 协议字面量。
 *
 * 与 Dart `channel_codes.dart` 的 `ChannelCodes` 一一对应。
 * **协议字符串保持不变**；`MainActivity` / `SmsAccess` 只准引用本对象，
 * 禁止散落裸字面量。
 */
object ChannelCodes {
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
