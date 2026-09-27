package com.davidche1116.sms

import android.content.ContentResolver
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.mockito.kotlin.anyOrNull
import org.mockito.kotlin.mock
import org.mockito.kotlin.whenever

/**
 * [SmsAccess.readRow] 映射 + [SmsAccess.querySms] 去重 / 排序 / 分片。
 *
 * ContentResolver 用手写 Mock + [FakeCursor]，不依赖 Robolectric/真机 Provider。
 */
class SmsAccessQueryTest {

  private fun accessWith(
    resolver: ContentResolver,
    defaultSms: Boolean = true,
  ): SmsAccess = SmsAccess(mockSmsContext(resolver, defaultSms = defaultSms))

  // ---- readRow ----

  @Test
  fun `readRow maps all projection columns`() {
    val access = accessWith(mock())
    val c = smsCursor(
      listOf(7L, 3L, "10086", "hi", 1_700_000_000_000L, 1_699_999_999_000L, 1, 2, 5),
    )
    c.moveToNext()
    val row = access.readRow(c)
    assertEquals(7, row["_id"])
    assertEquals(3, row["thread_id"])
    assertEquals("10086", row["address"])
    assertEquals("hi", row["body"])
    assertEquals(1_700_000_000_000L, row["date"])
    assertEquals(1_699_999_999_000L, row["date_sent"])
    assertEquals(1, row["read"])
    assertEquals(2, row["type"])
    assertEquals(5, row["sub_id"])
  }

  @Test
  fun `readRow maps missing and null columns to null`() {
    val access = accessWith(mock())
    // 缺列 + 列值为 null：都应映射为 null，而不是 NPE / 0。
    val c = FakeCursor(
      listOf("_id", "address", "body", "date"),
      listOf(listOf(1L, "10086", null, null)),
    )
    c.moveToNext()
    val row = access.readRow(c)
    assertEquals(1, row["_id"])
    assertEquals("10086", row["address"])
    assertNull(row["body"])
    assertNull(row["date"])
    assertNull(row["thread_id"])
    assertNull(row["sub_id"])
    assertNull(row["read"])
    assertNull(row["type"])
    assertNull(row["date_sent"])
  }

  @Test
  fun `readRow drops rows without usable _id when queried`() {
    val resolver = mock<ContentResolver>()
    whenever(resolver.query(anyOrNull(), anyOrNull(), anyOrNull(), anyOrNull(), anyOrNull()))
      .thenReturn(
        smsCursor(listOf(null, 1L, "a", "row-no-id", 100L, 100L, 1, 1, 1)),
        null, null, null,
      )
    val access = accessWith(resolver)
    val r = access.querySms(null)
    assertEquals(0, r[ChannelCodes.KEY_TOTAL])
    assertTrue((r[ChannelCodes.KEY_MESSAGES] as List<*>).isEmpty())
    assertNull(r[ChannelCodes.KEY_ERROR])
  }

  // ---- querySms：去重 ----

  @Test
  fun `querySms dedups rows shared across sms inbox sent draft uris`() {
    val resolver = mock<ContentResolver>()
    // 同一 _id=2 在 CONTENT_URI 与 Inbox 各出现一次；_id=1 只在 Sent。
    whenever(resolver.query(anyOrNull(), anyOrNull(), anyOrNull(), anyOrNull(), anyOrNull()))
      .thenReturn(
        smsCursor(
          smsRow(id = 2, body = "from-content", date = 200L),
          smsRow(id = 1, body = "from-content-1", date = 100L),
        ),
        smsCursor(smsRow(id = 2, body = "from-inbox-dup", date = 200L)),
        smsCursor(smsRow(id = 1, body = "from-sent-dup", date = 100L)),
        null,
      )
    val access = accessWith(resolver)
    val r = access.querySms(null)
    @Suppress("UNCHECKED_CAST")
    val messages = r[ChannelCodes.KEY_MESSAGES] as List<Map<String, Any?>>
    assertEquals(2, r[ChannelCodes.KEY_TOTAL])
    assertEquals(2, messages.size)
    // 先出现的保留（putIfAbsent）
    assertEquals("from-content", messages.first { it["_id"] == 2 }["body"])
    assertEquals("from-content-1", messages.first { it["_id"] == 1 }["body"])
    assertNull(r[ChannelCodes.KEY_ERROR])
  }

  // ---- querySms：排序 ----

  @Test
  fun `querySms sorts by date desc then _id desc`() {
    val resolver = mock<ContentResolver>()
    whenever(resolver.query(anyOrNull(), anyOrNull(), anyOrNull(), anyOrNull(), anyOrNull()))
      .thenReturn(
        smsCursor(
          smsRow(id = 1, date = 100L),
          smsRow(id = 3, date = 300L),
          smsRow(id = 2, date = 200L),
        ),
        null, null, null,
      )
    val access = accessWith(resolver)
    @Suppress("UNCHECKED_CAST")
    val messages = access.querySms(null)[ChannelCodes.KEY_MESSAGES] as List<Map<String, Any?>>
    assertEquals(listOf(3, 2, 1), messages.map { it["_id"] })
  }

