package com.dc16.sms

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * 通道线值快照：与 `lib/services/channel_codes.dart` / `docs/CHANNEL_CONTRACT.md` 对齐。
 * 改线值是 Breaking，必须双端同步；本测试锁死字面量，防止误改。
 */
class ChannelCodesTest {

  @Test
  fun `setDefaultSms wire values`() {
    assertEquals("had", ChannelCodes.SET_DEFAULT_HAD)
    assertEquals("no", ChannelCodes.SET_DEFAULT_NO)
    assertEquals("error", ChannelCodes.ERROR)
  }

  @Test
  fun `restoreDefaultSms wire values`() {
    assertEquals("not_default", ChannelCodes.RESTORE_NOT_DEFAULT)
    assertEquals("settings", ChannelCodes.RESTORE_SETTINGS)
  }

  @Test
  fun `miuiNotificationSmsState wire values`() {
    assertEquals("allow", ChannelCodes.MIUI_ALLOW)
    assertEquals("likely_off", ChannelCodes.MIUI_LIKELY_OFF)
    assertEquals("ignore", ChannelCodes.MIUI_IGNORE)
    assertEquals("deny", ChannelCodes.MIUI_DENY)
    assertEquals("unknown", ChannelCodes.MIUI_UNKNOWN)
  }

  @Test
  fun `querySms error wire values`() {
    assertEquals("permission", ChannelCodes.QUERY_ERROR_PERMISSION)
    assertEquals("unknown", ChannelCodes.QUERY_ERROR_UNKNOWN)
  }

  @Test
  fun `querySms partial and warnings wire values`() {
    assertEquals("partial", ChannelCodes.KEY_PARTIAL)
    assertEquals("warnings", ChannelCodes.KEY_WARNINGS)
    assertEquals("sms_uri_security", ChannelCodes.WARN_SMS_URI_SECURITY)
    assertEquals("sms_uri_failed", ChannelCodes.WARN_SMS_URI_FAILED)
    assertEquals("mms_uri_security", ChannelCodes.WARN_MMS_URI_SECURITY)
    assertEquals("mms_uri_failed", ChannelCodes.WARN_MMS_URI_FAILED)
    assertEquals("mms_addr_failed", ChannelCodes.WARN_MMS_ADDR_FAILED)
    assertEquals("mms_part_failed", ChannelCodes.WARN_MMS_PART_FAILED)
    assertEquals("unknown", ChannelCodes.WARN_UNKNOWN)
  }

  @Test
  fun `PlatformException error codes`() {
    assertEquals("lifecycle", ChannelCodes.ERROR_LIFECYCLE)
    assertEquals("error", ChannelCodes.ERROR)
  }

  @Test
  fun `payload keys`() {
    assertEquals("ok", ChannelCodes.KEY_OK)
    assertEquals("ids", ChannelCodes.KEY_IDS)
    assertEquals("deleted", ChannelCodes.KEY_DELETED)
    assertEquals("messages", ChannelCodes.KEY_MESSAGES)
    assertEquals("total", ChannelCodes.KEY_TOTAL)
    assertEquals("error", ChannelCodes.KEY_ERROR)
    assertEquals("partial", ChannelCodes.KEY_PARTIAL)
    assertEquals("warnings", ChannelCodes.KEY_WARNINGS)
    assertEquals("inserted", ChannelCodes.KEY_INSERTED)
    assertEquals("failed", ChannelCodes.KEY_FAILED)
    assertEquals("errors", ChannelCodes.KEY_ERRORS)
    assertEquals("index", ChannelCodes.KEY_INDEX)
    assertEquals("code", ChannelCodes.KEY_CODE)
    assertEquals("message", ChannelCodes.KEY_MESSAGE)
  }

  @Test
  fun `insertSmsBatch error codes`() {
    assertEquals("not_default", ChannelCodes.INSERT_ERROR_NOT_DEFAULT)
    assertEquals("failed", ChannelCodes.INSERT_ERROR_FAILED)
    assertEquals("invalid", ChannelCodes.INSERT_ERROR_INVALID)
    assertEquals("unknown", ChannelCodes.INSERT_ERROR_UNKNOWN)
  }

  @Test
  fun `deleteSmsBatch error codes`() {
    assertEquals("not_default", ChannelCodes.DELETE_ERROR_NOT_DEFAULT)
    assertEquals("failed", ChannelCodes.DELETE_ERROR_FAILED)
    assertEquals("unknown", ChannelCodes.DELETE_ERROR_UNKNOWN)
  }

  @Test
  fun `wire constants stay unique per role even when strings collide`() {
    // 同字面量允许多语境复用，但每个常量必须解析为文档约定值。
    assertEquals(ChannelCodes.ERROR, ChannelCodes.KEY_ERROR)
    assertEquals(ChannelCodes.MIUI_UNKNOWN, ChannelCodes.QUERY_ERROR_UNKNOWN)
    assertEquals(ChannelCodes.RESTORE_NOT_DEFAULT, ChannelCodes.INSERT_ERROR_NOT_DEFAULT)
    assertEquals(ChannelCodes.INSERT_ERROR_NOT_DEFAULT, ChannelCodes.DELETE_ERROR_NOT_DEFAULT)
    assertEquals(ChannelCodes.INSERT_ERROR_FAILED, ChannelCodes.DELETE_ERROR_FAILED)
    assertEquals(ChannelCodes.INSERT_ERROR_UNKNOWN, ChannelCodes.DELETE_ERROR_UNKNOWN)
    assertEquals(ChannelCodes.INSERT_ERROR_FAILED, "failed")
    assertEquals(ChannelCodes.INSERT_ERROR_UNKNOWN, "unknown")
  }
}
