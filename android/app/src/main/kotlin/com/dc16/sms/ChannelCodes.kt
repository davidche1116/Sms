package com.dc16.sms

/**
 * MethodChannel `com.dc16.sms/smsApp` 协议字面量。
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

  // ---- insertTestSms / deleteTestSmsByPrefix 载荷键 ----
  const val KEY_OK = "ok"
  const val KEY_IDS = "ids"
  const val KEY_DELETED = "deleted"

  // ---- querySms 载荷键 ----
  const val KEY_MESSAGES = "messages"
  const val KEY_TOTAL = "total"
  const val KEY_ERROR = "error"
}