  @Test
  fun `querySms tie-breaks equal date by _id desc`() {
    val resolver = mock<ContentResolver>()
    whenever(resolver.query(anyOrNull(), anyOrNull(), anyOrNull(), anyOrNull(), anyOrNull()))
      .thenReturn(
        smsCursor(
          smsRow(id = 1, date = 100L),
          smsRow(id = 9, date = 100L),
          smsRow(id = 5, date = 100L),
        ),
        null, null, null,
      )
    val access = accessWith(resolver)
    @Suppress("UNCHECKED_CAST")
    val messages = access.querySms(null)[ChannelCodes.KEY_MESSAGES] as List<Map<String, Any?>>
    assertEquals(listOf(9, 5, 1), messages.map { it["_id"] })
  }

  @Test
  fun `querySms treats null date as oldest`() {
    val resolver = mock<ContentResolver>()
    whenever(resolver.query(anyOrNull(), anyOrNull(), anyOrNull(), anyOrNull(), anyOrNull()))
      .thenReturn(
        smsCursor(
          smsRow(id = 1, date = null),
          smsRow(id = 2, date = 50L),
          smsRow(id = 3, date = null),
        ),
        null, null, null,
      )
    val access = accessWith(resolver)
    @Suppress("UNCHECKED_CAST")
    val messages = access.querySms(null)[ChannelCodes.KEY_MESSAGES] as List<Map<String, Any?>>
    assertEquals(listOf(2, 3, 1), messages.map { it["_id"] })
  }

  // ---- querySms：分片 ----

  @Test
  fun `querySms pages by limit and offset after global sort`() {
    val resolver = mock<ContentResolver>()
    // 乱序 5 条，date=5..1 对应 id=1..5。每次 query 返回新 Cursor：
    // 本用例连续调用 querySms 多次，共用单个 Cursor 会被消耗掉。
    whenever(resolver.query(anyOrNull(), anyOrNull(), anyOrNull(), anyOrNull(), anyOrNull()))
      .thenAnswer {
        smsCursor(
          smsRow(id = 2, date = 4L),
          smsRow(id = 5, date = 1L),
          smsRow(id = 1, date = 5L),
          smsRow(id = 4, date = 2L),
          smsRow(id = 3, date = 3L),
        )
      }
    val access = accessWith(resolver)

    val page0 = access.querySms(null, limit = 2, offset = 0)
    @Suppress("UNCHECKED_CAST")
    val m0 = page0[ChannelCodes.KEY_MESSAGES] as List<Map<String, Any?>>
    assertEquals(5, page0[ChannelCodes.KEY_TOTAL])
    assertEquals(listOf(1, 2), m0.map { it["_id"] })

    val page1 = access.querySms(null, limit = 2, offset = 2)
    @Suppress("UNCHECKED_CAST")
    val m1 = page1[ChannelCodes.KEY_MESSAGES] as List<Map<String, Any?>>
    assertEquals(5, page1[ChannelCodes.KEY_TOTAL])
    assertEquals(listOf(3, 4), m1.map { it["_id"] })

    val page2 = access.querySms(null, limit = 2, offset = 4)
    @Suppress("UNCHECKED_CAST")
    val m2 = page2[ChannelCodes.KEY_MESSAGES] as List<Map<String, Any?>>
    assertEquals(5, page2[ChannelCodes.KEY_TOTAL])
    assertEquals(listOf(5), m2.map { it["_id"] })

    // limit=null → 全量
    val all = access.querySms(null, limit = null)
    @Suppress("UNCHECKED_CAST")
    val ma = all[ChannelCodes.KEY_MESSAGES] as List<Map<String, Any?>>
    assertEquals(5, ma.size)
  }

  @Test
  fun `querySms limit zero returns empty page but keeps total`() {
    val resolver = mock<ContentResolver>()
    whenever(resolver.query(anyOrNull(), anyOrNull(), anyOrNull(), anyOrNull(), anyOrNull()))
      .thenReturn(smsCursor(smsRow(id = 1), smsRow(id = 2)), null, null, null)
    val access = accessWith(resolver)
    val r = access.querySms(null, limit = 0, offset = 0)
    @Suppress("UNCHECKED_CAST")
    val messages = r[ChannelCodes.KEY_MESSAGES] as List<Map<String, Any?>>
    assertEquals(2, r[ChannelCodes.KEY_TOTAL])
    assertTrue(messages.isEmpty())
  }

  @Test
  fun `querySms negative offset is coerced to zero`() {
    val resolver = mock<ContentResolver>()
    whenever(resolver.query(anyOrNull(), anyOrNull(), anyOrNull(), anyOrNull(), anyOrNull()))
      .thenReturn(
        smsCursor(smsRow(id = 1, date = 2L), smsRow(id = 2, date = 1L)),
        null, null, null,
      )
    val access = accessWith(resolver)
    val r = access.querySms(null, limit = 10, offset = -5)
    @Suppress("UNCHECKED_CAST")
    val messages = r[ChannelCodes.KEY_MESSAGES] as List<Map<String, Any?>>
    assertEquals(listOf(1, 2), messages.map { it["_id"] })
  }

