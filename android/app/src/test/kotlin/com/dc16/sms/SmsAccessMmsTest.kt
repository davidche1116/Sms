package com.dc16.sms

import android.content.ContentResolver
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.mockito.kotlin.anyOrNull
import org.mockito.kotlin.mock
import org.mockito.kotlin.verify
import org.mockito.kotlin.whenever

/**
 * 彩信：[SmsAccess.readMmsRow] 映射、date 秒→毫秒、
 * [SmsAccess.splitDeleteTargets] 删除路由、正文 part 拼接与 address 补全。
 */
class SmsAccessMmsTest {

  private fun accessWith(
    resolver: ContentResolver,
    defaultSms: Boolean = true,
  ): SmsAccess = SmsAccess(mockSmsContext(resolver, defaultSms = defaultSms))

  // ---- readMmsRow ----

  @Test
  fun `readMmsRow maps metadata and converts date seconds to ms`() {
    val access = accessWith(mock())
    val c = mmsCursor(mmsRow(id = 7, threadId = 3, dateSec = 1_700_000_000L, msgBox = 2, subId = 5))
    c.moveToNext()
    val row = access.readMmsRow(c)!!
    assertEquals(7, row["_id"])
    assertEquals(3, row["thread_id"])
    assertEquals(1_700_000_000_000L, row["date"])
    assertEquals(1_700_000_000_000L, row["date_sent"])
    assertEquals(1, row["read"])
    assertEquals(2, row["type"])
    assertEquals(5, row["sub_id"])
    assertEquals(1, row["is_mms"])
    // address / body 留给 enrich 阶段补全
    assertNull(row["address"])
    assertNull(row["body"])
  }

  @Test
  fun `readMmsRow keeps date when already in ms`() {
    val access = accessWith(mock())
    val ms = 1_700_000_000_000L
    val c = mmsCursor(mmsRow(id = 1, dateSec = ms))
    c.moveToNext()
    assertEquals(ms, access.readMmsRow(c)!!["date"])
  }

  @Test
  fun `readMmsRow rejects non-mms schema cursor`() {
    val access = accessWith(mock())
    val c = smsCursor(smsRow(id = 1))
    c.moveToNext()
    // SMS Cursor 无 msg_box 列 → null，不进合并结果
    assertNull(access.readMmsRow(c))
  }

  @Test
  fun `mmsDateToMs scales seconds and passes large values`() {
    val access = accessWith(mock())
    assertEquals(1_700_000_000_000L, access.mmsDateToMs(1_700_000_000L))
    assertEquals(1_700_000_000_000L, access.mmsDateToMs(1_700_000_000_000L))
    assertNull(access.mmsDateToMs(null))
    assertEquals(0L, access.mmsDateToMs(0L))
  }

  // ---- splitDeleteTargets / isMmsFlag ----

  @Test
  fun `splitDeleteTargets treats bare numbers as sms`() {
    val access = accessWith(mock())
    val (sms, mms) = access.splitDeleteTargets(listOf(1, 2, 3))
    assertEquals(listOf(1, 2, 3), sms.map { it.id })
    assertEquals(listOf(0, 1, 2), sms.map { it.index })
    assertTrue(mms.isEmpty())
  }

  @Test
  fun `splitDeleteTargets routes maps by is_mms`() {
    val access = accessWith(mock())
    val (sms, mms) = access.splitDeleteTargets(
      listOf(
        mapOf("id" to 10, "is_mms" to 0),
        mapOf("id" to 20, "is_mms" to 1),
        mapOf("id" to 30, "is_mms" to true),
        mapOf("id" to 40, "is_mms" to false),
        mapOf("id" to 50), // 缺省 = SMS
      ),
    )
    assertEquals(listOf(10, 40, 50), sms.map { it.id })
    assertEquals(listOf(20, 30), mms.map { it.id })
  }

  @Test
  fun `splitDeleteTargets drops malformed entries instead of guessing`() {
    val access = accessWith(mock())
    val (sms, mms) = access.splitDeleteTargets(
      listOf(
        mapOf("is_mms" to 1), // 无 id
        mapOf("id" to "x", "is_mms" to 1), // id 非数
        "junk",
        null,
        mapOf("id" to 1, "is_mms" to 1),
      ),
    )
    assertTrue(sms.isEmpty())
    assertEquals(listOf(1), mms.map { it.id })
    // 保留原入参下标（4），供 errors[].index 对齐
    assertEquals(listOf(4), mms.map { it.index })
  }

