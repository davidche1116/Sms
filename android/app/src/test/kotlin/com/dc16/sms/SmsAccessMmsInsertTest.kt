package com.dc16.sms

import android.content.ContentResolver
import android.net.Uri
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import org.mockito.kotlin.anyOrNull
import org.mockito.kotlin.mock
import org.mockito.kotlin.times
import org.mockito.kotlin.verify
import org.mockito.kotlin.whenever

/**
 * [SmsAccess.insertMmsNotification]：骨架行 + addr + 主题 text part 的调用形状。
 * JVM 上 ContentValues 是空桩，按 insert 调用次序/次数断言，不读列值。
 */
class SmsAccessMmsInsertTest {

  private fun notification(
    from: String? = "10086",
    subject: String? = null,
    messageId: String? = "MSG-1",
    contentLocation: String? = "http://mmsc/x",
    dateSec: Long? = 1_700_000_000L,
  ) = MmsPduParser.MmsNotification(
    messageType = MmsPduParser.MESSAGE_TYPE_NOTIFICATION_IND,
    from = from,
    subject = subject,
    messageId = messageId,
    contentLocation = contentLocation,
    dateSec = dateSec,
  )

  private fun uri(id: Int): Uri =
    mock<Uri>().also { whenever(it.lastPathSegment).thenReturn(id.toString()) }

  @Test
  fun `inserts main row then addr when subject absent`() {
    val resolver = mock<ContentResolver>()
    var call = 0
    whenever(resolver.insert(anyOrNull(), anyOrNull())).thenAnswer {
      uri(++call) // 1=main, 2=addr
    }
    val access = SmsAccess(mockSmsContext(resolver, defaultSms = true))
    assertEquals(1, access.insertMmsNotification(notification(), subId = 1))
    // 主行 + addr；无主题不写 part
    verify(resolver, times(2)).insert(anyOrNull(), anyOrNull())
  }

  @Test
  fun `inserts subject as text part after addr`() {
    val resolver = mock<ContentResolver>()
    var call = 0
    whenever(resolver.insert(anyOrNull(), anyOrNull())).thenAnswer {
      uri(++call) // 1=main, 2=addr, 3=part
    }
    val access = SmsAccess(mockSmsContext(resolver, defaultSms = true))
    assertEquals(1, access.insertMmsNotification(notification(subject = "你好"), subId = null))
    verify(resolver, times(3)).insert(anyOrNull(), anyOrNull())
  }

  @Test
  fun `returns null when main insert returns null`() {
    val resolver = mock<ContentResolver>()
    whenever(resolver.insert(anyOrNull(), anyOrNull())).thenReturn(null)
    val access = SmsAccess(mockSmsContext(resolver, defaultSms = true))
    assertNull(access.insertMmsNotification(notification(), subId = 1))
    verify(resolver, times(1)).insert(anyOrNull(), anyOrNull())
  }

  @Test
  fun `returns null when provider throws`() {
    val resolver = mock<ContentResolver>()
    whenever(resolver.insert(anyOrNull(), anyOrNull())).thenThrow(RuntimeException("io"))
    val access = SmsAccess(mockSmsContext(resolver, defaultSms = true))
    assertNull(access.insertMmsNotification(notification(), subId = 1))
  }

  @Test
  fun `addr insert failure does not fail main insert`() {
    val resolver = mock<ContentResolver>()
    var call = 0
    whenever(resolver.insert(anyOrNull(), anyOrNull())).thenAnswer {
      call++
      if (call == 1) uri(5) else throw RuntimeException("addr failed")
    }
    val access = SmsAccess(mockSmsContext(resolver, defaultSms = true))
    assertEquals(5, access.insertMmsNotification(notification(subject = "s"), subId = 1))
  }

  @Test
  fun `without from still inserts main row only`() {
    val resolver = mock<ContentResolver>()
    whenever(resolver.insert(anyOrNull(), anyOrNull())).thenAnswer { uri(9) }
    val access = SmsAccess(mockSmsContext(resolver, defaultSms = true))
    assertEquals(9, access.insertMmsNotification(notification(from = null), subId = 1))
    verify(resolver, times(1)).insert(anyOrNull(), anyOrNull())
  }

  @Test
  fun `negative sub id still inserts`() {
    val resolver = mock<ContentResolver>()
    whenever(resolver.insert(anyOrNull(), anyOrNull())).thenAnswer { uri(1) }
    val access = SmsAccess(mockSmsContext(resolver, defaultSms = true))
    assertEquals(1, access.insertMmsNotification(notification(from = null), subId = -1))
    verify(resolver, times(1)).insert(anyOrNull(), anyOrNull())
  }
}
