package com.dc16.sms

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * [MmsPduParser] 对 M-Notification.ind 的 WSP/MMS 头解析。
 * 用手工编码的字节锁定 wire 格式（Short-integer / Long-integer / Text-string / From）。
 */
class MmsPduParserTest {

  // ---- 便捷编码 ----

  private fun shortInt(v: Int) = byteArrayOf((v or 0x80).toByte())

  private fun longInt(v: Long): ByteArray {
    val bytes = ArrayList<Byte>()
    var x = v
    if (x == 0L) bytes.add(0)
    else {
      while (x > 0) {
        bytes.add(0, (x and 0xFF).toByte())
        x = x ushr 8
      }
    }
    return byteArrayOf(bytes.size.toByte()) + bytes.toByteArray()
  }

  private fun text(s: String): ByteArray {
    val raw = s.toByteArray(Charsets.UTF_8)
    val needQuote = raw.isNotEmpty() && raw[0].toInt() and 0xFF >= 128
    val out = ArrayList<Byte>()
    if (needQuote) out.add(0x7F)
    raw.forEach { out.add(it) }
    out.add(0)
    return out.toByteArray()
  }

  private fun fromHeader(addr: String): ByteArray {
    val enc = text(addr)
    // From = Value-length + Address-present(0x80) + Encoded-string
    val body = byteArrayOf(0x80.toByte()) + enc
    return byteArrayOf(0x89.toByte(), body.size.toByte()) + body
  }

  private fun pdu(vararg parts: ByteArray): ByteArray {
    val out = ArrayList<Byte>()
    parts.forEach { p -> p.forEach { out.add(it) } }
    return out.toByteArray()
  }

  // ---- 解析 ----

  @Test
  fun `parses notification core fields`() {
    val bytes = pdu(
      shortInt(0x0C), shortInt(0x02), // Message-Type = Notification.ind (0x82)
      byteArrayOf(0x98.toByte()) + text("tx-1"), // Transaction-Id
      shortInt(0x0D), shortInt(0x12), // MMS-Version 1.2
      fromHeader("10086"),
      byteArrayOf(0x8B.toByte()) + text("MSG-9"), // Message-Id
      byteArrayOf(0x83.toByte()) + text("http://mmsc/x"), // Content-Location
      byteArrayOf(0x96.toByte()) + text("hello"), // Subject
      byteArrayOf(0x85.toByte()) + longInt(1_700_000_000L), // Date (sec)
    )
    val n = MmsPduParser.parseNotification(bytes)!!
    assertEquals(MmsPduParser.MESSAGE_TYPE_NOTIFICATION_IND, n.messageType)
    assertEquals("10086", n.from)
    assertEquals("MSG-9", n.messageId)
    assertEquals("http://mmsc/x", n.contentLocation)
    assertEquals("hello", n.subject)
    assertEquals(1_700_000_000L, n.dateSec)
  }

  @Test
  fun `parses utf8 subject with quote`() {
    val subject = "主题"
    val raw = subject.toByteArray(Charsets.UTF_8)
    val subjBytes = byteArrayOf(0x96.toByte(), 0x7F) + raw + byteArrayOf(0)
    val bytes = pdu(
      shortInt(0x0C), shortInt(0x02),
      fromHeader("13800138000"),
      subjBytes,
    )
    val n = MmsPduParser.parseNotification(bytes)!!
    assertEquals(subject, n.subject)
    assertEquals("13800138000", n.from)
  }

  @Test
  fun `parses from with charset-encoded string`() {
    // Encoded-string = Value-length + Char-set + Text-string
    val textPart = text("10010")
    val encoded = byteArrayOf((1 + textPart.size).toByte(), 0xEA.toByte()) + textPart
    val body = byteArrayOf(0x80.toByte()) + encoded
    val bytes = pdu(
      shortInt(0x0C), shortInt(0x02),
      byteArrayOf(0x89.toByte(), body.size.toByte()) + body,
    )
    val n = MmsPduParser.parseNotification(bytes)!!
    assertEquals("10010", n.from)
  }

  @Test
  fun `insert-address-token is not a real from`() {
    // From = Value-length(2) + Insert-address(0x81)  （仅 token，无字符串）
    val body = byteArrayOf(0x81.toByte())
    val bytes = pdu(
      shortInt(0x0C), shortInt(0x02),
      byteArrayOf(0x89.toByte(), body.size.toByte()) + body,
    )
    val n = MmsPduParser.parseNotification(bytes)!!
    assertNull(n.from)
  }

  @Test
  fun `skips expiry and size without breaking later fields`() {
    val bytes = pdu(
      shortInt(0x0C), shortInt(0x02),
      // Expiry = Value-length(6) + Absolute(0x80) + Long-integer(4 bytes)
      byteArrayOf(0x88.toByte(), 0x06, 0x80.toByte()) + longInt(1_800_000_000L),
      // Message-Size long-integer
      byteArrayOf(0x8E.toByte()) + longInt(2048L),
      fromHeader("10086"),
      byteArrayOf(0x83.toByte()) + text("http://y"),
    )
    val n = MmsPduParser.parseNotification(bytes)!!
    assertEquals("10086", n.from)
    assertEquals("http://y", n.contentLocation)
  }

  @Test
  fun `returns null for empty or untyped pdu`() {
    assertNull(MmsPduParser.parseNotification(null))
    assertNull(MmsPduParser.parseNotification(ByteArray(0)))
    // 只有 Transaction-Id，没有 Message-Type
    assertNull(MmsPduParser.parseNotification(pdu(byteArrayOf(0x98.toByte()) + text("x"))))
  }

  @Test
  fun `stops on unknown header and keeps parsed fields`() {
    val bytes = pdu(
      shortInt(0x0C), shortInt(0x02),
      fromHeader("10086"),
      byteArrayOf(0xFF.toByte(), 0x01), // 未知头 → 停止
      byteArrayOf(0x83.toByte()) + text("http://should-not-see"),
    )
    val n = MmsPduParser.parseNotification(bytes)!!
    assertEquals("10086", n.from)
    assertNull(n.contentLocation)
  }

  @Test
  fun `date zero is treated as missing`() {
    val bytes = pdu(
      shortInt(0x0C), shortInt(0x02),
      byteArrayOf(0x85.toByte()) + longInt(0L),
      fromHeader("1"),
    )
    assertNull(MmsPduParser.parseNotification(bytes)!!.dateSec)
  }

  @Test
  fun `retrieve conf message type is preserved`() {
    val bytes = pdu(shortInt(0x0C), shortInt(0x04)) // 0x84 Retrieve.conf
    assertEquals(
      MmsPduParser.MESSAGE_TYPE_RETRIEVE_CONF,
      MmsPduParser.parseNotification(bytes)!!.messageType,
    )
  }
}
