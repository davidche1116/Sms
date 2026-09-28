package com.dc16.sms

/**
 * MMS PDU（OMA-TS-MMS-ENC）最小解析：只覆盖收信骨架入库所需字段。
 *
 * 默认短信应用收到的 `WAP_PUSH_DELIVER` 载荷是 M-Notification.ind（也可能是已取回的
 * M-Retrieve.conf）。完整 smil / 媒体 part 落库依赖 AOSP `PduPersister`（非公开 API），
 * 本解析器**不**重建 part 正文，只抽出元数据写入 `content://mms`（见 [SmsAccess.insertMmsNotification]）。
 *
 * 编码对齐 AOSP `com.google.android.mms.pdu.PduParser`：
 * - 头字段名 / Octet 值：WSP Short-integer（最高位为 1）
 * - Long-integer / Value-length / Text-string / Encoded-string：见各自方法注释
 */
object MmsPduParser {

  /** M-Notification.ind（彩信通知，含 Content-Location）。 */
  const val MESSAGE_TYPE_NOTIFICATION_IND = 0x82

  /** M-Retrieve.conf（已取回的完整彩信）。 */
  const val MESSAGE_TYPE_RETRIEVE_CONF = 0x84

  // 头字段名（wire = token | 0x80，与 AOSP PduHeaders 一致）
  private const val HDR_BCC = 0x81
  private const val HDR_CC = 0x82
  private const val HDR_CONTENT_LOCATION = 0x83
  private const val HDR_CONTENT_TYPE = 0x84
  private const val HDR_DATE = 0x85
  private const val HDR_DELIVERY_REPORT = 0x86
  private const val HDR_DELIVERY_TIME = 0x87
  private const val HDR_EXPIRY = 0x88
  private const val HDR_FROM = 0x89
  private const val HDR_MESSAGE_CLASS = 0x8A
  private const val HDR_MESSAGE_ID = 0x8B
  private const val HDR_MESSAGE_TYPE = 0x8C
  private const val HDR_MMS_VERSION = 0x8D
  private const val HDR_MESSAGE_SIZE = 0x8E
  private const val HDR_PRIORITY = 0x8F
  private const val HDR_READ_REPORT = 0x90
  private const val HDR_REPORT_ALLOWED = 0x91
  private const val HDR_STATUS = 0x95
  private const val HDR_SUBJECT = 0x96
  private const val HDR_TO = 0x97
  private const val HDR_TRANSACTION_ID = 0x98
  private const val HDR_RETRIEVE_STATUS = 0x99
  private const val HDR_RETRIEVE_TEXT = 0x9A

  private const val FROM_ADDRESS_PRESENT = 0x80
  private const val FROM_INSERT_ADDRESS = 0x81
  private const val EXPIRY_ABSOLUTE = 0x80
  private const val EXPIRY_RELATIVE = 0x81

  private const val TEXT_MIN = 0x20
  private const val QUOTE = 0x7F
  private const val SHORT_LENGTH_MAX = 30
  private const val LENGTH_QUOTE = 31

  /** WSP charset：0=未知(按 UTF-8)，3=ISO-8859-1，106=UTF-8。 */
  private const val CHARSET_UTF8 = 106

  /** 插入地址占位（发件人隐藏），不能当真实号码。 */
  const val INSERT_ADDRESS_TOKEN = "insert-address-token"

  /** 解析结果：仅骨架入库所需元数据。 */
  data class MmsNotification(
    val messageType: Int,
    val from: String?,
    val subject: String?,
    val messageId: String?,
    val contentLocation: String?,
    /** 绝对时间秒；无法解析时为 null（入库用当前时间）。 */
    val dateSec: Long?,
  )

  /**
   * 解析彩信 PDU 头。失败返回 null（绝不抛到 BroadcastReceiver）。
   * 未知头字段立即停止扫描并返回已解析字段（宁可少字段，也不错位）。
   */
  fun parseNotification(pdu: ByteArray?): MmsNotification? {
    if (pdu == null || pdu.isEmpty()) return null
    val r = Reader(pdu)
    var messageType = -1
    var from: String? = null
    var subject: String? = null
    var messageId: String? = null
    var contentLocation: String? = null
    var dateSec: Long? = null

    while (r.hasRemaining) {
      val header = r.u8()
      when (header) {
        HDR_MESSAGE_TYPE -> messageType = r.u8()
        HDR_FROM -> from = parseFrom(r)
        HDR_SUBJECT -> subject = parseEncodedString(r)
        HDR_MESSAGE_ID -> messageId = parseTextString(r)
        HDR_CONTENT_LOCATION -> contentLocation = parseTextString(r)
        HDR_DATE -> dateSec = parseLongInteger(r)
        HDR_EXPIRY -> parseExpiry(r)
        HDR_CONTENT_TYPE -> parseContentTypeOrSkip(r)
        HDR_TRANSACTION_ID -> parseTextString(r)
        HDR_MESSAGE_CLASS -> parseMessageClass(r)
        HDR_MMS_VERSION, HDR_PRIORITY, HDR_DELIVERY_REPORT, HDR_READ_REPORT,
        HDR_REPORT_ALLOWED, HDR_STATUS, HDR_RETRIEVE_STATUS,
        -> r.u8()
        HDR_MESSAGE_SIZE -> parseLongInteger(r)
        HDR_DELIVERY_TIME -> parseDeliveryTime(r)
        HDR_TO, HDR_CC, HDR_BCC, HDR_RETRIEVE_TEXT -> parseEncodedString(r)
        else -> break // 未知头：停止，保留已解析字段
      }
    }
    if (messageType < 0) return null
    return MmsNotification(
      messageType = messageType,
      from = from?.trim()?.takeIf { it.isNotEmpty() && it != INSERT_ADDRESS_TOKEN },
      subject = subject?.trim()?.takeIf { it.isNotEmpty() },
      messageId = messageId?.trim()?.takeIf { it.isNotEmpty() },
      contentLocation = contentLocation?.trim()?.takeIf { it.isNotEmpty() },
      dateSec = dateSec?.takeIf { it > 0 },
    )
  }