  @Test
  fun `isMmsFlag accepts only 1 and true`() {
    val access = accessWith(mock())
    assertTrue(access.isMmsFlag(1))
    assertTrue(access.isMmsFlag(true))
    assertFalse(access.isMmsFlag(0))
    assertFalse(access.isMmsFlag(false))
    assertFalse(access.isMmsFlag(null))
    assertFalse(access.isMmsFlag("1"))
    assertFalse(access.isMmsFlag(2))
  }

  // ---- deleteSmsBatch 路由与 chunk ----

  @Test
  fun `deleteSmsBatch mixed targets chunk each side separately`() {
    val resolver = mock<ContentResolver>()
    val chunks = stubDeleteCounting(resolver)
    val access = accessWith(resolver)
    val targets = buildList<Any?> {
      // 901 个 SMS → 900 + 1
      for (i in 1..901) add(i)
      // 500 个 MMS → 1 chunk
      for (i in 1..500) add(mapOf("id" to i, "is_mms" to 1))
    }
    val r = access.deleteSmsBatch(targets)
    assertEquals(true, r[ChannelCodes.KEY_OK])
    assertEquals(1401, r[ChannelCodes.KEY_DELETED])
    assertEquals(listOf(900, 1, 500), chunks.map { it.size })
  }

  @Test
  fun `deleteSmsBatch pure sms list stays backward compatible`() {
    val resolver = mock<ContentResolver>()
    val chunks = stubDeleteCounting(resolver)
    val access = accessWith(resolver)
    val r = access.deleteSmsBatch(listOf(1, 2, 3))
    assertEquals(3, r[ChannelCodes.KEY_DELETED])
    assertEquals(listOf(3), chunks.map { it.size })
  }

  @Test
  fun `deleteSmsBatch with only mms maps never touches sms path first`() {
    val resolver = mock<ContentResolver>()
    val chunks = stubDeleteCounting(resolver)
    val access = accessWith(resolver)
    val r = access.deleteSmsBatch(listOf(mapOf("id" to 9, "is_mms" to 1)))
    assertEquals(1, r[ChannelCodes.KEY_DELETED])
    assertEquals(listOf(1), chunks.map { it.size })
  }

  // ---- querySms 合并 ----

  @Test
  fun `querySms merges sms and mms with same _id without collision`() {
    val resolver = mock<ContentResolver>()
    val stub = SmsProviderStub().apply {
      // SMS _id=1 与 MMS _id=1 必须都保留（身份 = _id + is_mms）
      sms = listOf(smsRow(id = 1, body = "sms-1", date = 200L))
      mms = listOf(mmsRow(id = 1, dateSec = 1L)) // date 秒=1 → ms=1000
    }
    stub.install(resolver)
    val access = accessWith(resolver)
    val r = access.querySms(null)
    @Suppress("UNCHECKED_CAST")
    val messages = r[ChannelCodes.KEY_MESSAGES] as List<Map<String, Any?>>
    assertEquals(2, r[ChannelCodes.KEY_TOTAL])
    assertEquals(2, messages.size)
    val sms = messages.first { it["is_mms"] == 0 }
    val mms = messages.first { it["is_mms"] == 1 }
    assertEquals("sms-1", sms["body"])
    assertEquals(1, sms["_id"])
    assertEquals(1, mms["_id"])
    assertEquals(1000L, mms["date"])
    // date 降序：MMS 1000ms 先于 SMS 200ms
    assertEquals(listOf(1, 0), messages.map { it["is_mms"] })
  }

