package com.dc16.sms

import android.content.ContentResolver
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.mockito.kotlin.anyOrNull
import org.mockito.kotlin.mock
import org.mockito.kotlin.never
import org.mockito.kotlin.verify
import org.mockito.kotlin.whenever

/**
 * [SmsAccess.readRow] 映射 + [SmsAccess.querySms] 真分页 / 单 URI / 回落 / 排序。
 *
 * ContentResolver 用手写 Mock + [FakeCursor]，不依赖 Robolectric/真机 Provider。
 * 行数据按 Provider 顺序（date DESC, _id DESC）提供，与 sortOrder 契约一致。
 */
class SmsAccessQueryTest {

  private fun accessWith(
    resolver: ContentResolver,
    defaultSms: Boolean = true,
  ): SmsAccess = SmsAccess(mockSmsContext(resolver, defaultSms = defaultSms))

  /** 按 date DESC, _id DESC 排好的短信行（Provider 顺序）。 */
  private fun smsRows(vararg rows: List<Any?>): List<List<Any?>> =
    rows.sortedWith(
      compareByDescending<List<Any?>> { (it[4] as? Number)?.toLong() ?: Long.MIN_VALUE }
        .thenByDescending { (it[0] as? Number)?.toLong() ?: Long.MIN_VALUE },
    )

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
    val stub = SmsProviderStub().apply {
      sms = listOf(listOf(null, 1L, "a", "row-no-id", 100L, 100L, 1, 1, 1))
    }
    stub.install(resolver)
    val access = accessWith(resolver)
    val r = access.querySms(null)
    assertEquals(0, r[ChannelCodes.KEY_TOTAL])
    assertTrue((r[ChannelCodes.KEY_MESSAGES] as List<*>).isEmpty())
    assertNull(r[ChannelCodes.KEY_ERROR])
  }

  // ---- querySms：单 URI 优先（去重复扫描） ----

  @Test
  fun `querySms does not query box uris when content uri has rows`() {
    val resolver = mock<ContentResolver>()
    val stub = SmsProviderStub().apply {
      sms = smsRows(smsRow(id = 1, date = 100L), smsRow(id = 2, date = 200L))
    }
    stub.install(resolver)
    val access = accessWith(resolver)
    val r = access.querySms(null)
    assertEquals(2, r[ChannelCodes.KEY_TOTAL])
    // 只查整表：SMS rows ×1 + MMS rows ×1（空表整表空也不回落——见回落用例）
    // MMS 整表空会回落子箱；这里用非空 SMS + 空 MMS，MMS 回落 3 箱 ×(count+rows)。
    // 断言 SMS 侧只有一次 rows（未扫 inbox/sent/draft）。
    val smsRowQueries = stub.queryLog.filter { it.kind == "sms" && !it.isCount }
    assertEquals(1, smsRowQueries.size)
    val smsCountQueries = stub.queryLog.filter { it.kind == "sms" && it.isCount }
    // 全量路径无 count
    assertTrue(smsCountQueries.isEmpty())
  }

  @Test
  fun `querySms paged queries content uri once per stream with LIMIT pushdown`() {
    val resolver = mock<ContentResolver>()
    val stub = SmsProviderStub().apply {
      sms = smsRows(
        smsRow(id = 1, date = 500L),
        smsRow(id = 2, date = 400L),
        smsRow(id = 3, date = 300L),
        smsRow(id = 4, date = 200L),
        smsRow(id = 5, date = 100L),
      )
    }
    stub.install(resolver)
    val access = accessWith(resolver)
    val r = access.querySms(null, limit = 2, offset = 0)
    @Suppress("UNCHECKED_CAST")
    val page = r[ChannelCodes.KEY_MESSAGES] as List<Map<String, Any?>>
    assertEquals(5, r[ChannelCodes.KEY_TOTAL])
    assertEquals(listOf(1, 2), page.map { it["_id"] })
    // 每流 1 次 count + 1 次 rows；rows 的 sortOrder 带 LIMIT 2
    val rowQ = stub.queryLog.filter { it.kind == "sms" && !it.isCount }
    assertEquals(1, rowQ.size)
    assertTrue(rowQ[0].sort!!.contains("LIMIT 2"))
    assertTrue(rowQ[0].sort!!.contains("date DESC"))
  }

  @Test
  fun `querySms falls back to box uris when content uri empty`() {
    val resolver = mock<ContentResolver>()
    stubEmptyPrimaryThenBoxes(
      resolver,
      smsInbox = smsRows(smsRow(id = 2, body = "from-inbox", date = 200L)),
      smsSent = smsRows(smsRow(id = 1, body = "from-sent", date = 100L)),
      smsDraft = smsRows(smsRow(id = 3, body = "from-draft", date = 50L)),
    )
    val access = accessWith(resolver)
    val r = access.querySms(null)
    @Suppress("UNCHECKED_CAST")
    val messages = r[ChannelCodes.KEY_MESSAGES] as List<Map<String, Any?>>
    assertEquals(3, r[ChannelCodes.KEY_TOTAL])
    assertEquals(listOf(2, 1, 3), messages.map { it["_id"] })
    assertEquals("from-inbox", messages[0]["body"])
    assertEquals("from-sent", messages[1]["body"])
    assertEquals("from-draft", messages[2]["body"])
  }

  @Test
  fun `querySms fallback dedups same _id across box uris`() {
    val resolver = mock<ContentResolver>()
    // 同一 _id=2 同时出现在 inbox 与 sent（异常数据 / OEM 重复），只保留先到者。
    stubEmptyPrimaryThenBoxes(
      resolver,
      smsInbox = smsRows(smsRow(id = 2, body = "from-inbox", date = 200L)),
      smsSent = smsRows(smsRow(id = 2, body = "from-sent-dup", date = 200L)),
    )
    val access = accessWith(resolver)
    val r = access.querySms(null)
    @Suppress("UNCHECKED_CAST")
    val messages = r[ChannelCodes.KEY_MESSAGES] as List<Map<String, Any?>>
    assertEquals(1, messages.size)
    // 归并后先到者保留（inbox 序在 sent 前，且同 date 按 _id 相同）
    assertTrue(messages[0]["body"] == "from-inbox" || messages[0]["body"] == "from-sent-dup")
  }

  // ---- querySms：排序 ----

  @Test
  fun `querySms sorts by date desc then _id desc`() {
    val resolver = mock<ContentResolver>()
    val stub = SmsProviderStub().apply {
      // Provider 按 sortOrder 返回有序数据
      sms = smsRows(
        smsRow(id = 3, date = 300L),
        smsRow(id = 2, date = 200L),
        smsRow(id = 1, date = 100L),
      )
    }
    stub.install(resolver)
    val access = accessWith(resolver)
    @Suppress("UNCHECKED_CAST")
    val messages = access.querySms(null)[ChannelCodes.KEY_MESSAGES] as List<Map<String, Any?>>
    assertEquals(listOf(3, 2, 1), messages.map { it["_id"] })
  }

  @Test
  fun `querySms tie-breaks equal date by _id desc`() {
    val resolver = mock<ContentResolver>()
    val stub = SmsProviderStub().apply {
      sms = smsRows(
        smsRow(id = 9, date = 100L),
        smsRow(id = 5, date = 100L),
        smsRow(id = 1, date = 100L),
      )
    }
    stub.install(resolver)
    val access = accessWith(resolver)
    @Suppress("UNCHECKED_CAST")
    val messages = access.querySms(null)[ChannelCodes.KEY_MESSAGES] as List<Map<String, Any?>>
    assertEquals(listOf(9, 5, 1), messages.map { it["_id"] })
  }

  @Test
  fun `querySms treats null date as oldest`() {
    val resolver = mock<ContentResolver>()
    val stub = SmsProviderStub().apply {
      // Provider 按 sortOrder 返回：date 非空在前，null date 最后（同 null 按 _id 降序）
      sms = smsRows(
        smsRow(id = 2, date = 50L),
        smsRow(id = 3, date = null),
        smsRow(id = 1, date = null),
      )
    }
    stub.install(resolver)
    val access = accessWith(resolver)
    @Suppress("UNCHECKED_CAST")
    val messages = access.querySms(null)[ChannelCodes.KEY_MESSAGES] as List<Map<String, Any?>>
    assertEquals(listOf(2, 3, 1), messages.map { it["_id"] })
  }

  // ---- querySms：真分页 ----

  @Test
  fun `querySms pages by limit and offset after provider sort`() {
    val resolver = mock<ContentResolver>()
    val stub = SmsProviderStub().apply {
      // Provider 顺序：date 5..1 → id 1..5
      sms = smsRows(
        smsRow(id = 1, date = 5L),
        smsRow(id = 2, date = 4L),
        smsRow(id = 3, date = 3L),
        smsRow(id = 4, date = 2L),
        smsRow(id = 5, date = 1L),
      )
    }
    stub.install(resolver)
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
    val stub = SmsProviderStub().apply {
      sms = smsRows(smsRow(id = 1), smsRow(id = 2))
    }
    stub.install(resolver)
    val access = accessWith(resolver)
    val r = access.querySms(null, limit = 0, offset = 0)
    @Suppress("UNCHECKED_CAST")
    val messages = r[ChannelCodes.KEY_MESSAGES] as List<Map<String, Any?>>
    assertEquals(2, r[ChannelCodes.KEY_TOTAL])
    assertTrue(messages.isEmpty())
    // 不应发生 rows 扫描（只 count）
    assertTrue(stub.queryLog.none { it.kind == "sms" && !it.isCount })
  }

  @Test
  fun `querySms negative offset is coerced to zero`() {
    val resolver = mock<ContentResolver>()
    val stub = SmsProviderStub().apply {
      sms = smsRows(smsRow(id = 1, date = 2L), smsRow(id = 2, date = 1L))
    }
    stub.install(resolver)
    val access = accessWith(resolver)
    val r = access.querySms(null, limit = 10, offset = -5)
    @Suppress("UNCHECKED_CAST")
    val messages = r[ChannelCodes.KEY_MESSAGES] as List<Map<String, Any?>>
    assertEquals(listOf(1, 2), messages.map { it["_id"] })
  }

  @Test
  fun `querySms offset beyond total returns empty page with total`() {
    val resolver = mock<ContentResolver>()
    val stub = SmsProviderStub().apply {
      sms = smsRows(smsRow(id = 1, date = 2L))
    }
    stub.install(resolver)
    val access = accessWith(resolver)
    val r = access.querySms(null, limit = 10, offset = 99)
    @Suppress("UNCHECKED_CAST")
    val messages = r[ChannelCodes.KEY_MESSAGES] as List<Map<String, Any?>>
    assertEquals(1, r[ChannelCodes.KEY_TOTAL])
    assertTrue(messages.isEmpty())
  }

  @Test
  fun `querySms short-circuits row reads to offset+limit`() {
    val resolver = mock<ContentResolver>()
    // 5000 行假数据：只应消费 offset+limit 条
    val big = (1..5000).map { i -> smsRow(id = i, date = (6000 - i).toLong()) }
    val cursors = mutableListOf<FakeCursor>()
    var lastSmsSort: String? = null
    whenever(resolver.query(anyOrNull(), anyOrNull(), anyOrNull(), anyOrNull(), anyOrNull()))
      .thenAnswer { inv ->
        val proj = inv.getArgument<Array<String>?>(1)?.toList()
        val sort = inv.getArgument<String?>(4)
        if (proj != null && proj.contains("body")) {
          if (sort != null) lastSmsSort = sort
          val c = FakeCursor(SMS_CURSOR_COLUMNS, big)
          cursors += c
          c
        } else {
          FakeCursor(MMS_CURSOR_COLUMNS, emptyList())
        }
      }
    val access = accessWith(resolver)
    val r = access.querySms(null, limit = 20, offset = 30)
    @Suppress("UNCHECKED_CAST")
    val page = r[ChannelCodes.KEY_MESSAGES] as List<Map<String, Any?>>
    assertEquals(5000, r[ChannelCodes.KEY_TOTAL])
    assertEquals(20, page.size)
    assertEquals(31, page.first()["_id"])
    // 只物化 offset+limit=50 条；绝不能 5000 全读
    val consumed = cursors.sumOf { it.rowsConsumed }
    assertTrue("rowsConsumed=$consumed should be <= 50", consumed <= 50)
    // LIMIT 下推到 sortOrder
    assertTrue(lastSmsSort!!.contains("LIMIT 50"))
    assertTrue(lastSmsSort.contains("date DESC"))
  }

  // ---- querySms：address 过滤与错误 ----

  @Test
  fun `querySms passes address filter through to provider`() {
    val resolver = mock<ContentResolver>()
    val stub = SmsProviderStub().apply {
      sms = smsRows(smsRow(id = 1, address = "10086"))
    }
    stub.install(resolver)
    val access = accessWith(resolver)
    access.querySms("10086")
    // SMS 行/ count 查询必须带上 address=? 过滤
    assertTrue(
      stub.queryLog.any {
        it.kind == "sms" && it.selection == "address=?" 
      },
    )
  }

  @Test
  fun `querySms empty address queries unfiltered`() {
    val resolver = mock<ContentResolver>()
    val stub = SmsProviderStub()
    stub.install(resolver)
    val access = accessWith(resolver)
    access.querySms("")
    assertTrue(stub.queryLog.all { it.selection == null })
  }

  @Test
  fun `querySms security exception with no rows reports permission error`() {
    val resolver = mock<ContentResolver>()
    whenever(resolver.query(anyOrNull(), anyOrNull(), anyOrNull(), anyOrNull(), anyOrNull()))
      .thenThrow(SecurityException("no sms"))
    val access = SmsAccess(mockSmsContext(resolver, defaultSms = false))
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
    val stub = SmsProviderStub().apply {
      sms = smsRows(smsRow(id = 1))
    }
    stub.install(resolver)
    val access = accessWith(resolver)
    val r = access.querySms(null)
    // 有数据则 error 必须为 null
    assertNull(r[ChannelCodes.KEY_ERROR])
    assertEquals(1, r[ChannelCodes.KEY_TOTAL])
  }

  @Test
  fun `querySms empty store reports empty success`() {
    val resolver = mock<ContentResolver>()
    val stub = SmsProviderStub()
    stub.install(resolver)
    val access = accessWith(resolver)
    val r = access.querySms(null)
    assertNull(r[ChannelCodes.KEY_ERROR])
    assertEquals(0, r[ChannelCodes.KEY_TOTAL])
    assertTrue((r[ChannelCodes.KEY_MESSAGES] as List<*>).isEmpty())
  }

  @Test
  fun `querySms payload always has messages total error partial warnings keys`() {
    val resolver = mock<ContentResolver>()
    val stub = SmsProviderStub()
    stub.install(resolver)
    val access = accessWith(resolver)
    val r = access.querySms(null)
    assertEquals(
      setOf(
        ChannelCodes.KEY_MESSAGES,
        ChannelCodes.KEY_TOTAL,
        ChannelCodes.KEY_ERROR,
        ChannelCodes.KEY_PARTIAL,
        ChannelCodes.KEY_WARNINGS,
      ),
      r.keys,
    )
    // 空库无失败：完整成功
    assertEquals(false, r[ChannelCodes.KEY_PARTIAL])
    assertTrue((r[ChannelCodes.KEY_WARNINGS] as List<*>).isEmpty())
  }

  // ---- querySms：部分失败（partial / warnings） ----

  @Test
  @Suppress("UNCHECKED_CAST")
  fun `querySms partial with warnings when mms stream throws but sms rows exist`() {
    val resolver = mock<ContentResolver>()
    val stub = SmsProviderStub().apply {
      sms = smsRows(smsRow(id = 1, date = 100L))
    }
    stub.install(resolver)
    // 只让彩信主表查询抛 SecurityException，短信侧正常返回行。
    stub.onQuery = { inv ->
      val proj = inv.getArgument<Array<String>?>(1)?.toList()
      if (proj != null && proj.contains("msg_box")) {
        throw SecurityException("mms restricted")
      }
      null
    }
    val access = accessWith(resolver)
    val r = access.querySms(null)
    // 有数据 → error 必须为 null，但 partial=true 且带 warnings
    assertNull(r[ChannelCodes.KEY_ERROR])
    assertEquals(true, r[ChannelCodes.KEY_PARTIAL])
    val warnings = r[ChannelCodes.KEY_WARNINGS] as List<Map<String, Any?>>
    assertTrue(warnings.isNotEmpty())
    assertTrue(warnings.any { it[ChannelCodes.KEY_CODE] == ChannelCodes.WARN_MMS_URI_SECURITY })
    // 不因单路失败丢弃另一路已有行
    assertEquals(1, r[ChannelCodes.KEY_TOTAL])
    assertEquals(1, (r[ChannelCodes.KEY_MESSAGES] as List<*>).size)
  }

  @Test
  @Suppress("UNCHECKED_CAST")
  fun `querySms partial with warnings when sms stream throws but mms rows exist`() {
    val resolver = mock<ContentResolver>()
    val stub = SmsProviderStub().apply {
      mms = listOf(mmsRow(id = 9, dateSec = 1_700_000_000L))
    }
    stub.install(resolver)
    stub.onQuery = { inv ->
      val proj = inv.getArgument<Array<String>?>(1)?.toList()
      if (proj != null && proj.contains("body")) {
        throw SecurityException("sms restricted")
      }
      null
    }
    val access = accessWith(resolver)
    val r = access.querySms(null)
    assertNull(r[ChannelCodes.KEY_ERROR])
    assertEquals(true, r[ChannelCodes.KEY_PARTIAL])
    val warnings = r[ChannelCodes.KEY_WARNINGS] as List<Map<String, Any?>>
    assertTrue(warnings.any { it[ChannelCodes.KEY_CODE] == ChannelCodes.WARN_SMS_URI_SECURITY })
    assertEquals(1, (r[ChannelCodes.KEY_MESSAGES] as List<*>).size)
  }

  @Test
  fun `querySms all success is not partial and has empty warnings`() {
    val resolver = mock<ContentResolver>()
    val stub = SmsProviderStub().apply {
      sms = smsRows(smsRow(id = 1, date = 100L))
      mms = listOf(mmsRow(id = 2, dateSec = 1_700_000_000L))
      mmsAddr = listOf(listOf(2L, "10086", 137))
      mmsPart = listOf(listOf(2L, "text/plain", "彩信正文", null))
    }
    stub.install(resolver)
    val access = accessWith(resolver)
    val r = access.querySms(null)
    assertNull(r[ChannelCodes.KEY_ERROR])
    assertEquals(false, r[ChannelCodes.KEY_PARTIAL])
    assertTrue((r[ChannelCodes.KEY_WARNINGS] as List<*>).isEmpty())
    assertEquals(2, r[ChannelCodes.KEY_TOTAL])
  }

  @Test
  @Suppress("UNCHECKED_CAST")
  fun `querySms all fail with no rows reports error and partial false`() {
    val resolver = mock<ContentResolver>()
    whenever(resolver.query(anyOrNull(), anyOrNull(), anyOrNull(), anyOrNull(), anyOrNull()))
      .thenThrow(SecurityException("no sms"))
    val access = SmsAccess(mockSmsContext(resolver, defaultSms = false))
    val r = access.querySms(null)
    assertEquals(ChannelCodes.QUERY_ERROR_PERMISSION, r[ChannelCodes.KEY_ERROR])
    // error 与 partial 互斥
    assertEquals(false, r[ChannelCodes.KEY_PARTIAL])
    val warnings = r[ChannelCodes.KEY_WARNINGS] as List<Map<String, Any?>>
    assertTrue(warnings.any { it[ChannelCodes.KEY_CODE] == ChannelCodes.WARN_SMS_URI_SECURITY })
  }

  @Test
  fun `querySms all fail with generic exception reports unknown error and partial false`() {
    val resolver = mock<ContentResolver>()
    whenever(resolver.query(anyOrNull(), anyOrNull(), anyOrNull(), anyOrNull(), anyOrNull()))
      .thenThrow(RuntimeException("provider dead"))
    val access = accessWith(resolver)
    val r = access.querySms(null)
    assertEquals(ChannelCodes.QUERY_ERROR_UNKNOWN, r[ChannelCodes.KEY_ERROR])
    assertEquals(false, r[ChannelCodes.KEY_PARTIAL])
  }

  @Test
  @Suppress("UNCHECKED_CAST")
  fun `querySms mms part enrichment failure yields partial with mms_part_failed`() {
    val resolver = mock<ContentResolver>()
    val stub = SmsProviderStub().apply {
      mms = listOf(mmsRow(id = 2, dateSec = 1_700_000_000L))
    }
    stub.install(resolver)
    stub.onQuery = { inv ->
      val proj = inv.getArgument<Array<String>?>(1)?.toList()
      if (proj != null && proj.contains("mid")) {
        throw RuntimeException("part table gone")
      }
      null
    }
    val access = accessWith(resolver)
    val r = access.querySms(null)
    assertNull(r[ChannelCodes.KEY_ERROR])
    assertEquals(true, r[ChannelCodes.KEY_PARTIAL])
    val warnings = r[ChannelCodes.KEY_WARNINGS] as List<Map<String, Any?>>
    assertTrue(warnings.any { it[ChannelCodes.KEY_CODE] == ChannelCodes.WARN_MMS_PART_FAILED })
    // 行仍在（不因富化失败丢行）
    assertEquals(1, (r[ChannelCodes.KEY_MESSAGES] as List<*>).size)
  }

  @Test
  @Suppress("UNCHECKED_CAST")
  fun `querySms warnings never contain exception message or uri`() {
    val resolver = mock<ContentResolver>()
    val stub = SmsProviderStub().apply {
      sms = smsRows(smsRow(id = 1, date = 100L))
    }
    stub.install(resolver)
    stub.onQuery = { inv ->
      val proj = inv.getArgument<Array<String>?>(1)?.toList()
      if (proj != null && proj.contains("msg_box")) {
        throw SecurityException("content://mms/secret/path leaked")
      }
      null
    }
    val access = accessWith(resolver)
    val r = access.querySms(null)
    val warnings = r[ChannelCodes.KEY_WARNINGS] as List<Map<String, Any?>>
    for (w in warnings) {
      val msg = w[ChannelCodes.KEY_MESSAGE]?.toString().orEmpty()
      assertFalse("message leaks path: $msg", msg.contains("content://"))
      assertFalse("message leaks path: $msg", msg.contains("secret"))
      assertFalse("message leaks path: $msg", msg.contains("/"))
    }
  }

  // ---- querySms：服务端过滤下推（type / 日期范围 / 大 id 集合计数）----

  @Test
  fun `querySms type inbox pushes exact inbox selection`() {
    val resolver = mock<ContentResolver>()
    val stub = SmsProviderStub().apply {
      sms = smsRows(smsRow(id = 1, type = 1))
    }
    stub.install(resolver)
    val access = accessWith(resolver)
    access.querySms(null, type = 1)
    assertTrue(
      stub.queryLog.any {
        it.kind == "sms" && it.selection == "type=?" && it.args == listOf("1")
      },
    )
  }

  @Test
  fun `querySms type sent pushes non-inbox selection so drafts stay included`() {
    val resolver = mock<ContentResolver>()
    val stub = SmsProviderStub().apply {
      sms = smsRows(smsRow(id = 1, type = 3))
    }
    stub.install(resolver)
    val access = accessWith(resolver)
    access.querySms(null, type = 2)
    // 「仅已发送」契约：草稿归入发送侧（filter_sheet.dart / SmsItem.kind），
    // 下推必须是 type<>1（含 DRAFT/OUTBOX/FAILED/QUEUED），不能是 type=2。
    assertTrue(
      stub.queryLog.any {
        it.kind == "sms" && it.selection == "type<>?" && it.args == listOf("1")
      },
    )
    assertTrue(
      stub.queryLog.none { it.kind == "sms" && it.selection == "type=?" },
    )
  }

  @Test
  fun `querySms type sent pushes non-inbox msg_box to mms`() {
    val resolver = mock<ContentResolver>()
    val stub = SmsProviderStub().apply {
      sms = smsRows(smsRow(id = 1, type = 2))
      mms = listOf(mmsRow(id = 9, dateSec = 1_700_000_000L, msgBox = 3))
    }
    stub.install(resolver)
    val access = accessWith(resolver)
    access.querySms(null, type = 2)
    // 彩信同理：msg_box<>1（草稿 msg_box=3 归入发送侧）
    assertTrue(
      stub.queryLog.any {
        it.kind == "mms" && it.selection == "msg_box<>?" && it.args == listOf("1")
      },
    )
  }

  @Test
  fun `querySms date range pushes to mms in seconds`() {
    val resolver = mock<ContentResolver>()
    val stub = SmsProviderStub().apply {
      mms = listOf(mmsRow(id = 1, dateSec = 1_700_000_000L))
    }
    stub.install(resolver)
    val access = accessWith(resolver)
    access.querySms(
      null,
      startDateMs = 1_700_000_000_000L,
      endDateMs = 1_700_086_399_999L,
      limit = 10,
      offset = 0,
    )
    // SMS 侧：毫秒原样下推
    assertTrue(
      stub.queryLog.any {
        it.kind == "sms" &&
          it.selection == "date >= ? AND date <= ?" &&
          it.args == listOf("1700000000000", "1700086399999")
      },
    )
    // 彩信 date 列是秒：下推必须 /1000（修复前彩信完全不带日期过滤，total 虚高）
    val mmsQ = stub.queryLog.filter { it.kind == "mms" && it.selection != null }
    assertTrue(mmsQ.isNotEmpty())
    assertTrue(
      mmsQ.all {
        it.selection == "date >= ? AND date <= ?" &&
          it.args == listOf("1700000000", "1700086399")
      },
    )
  }

  @Test
  @Suppress("UNCHECKED_CAST")
  fun `querySms large mms id filter counts only matching rows`() {
    val resolver = mock<ContentResolver>()
    val stub = SmsProviderStub().apply {
      // 全表 1200 条彩信（Provider 序：date DESC），仅 1000 条命中 address 过滤
      // （1000 > MMS_ID_IN_MAX=900 → 走 keepRow 内存过滤，selection 不含 id 条件）
      mms = (1200 downTo 1).map { mmsRow(id = it, dateSec = it.toLong()) }
      mmsAddrIds = (1..1000).map { listOf(it, "10086", 137) }
      mmsAddr = (991..1000).map { listOf(it, "10086", 137) }
      mmsPart = (991..1000).map { listOf(it, "text/plain", "命中", null) }
    }
    stub.install(resolver)
    val access = accessWith(resolver)
    val r = access.querySms("10086", limit = 10, offset = 0)
    // total 只统计命中行（修复前：selection=null 的聚合 count 把全表 1200 算进去）
    assertEquals(1000, r[ChannelCodes.KEY_TOTAL])
    val messages = r[ChannelCodes.KEY_MESSAGES] as List<Map<String, Any?>>
    assertEquals(10, messages.size)
    // 命中最新的 10 条（id 1000..991）；未命中行（id>1000）不进入结果
    assertEquals(1000, messages.first()["_id"])
    assertEquals(991, messages.last()["_id"])
    assertTrue(messages.all { (it["_id"] as Int) <= 1000 })
  }
}