  // ---- 值编码 ----

  private fun parseFrom(r: Reader): String? {
    // From = Value-length ( Address-present Encoded-string | Insert-address )
    parseValueLength(r)
    return when (val token = r.u8()) {
      FROM_ADDRESS_PRESENT -> parseEncodedString(r)
      FROM_INSERT_ADDRESS -> INSERT_ADDRESS_TOKEN
      else -> null
    }
  }

  private fun parseExpiry(r: Reader) {
    // Expiry = Value-length ( Absolute Date | Relative Delta-seconds )
    parseValueLength(r)
    when (r.u8()) {
      EXPIRY_ABSOLUTE, EXPIRY_RELATIVE -> parseLongInteger(r)
      else -> Unit
    }
  }

  /** Delivery-Time = Value-length ( Absolute Date | Relative Delta-seconds )。 */
  private fun parseDeliveryTime(r: Reader) {
    parseExpiry(r)
  }

  /** Message-Class = Octet * | Text-string。 */
  private fun parseMessageClass(r: Reader) {
    val first = r.peek()
    if (first > 0x7F) r.u8() else parseTextString(r)
  }

  /**
   * Content-Type：Constrained-media 或 Value-length 包裹的 Content-general-form。
   * 通知里少见；只为正确跳过，不解析 multipart body。
   */
  private fun parseContentTypeOrSkip(r: Reader) {
    val first = r.peek()
    if (first in 0 until TEXT_MIN) {
      val len = parseValueLength(r)
      if (len in 0..r.remaining) r.skip(len)
      else r.skip(r.remaining)
    } else if (first > 0x7F) {
      r.u8()
    } else {
      parseTextString(r)
    }
  }

  private fun parseEncodedString(r: Reader): String? {
    // Encoded-string = Text-string | Value-length Char-set Text-string
    val first = r.peek()
    if (first == 0) {
      r.u8()
      return ""
    }
    var charset = 0
    if (first in 0 until TEXT_MIN) {
      parseValueLength(r)
      charset = r.u8() and 0x7F
    }
    val bytes = parseTextStringBytes(r) ?: return null
    return decode(bytes, charset)
  }

  private fun parseTextString(r: Reader): String? {
    val bytes = parseTextStringBytes(r) ?: return null
    return decode(bytes, charset = 0)
  }

  private fun parseTextStringBytes(r: Reader): ByteArray? {
    // Text-string = [Quote] *TEXT End-of-string(0)
    if (!r.hasRemaining) return null
    if (r.peek() == QUOTE) r.u8()
    val out = ArrayList<Byte>()
    while (r.hasRemaining) {
      val b = r.u8()
      if (b == 0) break
      out.add(b.toByte())
    }
    return out.toByteArray()
  }

  private fun parseValueLength(r: Reader): Int {
    val first = r.u8()
    return when {
      first <= SHORT_LENGTH_MAX -> first
      first == LENGTH_QUOTE -> parseUintvar(r)
      else -> -1
    }
  }

  private fun parseLongInteger(r: Reader): Long {
    // Long-integer = Short-length Multi-octet-integer（大端，长度 1–8）
    val count = r.u8()
    if (count <= 0 || count > 8) return 0L
    var v = 0L
    repeat(count) {
      v = (v shl 8) or (r.u8().toLong() and 0xFF)
    }
    return v
  }

  private fun parseUintvar(r: Reader): Int {
    var result = 0
    var guard = 0
    while (r.hasRemaining && guard++ < 5) {
      val b = r.u8()
      result = (result shl 7) or (b and 0x7F)
      if (b and 0x80 == 0) break
    }
    return result
  }

  private fun decode(bytes: ByteArray, charset: Int): String {
    val cs = when (charset) {
      2 -> Charsets.US_ASCII
      3 -> Charsets.ISO_8859_1
      CHARSET_UTF8, 0 -> Charsets.UTF_8
      else -> Charsets.UTF_8
    }
    return String(bytes, cs)
  }

  /** 只读游标。越界安全，解析失败靠返回值而非异常。 */
  private class Reader(private val buf: ByteArray) {
    private var pos = 0
    val remaining: Int get() = buf.size - pos
    val hasRemaining: Boolean get() = pos < buf.size

    fun peek(): Int = if (hasRemaining) buf[pos].toInt() and 0xFF else -1

    fun u8(): Int {
      if (!hasRemaining) return 0
      return buf[pos++].toInt() and 0xFF
    }

    fun skip(n: Int) {
      pos = (pos + n).coerceIn(0, buf.size)
    }
  }
}
