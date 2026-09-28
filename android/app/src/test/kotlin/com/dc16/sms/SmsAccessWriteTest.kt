package com.dc16.sms

import android.content.ContentResolver
import android.net.Uri
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.mockito.kotlin.anyOrNull
import org.mockito.kotlin.mock
import org.mockito.kotlin.never
import org.mockito.kotlin.times
import org.mockito.kotlin.verify
import org.mockito.kotlin.whenever

/**
 * [SmsAccess.deleteSmsBatch] chunk 边界 / 空列表，
 * 以及 [SmsAccess.insertTestSms] / [SmsAccess.insertSmsBatch] 的门禁与返回形状。
 */
class SmsAccessWriteTest {

  // ---- deleteSmsBatch ----

  @Test
  fun `deleteSmsBatch empty list returns ok zero without touching provider`() {
    val resolver = mock<ContentResolver>()
    val access = SmsAccess(mockSmsContext(resolver, defaultSms = true))
    val r = access.deleteSmsBatch(emptyList())
    assertEquals(true, r[ChannelCodes.KEY_OK])
    assertEquals(0, r[ChannelCodes.KEY_DELETED])
    assertEquals(0, r[ChannelCodes.KEY_FAILED])
    assertEquals(null, r[ChannelCodes.KEY_ERROR])
    assertTrue((r[ChannelCodes.KEY_ERRORS] as List<*>).isEmpty())
    verify(resolver, never()).delete(anyOrNull(), anyOrNull(), anyOrNull())
  }

  @Test
  fun `deleteSmsBatch empty list returns ok zero even when not default`() {
    val resolver = mock<ContentResolver>()
    val access = SmsAccess(mockSmsContext(resolver, defaultSms = false))
    val r = access.deleteSmsBatch(emptyList())
    assertEquals(true, r[ChannelCodes.KEY_OK])
    assertEquals(0, r[ChannelCodes.KEY_DELETED])
  }

  @Test
  fun `deleteSmsBatch returns not_default error when not default sms app`() {
    val resolver = mock<ContentResolver>()
    val access = SmsAccess(mockSmsContext(resolver, defaultSms = false))
    val r = access.deleteSmsBatch(listOf(1, 2, 3))
    assertEquals(false, r[ChannelCodes.KEY_OK])
    assertEquals(0, r[ChannelCodes.KEY_DELETED])
    assertEquals(3, r[ChannelCodes.KEY_FAILED])
    assertEquals(ChannelCodes.DELETE_ERROR_NOT_DEFAULT, r[ChannelCodes.KEY_ERROR])
    @Suppress("UNCHECKED_CAST")
    val errors = r[ChannelCodes.KEY_ERRORS] as List<Map<String, Any?>>
    assertEquals(1, errors.size)
    assertEquals(-1, errors[0][ChannelCodes.KEY_INDEX])
    assertEquals(ChannelCodes.DELETE_ERROR_NOT_DEFAULT, errors[0][ChannelCodes.KEY_CODE])
    verify(resolver, never()).delete(anyOrNull(), anyOrNull(), anyOrNull())
  }

  @Test
  fun `deleteSmsBatch sends single chunk for 900 ids`() {
    val resolver = mock<ContentResolver>()
    val chunks = stubDeleteCounting(resolver)
    val access = SmsAccess(mockSmsContext(resolver, defaultSms = true))
    val ids = (1..900).toList()
    val r = access.deleteSmsBatch(ids)
    assertEquals(true, r[ChannelCodes.KEY_OK])
    assertEquals(900, r[ChannelCodes.KEY_DELETED])
    assertEquals(0, r[ChannelCodes.KEY_FAILED])
    assertEquals(listOf(900), chunks.map { it.size })
    assertEquals(ids.map { it.toString() }, chunks[0])
  }

  @Test
  fun `deleteSmsBatch splits 901 ids into 900 plus 1`() {
    val resolver = mock<ContentResolver>()
    val chunks = stubDeleteCounting(resolver)
    val access = SmsAccess(mockSmsContext(resolver, defaultSms = true))
    val r = access.deleteSmsBatch((1..901).toList())
    assertEquals(901, r[ChannelCodes.KEY_DELETED])
    assertEquals(listOf(900, 1), chunks.map { it.size })
  }