  @Test
  fun `querySms sorts mixed rows by date desc then is_mms desc then id desc`() {
    val resolver = mock<ContentResolver>()
    val stub = SmsProviderStub().apply {
      sms = listOf(smsRow(id = 2, date = 300L), smsRow(id = 1, date = 100L))
      mms = listOf(mmsRow(id = 5, dateSec = 0L), mmsRow(id = 3, dateSec = 0L))
    }
    stub.install(resolver)
    val access = accessWith(resolver)
    @Suppress("UNCHECKED_CAST")
    val messages = access.querySms(null)[ChannelCodes.KEY_MESSAGES] as List<Map<String, Any?>>
    // date: 300(SMS2) > 100(SMS1) > 0(MMS5, MMS3)
    assertEquals(listOf(2, 1, 5, 3), messages.map { it["_id"] })
  }

  @Test
  fun `querySms total includes mms and paging covers both`() {
    val resolver = mock<ContentResolver>()
    val stub = SmsProviderStub().apply {
      sms = listOf(smsRow(id = 1, date = 500L))
      mms = listOf(mmsRow(id = 1, dateSec = 1L)) // 1000ms
    }
    stub.install(resolver)
    val access = accessWith(resolver)
    val r = access.querySms(null, limit = 1, offset = 0)
    @Suppress("UNCHECKED_CAST")
    val page = r[ChannelCodes.KEY_MESSAGES] as List<Map<String, Any?>>
    assertEquals(2, r[ChannelCodes.KEY_TOTAL])
    assertEquals(1, page.size)
    // date 1000ms > 500ms → MMS 先
    assertEquals(1, page[0]["is_mms"])
  }

  @Test
  fun `querySms enriches mms body and address from part and addr tables`() {
    val resolver = mock<ContentResolver>()
    val stub = SmsProviderStub().apply {
      mms = listOf(mmsRow(id = 42, dateSec = 1L))
      mmsAddr = listOf(listOf(42, "10086", 137))
      mmsPart = listOf(
        listOf(42, "text/plain", "你好呀", null),
        listOf(42, "image/png", null, "/data/x.png"),
      )
    }
    stub.install(resolver)
    val access = accessWith(resolver)
    @Suppress("UNCHECKED_CAST")
    val messages = access.querySms(null)[ChannelCodes.KEY_MESSAGES] as List<Map<String, Any?>>
    assertEquals(1, messages.size)
    val row = messages[0]
    assertEquals(1, row["is_mms"])
    assertEquals("10086", row["address"])
    assertEquals("你好呀", row["body"])
    assertEquals(1, row["has_media"])
  }

  @Test
  fun `querySms mms without text parts falls back to empty body and media flag`() {
    val resolver = mock<ContentResolver>()
    val stub = SmsProviderStub().apply {
      mms = listOf(mmsRow(id = 9, dateSec = 1L))
      mmsAddr = listOf(listOf(9, "139", 151))
      mmsPart = listOf(listOf(9, "application/smil", "<smil/>", null))
    }
    stub.install(resolver)
    val access = accessWith(resolver)
    @Suppress("UNCHECKED_CAST")
    val messages = access.querySms(null)[ChannelCodes.KEY_MESSAGES] as List<Map<String, Any?>>
    val row = messages.single()
    assertEquals("", row["body"])
    assertEquals(0, row["has_media"])
    assertEquals("139", row["address"])
  }

  @Test
  fun `querySms concatenates multiple text parts`() {
    val resolver = mock<ContentResolver>()
    val stub = SmsProviderStub().apply {
      mms = listOf(mmsRow(id = 1, dateSec = 1L))
      mmsPart = listOf(
        listOf(1, "text/plain", "第一段", null),
        listOf(1, "text/plain", "第二段", null),
        listOf(1, "text/x-vcard", "BEGIN:VCARD", null),
      )
    }
    stub.install(resolver)
    val access = accessWith(resolver)
    @Suppress("UNCHECKED_CAST")
    val messages = access.querySms(null)[ChannelCodes.KEY_MESSAGES] as List<Map<String, Any?>>
    assertEquals("第一段\n第二段\nBEGIN:VCARD", messages.single()["body"])
  }