  // ---- querySms：address 过滤与错误 ----

  @Test
  fun `querySms passes address filter through to provider`() {
    val resolver = mock<ContentResolver>()
    val cursor = smsCursor(smsRow(id = 1, address = "10086"))
    whenever(resolver.query(anyOrNull(), anyOrNull(), anyOrNull(), anyOrNull(), anyOrNull()))
      .thenReturn(cursor, null, null, null)
    val access = accessWith(resolver)
    access.querySms("10086")
    // 至少一次调用带上 ADDRESS=? 过滤
    org.mockito.kotlin.verify(resolver, org.mockito.kotlin.atLeastOnce()).query(
      anyOrNull(),
      anyOrNull(),
      org.mockito.kotlin.eq("address=?"),
      org.mockito.kotlin.eq(arrayOf("10086")),
      anyOrNull(),
    )
  }

  @Test
  fun `querySms empty address queries unfiltered`() {
    val resolver = mock<ContentResolver>()
    whenever(resolver.query(anyOrNull(), anyOrNull(), anyOrNull(), anyOrNull(), anyOrNull()))
      .thenReturn(null, null, null, null)
    val access = accessWith(resolver)
    access.querySms("")
    org.mockito.kotlin.verify(resolver, org.mockito.kotlin.atLeastOnce()).query(
      anyOrNull(),
      anyOrNull(),
      org.mockito.kotlin.isNull(),
      org.mockito.kotlin.isNull(),
      anyOrNull(),
    )
  }

  @Test
  fun `querySms security exception with no rows reports permission error`() {
    val resolver = mock<ContentResolver>()
    whenever(resolver.query(anyOrNull(), anyOrNull(), anyOrNull(), anyOrNull(), anyOrNull()))
      .thenThrow(SecurityException("no sms"))
    // 无读权限且非默认 → 早退，不会走到 provider
    val access = SmsAccess(mockSmsContext(resolver, defaultSms = false))
    // 强制走 provider：isDefaultSms=false 但 hasReadSms 因 AppOps catch 返回 true。
    // 若 hasReadSms 也为 false，则早退 permission。两种路径 error 都是 permission。
    val r = access.querySms(null)
    assertEquals(ChannelCodes.QUERY_ERROR_PERMISSION, r[ChannelCodes.KEY_ERROR])
    assertEquals(0, r[ChannelCodes.KEY_TOTAL])
    @Suppress("UNCHECKED_CAST")
    assertTrue((r[ChannelCodes.KEY_MESSAGES] as List<*>).isEmpty())
  }

  @Test
  fun `querySms generic exception with no rows reports unknown error`() {
    val resolver = mock<ContentResolver>()
    whenever(resolver.query(anyOrNull(), anyOrNull(), anyOrNull(), anyOrNull(), anyOrNull()))
      .thenThrow(RuntimeException("provider dead"))
    val access = accessWith(resolver)
    val r = access.querySms(null)
    assertEquals(ChannelCodes.QUERY_ERROR_UNKNOWN, r[ChannelCodes.KEY_ERROR])
  }

  @Test
  fun `querySms error is null when any row was read even if another uri returned none`() {
    val resolver = mock<ContentResolver>()
    whenever(resolver.query(anyOrNull(), anyOrNull(), anyOrNull(), anyOrNull(), anyOrNull()))
      .thenReturn(smsCursor(smsRow(id = 1)), null, null, null)
    val access = accessWith(resolver)
    val r = access.querySms(null)
    // 有数据则 error 必须为 null
    assertNull(r[ChannelCodes.KEY_ERROR])
    assertEquals(1, r[ChannelCodes.KEY_TOTAL])
  }

  @Test
  fun `querySms empty store reports empty success`() {
    val resolver = mock<ContentResolver>()
    whenever(resolver.query(anyOrNull(), anyOrNull(), anyOrNull(), anyOrNull(), anyOrNull()))
      .thenReturn(null, null, null, null)
    val access = accessWith(resolver)
    val r = access.querySms(null)
    assertNull(r[ChannelCodes.KEY_ERROR])
    assertEquals(0, r[ChannelCodes.KEY_TOTAL])
    assertTrue((r[ChannelCodes.KEY_MESSAGES] as List<*>).isEmpty())
  }

  @Test
  fun `querySms payload always has messages total error keys`() {
    val resolver = mock<ContentResolver>()
    whenever(resolver.query(anyOrNull(), anyOrNull(), anyOrNull(), anyOrNull(), anyOrNull()))
      .thenReturn(null, null, null, null)
    val access = accessWith(resolver)
    val r = access.querySms(null)
    assertEquals(setOf(ChannelCodes.KEY_MESSAGES, ChannelCodes.KEY_TOTAL, ChannelCodes.KEY_ERROR), r.keys)
  }
}