  @Test
  fun `deleteSmsBatch splits 1800 ids into two full chunks`() {
    val resolver = mock<ContentResolver>()
    val chunks = stubDeleteCounting(resolver)
    val access = SmsAccess(mockSmsContext(resolver, defaultSms = true))
    val r = access.deleteSmsBatch((1..1800).toList())
    assertEquals(1800, r[ChannelCodes.KEY_DELETED])
    assertEquals(listOf(900, 900), chunks.map { it.size })
    verify(resolver, times(2)).delete(anyOrNull(), anyOrNull(), anyOrNull())
  }

  @Test
  fun `deleteSmsBatch sums deleted counts across chunks`() {
    val resolver = mock<ContentResolver>()
    // 每 chunk 只删掉一半（向下取整）
    whenever(resolver.delete(anyOrNull(), anyOrNull(), anyOrNull())).thenAnswer { inv ->
      inv.getArgument<Array<String>?>(2)?.size?.div(2) ?: 0
    }
    val access = SmsAccess(mockSmsContext(resolver, defaultSms = true))
    // 901 → chunk 900/1 → 450 + 0 = 450
    val r = access.deleteSmsBatch((1..901).toList())
    assertEquals(true, r[ChannelCodes.KEY_OK])
    assertEquals(450, r[ChannelCodes.KEY_DELETED])
    assertEquals(0, r[ChannelCodes.KEY_FAILED])
  }

  @Test
  fun `deleteSmsBatch provider exception returns failed error with per-item indices`() {
    val resolver = mock<ContentResolver>()
    whenever(resolver.delete(anyOrNull(), anyOrNull(), anyOrNull()))
      .thenThrow(RuntimeException("boom"))
    val access = SmsAccess(mockSmsContext(resolver, defaultSms = true))
    val r = access.deleteSmsBatch(listOf(1, 2))
    assertEquals(false, r[ChannelCodes.KEY_OK])
    assertEquals(0, r[ChannelCodes.KEY_DELETED])
    assertEquals(2, r[ChannelCodes.KEY_FAILED])
    assertEquals(ChannelCodes.DELETE_ERROR_FAILED, r[ChannelCodes.KEY_ERROR])
    @Suppress("UNCHECKED_CAST")
    val errors = r[ChannelCodes.KEY_ERRORS] as List<Map<String, Any?>>
    assertEquals(2, errors.size)
    assertEquals(listOf(0, 1), errors.map { it[ChannelCodes.KEY_INDEX] })
    assertTrue(errors.all { it[ChannelCodes.KEY_CODE] == ChannelCodes.DELETE_ERROR_FAILED })
  }

  @Test
  fun `deleteSmsBatch partial chunk failure keeps successes and marks failed indices`() {
    val resolver = mock<ContentResolver>()
    var call = 0
    whenever(resolver.delete(anyOrNull(), anyOrNull(), anyOrNull())).thenAnswer { inv ->
      call++
      if (call == 2) throw RuntimeException("chunk failed")
      inv.getArgument<Array<String>?>(2)?.size ?: 0
    }
    val access = SmsAccess(mockSmsContext(resolver, defaultSms = true))
    // 901 个 SMS → chunk 900 成功 + chunk 1 失败
    val r = access.deleteSmsBatch((1..901).toList())
    assertEquals(true, r[ChannelCodes.KEY_OK])
    assertEquals(900, r[ChannelCodes.KEY_DELETED])
    assertEquals(1, r[ChannelCodes.KEY_FAILED])
    assertEquals(null, r[ChannelCodes.KEY_ERROR])
    @Suppress("UNCHECKED_CAST")
    val errors = r[ChannelCodes.KEY_ERRORS] as List<Map<String, Any?>>
    assertEquals(1, errors.size)
    assertEquals(900, errors[0][ChannelCodes.KEY_INDEX])
    assertEquals(ChannelCodes.DELETE_ERROR_FAILED, errors[0][ChannelCodes.KEY_CODE])
  }

  @Test
  fun `deleteSmsBatch mixed side failure only marks that side`() {
    val resolver = mock<ContentResolver>()
    whenever(resolver.delete(anyOrNull(), anyOrNull(), anyOrNull())).thenAnswer { inv ->
      val args = inv.getArgument<Array<String>?>(2)?.toList().orEmpty()
      // MMS 侧（第 2 次 delete 调用）抛异常
      if (args.contains("20")) throw RuntimeException("mms boom")
      args.size
    }
    val access = SmsAccess(mockSmsContext(resolver, defaultSms = true))
    // targets 下标：0=sms1, 1=mms20, 2=sms2
    val r = access.deleteSmsBatch(
      listOf(
        mapOf("id" to 1, "is_mms" to 0),
        mapOf("id" to 20, "is_mms" to 1),
        mapOf("id" to 2, "is_mms" to 0),
      ),
    )
    assertEquals(true, r[ChannelCodes.KEY_OK])
    assertEquals(2, r[ChannelCodes.KEY_DELETED])
    assertEquals(1, r[ChannelCodes.KEY_FAILED])
    @Suppress("UNCHECKED_CAST")
    val errors = r[ChannelCodes.KEY_ERRORS] as List<Map<String, Any?>>
    assertEquals(1, errors.size)
    assertEquals(1, errors[0][ChannelCodes.KEY_INDEX])
    assertEquals(ChannelCodes.DELETE_ERROR_FAILED, errors[0][ChannelCodes.KEY_CODE])
  }

