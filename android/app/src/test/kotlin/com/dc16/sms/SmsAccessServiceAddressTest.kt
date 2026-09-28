package com.dc16.sms

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** [SmsAccess.looksLikeServiceAddress]：服务号 / 非手机号启发式。 */
class SmsAccessServiceAddressTest {

  private val access = SmsAccess(
    mockSmsContext(
      resolver = org.mockito.kotlin.mock(),
      defaultSms = true,
      debuggable = true,
    ),
  )

  @Test
  fun `service short codes are service addresses`() {
    assertTrue(access.looksLikeServiceAddress("10086"))
    assertTrue(access.looksLikeServiceAddress("95566"))
    assertTrue(access.looksLikeServiceAddress("106900"))
    assertTrue(access.looksLikeServiceAddress("106550"))
  }

  @Test
  fun `short numeric codes are service addresses`() {
    assertTrue(access.looksLikeServiceAddress("123456"))
    assertTrue(access.looksLikeServiceAddress("95588"))
  }

  @Test
  fun `plain mobile numbers are not service addresses`() {
    assertFalse(access.looksLikeServiceAddress("13800001111"))
    assertFalse(access.looksLikeServiceAddress("18612345678"))
  }

  @Test
  fun `e164 mobile numbers are not service addresses`() {
    assertFalse(access.looksLikeServiceAddress("+8613800001111"))
    assertFalse(access.looksLikeServiceAddress("+13800001111"))
  }

  @Test
  fun `alphanumeric sender ids are service addresses`() {
    assertTrue(access.looksLikeServiceAddress("WeChat"))
    assertTrue(access.looksLikeServiceAddress("106xxx"))
    assertTrue(access.looksLikeServiceAddress("TD-Notify"))
    assertTrue(access.looksLikeServiceAddress("12345abc"))
  }

  @Test
  fun `blank and empty are not service addresses`() {
    assertFalse(access.looksLikeServiceAddress(""))
    assertFalse(access.looksLikeServiceAddress("   "))
    assertFalse(access.looksLikeServiceAddress("\t"))
  }

  @Test
  fun `leading and trailing whitespace is trimmed`() {
    assertTrue(access.looksLikeServiceAddress(" 10086 "))
    assertFalse(access.looksLikeServiceAddress(" 13800001111 "))
  }

  @Test
  fun `seven-digit pure number is treated as mobile-range not service`() {
    // 7–15 位纯数字（可带 +）走手机号格式；7 位刚好落入该区间。
    assertFalse(access.looksLikeServiceAddress("1234567"))
    assertTrue(access.looksLikeServiceAddress("123456"))
  }

  @Test
  fun `too-long digit strings are service addresses`() {
    // >15 位不匹配手机号格式 → 按服务号/异常号处理。
    assertTrue(access.looksLikeServiceAddress("1234567890123456"))
  }
}