  @Test
  fun `querySms address filter matches mms via addr table`() {
    val resolver = mock<ContentResolver>()
    val stub = SmsProviderStub().apply {
      // SQL `_id IN` 已由 Provider 过滤，这里只回命中行
      mms = listOf(mmsRow(id = 42, dateSec = 1L))
      mmsAddrIds = listOf(listOf(42, "10086", 137))
      mmsAddr = listOf(listOf(42, "10086", 137))
      mmsPart = listOf(listOf(42, "text/plain", "命中", null))
    }
    stub.install(resolver)
    val access = accessWith(resolver)
    val r = access.querySms("10086")
    @Suppress("UNCHECKED_CAST")
    val messages = r[ChannelCodes.KEY_MESSAGES] as List<Map<String, Any?>>
    assertEquals(1, r[ChannelCodes.KEY_TOTAL])
    assertEquals(42, messages.single()["_id"])
    assertEquals("10086", messages.single()["address"])
    // addr 预取必须按 address=? 查 msg_id
    assertTrue(stub.queryLog.any { it.kind == "addrIds" && it.selection == "address=?" })
    // 主表用 `_id IN` 下推过滤
    assertTrue(stub.queryLog.filter { it.kind == "mms" }.all { it.selection!!.startsWith("_id IN") })
  }

  @Test
  fun `querySms mms address filter empty result skips mms scan`() {
    val resolver = mock<ContentResolver>()
    var mmsTableQueries = 0
    whenever(resolver.query(anyOrNull(), anyOrNull(), anyOrNull(), anyOrNull(), anyOrNull()))
      .thenAnswer { inv ->
        val proj = inv.getArgument<Array<String>?>(1)?.toList()
        when {
          proj != null && proj.size == 1 && proj[0] == "msg_id" -> null // addr 无匹配
          proj != null && proj.contains("msg_box") -> {
            mmsTableQueries++
            mmsCursor(mmsRow(id = 1, dateSec = 1L)) // 不应被读到
          }
          proj != null && proj.contains("body") -> smsCursor()
          else -> null
        }
      }
    val access = accessWith(resolver)
    val r = access.querySms("999999")
    assertEquals(0, r[ChannelCodes.KEY_TOTAL])
    // MMS 主表不应再被扫（addr 过滤为空）
    assertEquals(0, mmsTableQueries)
  }

  @Test
  fun `querySms pushes _id IN selection for small mms addr filter`() {
    val resolver = mock<ContentResolver>()
    val stub = SmsProviderStub().apply {
      mms = listOf(mmsRow(id = 42, dateSec = 1L))
      mmsAddrIds = listOf(listOf(42, "10086", 137))
      mmsAddr = listOf(listOf(42, "10086", 137))
      mmsPart = listOf(listOf(42, "text/plain", "命中", null))
    }
    stub.install(resolver)
    val access = accessWith(resolver)
    access.querySms("10086")
    val mmsQ = stub.queryLog.filter { it.kind == "mms" }
    assertTrue(mmsQ.isNotEmpty())
    assertTrue(mmsQ.all { it.selection?.startsWith("_id IN") == true })
  }

  @Test
  fun `querySms enriches only current page mms not full library`() {
    val resolver = mock<ContentResolver>()
    // 2 条彩信，只取第 1 页 1 条：addr/part 只应查本页那 1 个 id
    val stub = SmsProviderStub().apply {
      mms = listOf(mmsRow(id = 1, dateSec = 2L), mmsRow(id = 2, dateSec = 1L))
      mmsAddr = listOf(listOf(1, "a", 137), listOf(2, "b", 137))
      mmsPart = listOf(listOf(1, "text/plain", "p1", null), listOf(2, "text/plain", "p2", null))
    }
    stub.install(resolver)
    val access = accessWith(resolver)
    val r = access.querySms(null, limit = 1, offset = 0)
    @Suppress("UNCHECKED_CAST")
    val page = r[ChannelCodes.KEY_MESSAGES] as List<Map<String, Any?>>
    assertEquals(1, page.size)
    assertEquals(1, page[0]["_id"])
    assertEquals("p1", page[0]["body"])
    // 本页 enrich：addr/part 的 selectionArgs 只含 id=1，不含 id=2
    val enrich = stub.queryLog.filter { it.kind == "addr" || it.kind == "part" }
    assertTrue(enrich.isNotEmpty())
    val ids = enrich.flatMap { it.args.orEmpty() }.toSet()
    assertEquals(setOf("1"), ids)
    assertFalse("2" in ids)
  }
}