  // ---- insertTestSms debuggable 门禁 ----

  @Test
  fun `insertTestSms returns null when not debuggable even if default`() {
    val resolver = mock<ContentResolver>()
    val access = SmsAccess(mockSmsContext(resolver, defaultSms = true, debuggable = false))
    assertNull(access.insertTestSms(3, "PREFIX"))
    verify(resolver, never()).insert(anyOrNull(), anyOrNull())
  }

  @Test
  fun `insertTestSms returns null when not default even if debuggable`() {
    val resolver = mock<ContentResolver>()
    val access = SmsAccess(mockSmsContext(resolver, defaultSms = false, debuggable = true))
    assertNull(access.insertTestSms(3, "PREFIX"))
    verify(resolver, never()).insert(anyOrNull(), anyOrNull())
  }

  @Test
  fun `insertTestSms returns null when neither default nor debuggable`() {
    val resolver = mock<ContentResolver>()
    val access = SmsAccess(mockSmsContext(resolver, defaultSms = false, debuggable = false))
    assertNull(access.insertTestSms(1, "P"))
    verify(resolver, never()).insert(anyOrNull(), anyOrNull())
  }

  @Test
  fun `insertTestSms debug default inserts coerced count and collects ids`() {
    val resolver = mock<ContentResolver>()
    // 不读 ContentValues（JVM 上 android.jar 桩为空实现），用调用次序发 id。
    var next = 0
    whenever(resolver.insert(anyOrNull(), anyOrNull())).thenAnswer {
      next++
      mock<Uri>().also { uri ->
        whenever(uri.lastPathSegment).thenReturn(next.toString())
      }
    }
    val access = SmsAccess(mockSmsContext(resolver, defaultSms = true, debuggable = true))
    val ids = access.insertTestSms(3, "PREFIX")
    assertEquals(listOf(1, 2, 3), ids)
    verify(resolver, times(3)).insert(anyOrNull(), anyOrNull())
  }

  @Test
  fun `insertTestSms count is coerced into 1 to 20`() {
    val resolver = mock<ContentResolver>()
    var next = 0
    whenever(resolver.insert(anyOrNull(), anyOrNull())).thenAnswer {
      next++
      mock<Uri>().also { whenever(it.lastPathSegment).thenReturn(next.toString()) }
    }
    val access = SmsAccess(mockSmsContext(resolver, defaultSms = true, debuggable = true))

    access.insertTestSms(0, "P")
    verify(resolver, times(1)).insert(anyOrNull(), anyOrNull())

    access.insertTestSms(50, "P")
    verify(resolver, times(1 + 20)).insert(anyOrNull(), anyOrNull())
  }

  @Test
  fun `insertTestSms skips rows whose insert returns null`() {
    val resolver = mock<ContentResolver>()
    var next = 0
    whenever(resolver.insert(anyOrNull(), anyOrNull())).thenAnswer {
      next++
      if (next == 2) {
        mock<Uri>().also { whenever(it.lastPathSegment).thenReturn("2") }
      } else {
        null
      }
    }
    val access = SmsAccess(mockSmsContext(resolver, defaultSms = true, debuggable = true))
    assertEquals(listOf(2), access.insertTestSms(3, "P"))
  }

  @Test
  fun `insertTestSms returns null when provider throws`() {
    val resolver = mock<ContentResolver>()
    whenever(resolver.insert(anyOrNull(), anyOrNull())).thenThrow(RuntimeException("io"))
    val access = SmsAccess(mockSmsContext(resolver, defaultSms = true, debuggable = true))
    assertNull(access.insertTestSms(1, "P"))
  }

  // ---- insertSmsBatch 形状（导入门禁，顺带锁契约） ----

  @Test
  fun `insertSmsBatch empty rows is ok zero`() {
    val resolver = mock<ContentResolver>()
    val access = SmsAccess(mockSmsContext(resolver, defaultSms = false))
    val r = access.insertSmsBatch(emptyList())
    assertEquals(true, r[ChannelCodes.KEY_OK])
    assertEquals(0, r[ChannelCodes.KEY_INSERTED])
    assertEquals(0, r[ChannelCodes.KEY_FAILED])
    assertTrue((r[ChannelCodes.KEY_ERRORS] as List<*>).isEmpty())
  }

  @Test
  fun `insertSmsBatch not default returns batch-level not_default error`() {
    val resolver = mock<ContentResolver>()
    val access = SmsAccess(mockSmsContext(resolver, defaultSms = false))
    val rows = listOf(mapOf<String, Any?>("address" to "1", "body" to "a"))
    val r = access.insertSmsBatch(rows)
    assertEquals(false, r[ChannelCodes.KEY_OK])
    assertEquals(0, r[ChannelCodes.KEY_INSERTED])
    assertEquals(1, r[ChannelCodes.KEY_FAILED])
    @Suppress("UNCHECKED_CAST")
    val errors = r[ChannelCodes.KEY_ERRORS] as List<Map<String, Any?>>
    assertEquals(1, errors.size)
    assertEquals(-1, errors[0][ChannelCodes.KEY_INDEX])
    assertEquals(ChannelCodes.INSERT_ERROR_NOT_DEFAULT, errors[0][ChannelCodes.KEY_CODE])
  }

  @Test
  fun `insertSmsBatch reports per-row failures with original indices`() {
    val resolver = mock<ContentResolver>()
    var call = 0
    whenever(resolver.insert(anyOrNull(), anyOrNull())).thenAnswer {
      call++
      if (call == 2) throw RuntimeException("row failed")
      mock<Uri>()
    }
    val access = SmsAccess(mockSmsContext(resolver, defaultSms = true))
    val rows = listOf(
      mapOf<String, Any?>("address" to "1", "body" to "ok", "type" to 1),
      mapOf<String, Any?>("address" to "1", "body" to "bad", "type" to 1),
      mapOf<String, Any?>("address" to "1", "body" to "ok2", "type" to 3),
    )
    val r = access.insertSmsBatch(rows)
    assertEquals(true, r[ChannelCodes.KEY_OK])
    assertEquals(2, r[ChannelCodes.KEY_INSERTED])
    assertEquals(1, r[ChannelCodes.KEY_FAILED])
    @Suppress("UNCHECKED_CAST")
    val errors = r[ChannelCodes.KEY_ERRORS] as List<Map<String, Any?>>
    assertEquals(1, errors.size)
    assertEquals(1, errors[0][ChannelCodes.KEY_INDEX])
    assertEquals(ChannelCodes.INSERT_ERROR_FAILED, errors[0][ChannelCodes.KEY_CODE])
  }

  @Test
  fun `insertSmsBatch keeps original indices for non-map rows`() {
    val resolver = mock<ContentResolver>()
    whenever(resolver.insert(anyOrNull(), anyOrNull())).thenReturn(mock<Uri>())
    val access = SmsAccess(mockSmsContext(resolver, defaultSms = true))
    // 混入 String / null：不得丢行，否则 errors[].index 相对 Dart 载荷错位。
    val rows = listOf<Any?>(
      mapOf<String, Any?>("address" to "1", "body" to "ok", "type" to 1),
      "not-a-map",
      mapOf<String, Any?>("address" to "1", "body" to "ok2", "type" to 1),
      null,
    )
    val r = access.insertSmsBatch(rows)
    assertEquals(true, r[ChannelCodes.KEY_OK])
    assertEquals(2, r[ChannelCodes.KEY_INSERTED])
    assertEquals(2, r[ChannelCodes.KEY_FAILED])
    @Suppress("UNCHECKED_CAST")
    val errors = r[ChannelCodes.KEY_ERRORS] as List<Map<String, Any?>>
    assertEquals(2, errors.size)
    assertEquals(1, errors[0][ChannelCodes.KEY_INDEX])
    assertEquals(ChannelCodes.INSERT_ERROR_INVALID, errors[0][ChannelCodes.KEY_CODE])
    assertEquals(3, errors[1][ChannelCodes.KEY_INDEX])
    assertEquals(ChannelCodes.INSERT_ERROR_INVALID, errors[1][ChannelCodes.KEY_CODE])
    // 仅两行合法 Map 真正落库
    verify(resolver, times(2)).insert(anyOrNull(), anyOrNull())
  }
}
