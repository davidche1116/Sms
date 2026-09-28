package com.dc16.sms

import android.database.ContentObserver
import android.database.Cursor
import android.database.DataSetObserver
import android.net.Uri
import android.os.Bundle

/**
 * 手写 Cursor 测试替身：只实现 [SmsAccess.readRow] / 查询循环用到的方法，
 * 其余接口方法显式抛 [UnsupportedOperationException]，避免误用时静默假绿。
 *
 * 行模型：`columns` 为列名顺序，每行是与之等长的取值列表（可含 null）。
 */
class FakeCursor(
  private val columns: List<String>,
  private val rows: List<List<Any?>>,
) : Cursor {

  private var position = -1
  private var closed = false

  /** 累计 `moveToNext` 成功次数：性能自证里断言短路扫描没有把全库读完。 */
  var rowsConsumed: Int = 0
    private set

  override fun getCount(): Int = rows.size

  override fun getPosition(): Int = position

  override fun move(offset: Int): Boolean = moveToPosition(position + offset)

  override fun moveToNext(): Boolean {
    if (position + 1 >= rows.size) return false
    position++
    rowsConsumed++
    return true
  }

  override fun moveToPosition(position: Int): Boolean {
    if (position < -1 || position >= rows.size) return false
    this.position = position
    return true
  }

  override fun moveToFirst(): Boolean = moveToPosition(0)

  override fun moveToLast(): Boolean = moveToPosition(rows.lastIndex)

  override fun moveToPrevious(): Boolean = moveToPosition(position - 1)

  override fun isFirst(): Boolean = position == 0

  override fun isLast(): Boolean = position == rows.lastIndex

  override fun isBeforeFirst(): Boolean = position < 0

  override fun isAfterLast(): Boolean = position >= rows.size

  override fun getColumnIndex(columnName: String): Int = columns.indexOf(columnName)

  override fun getColumnIndexOrThrow(columnName: String): Int =
    getColumnIndex(columnName).also {
      if (it < 0) throw IllegalArgumentException("no column $columnName")
    }

  override fun getColumnName(columnIndex: Int): String = columns[columnIndex]

  override fun getColumnNames(): Array<String> = columns.toTypedArray()

  override fun getColumnCount(): Int = columns.size

  private fun value(i: Int): Any? = rows[position][i]

  override fun isNull(i: Int): Boolean = value(i) == null

  override fun getString(i: Int): String? = value(i) as? String

  override fun getShort(i: Int): Short = (value(i) as Number).toShort()

  override fun getInt(i: Int): Int = (value(i) as Number).toInt()

  override fun getLong(i: Int): Long = (value(i) as Number).toLong()

  override fun getFloat(i: Int): Float = (value(i) as Number).toFloat()

  override fun getDouble(i: Int): Double = (value(i) as Number).toDouble()

  override fun getBlob(i: Int): ByteArray = value(i) as ByteArray

  override fun getType(i: Int): Int = when (value(i)) {
    null -> Cursor.FIELD_TYPE_NULL
    is ByteArray -> Cursor.FIELD_TYPE_BLOB
    is Float, is Double -> Cursor.FIELD_TYPE_FLOAT
    is Number -> Cursor.FIELD_TYPE_INTEGER
    else -> Cursor.FIELD_TYPE_STRING
  }

  override fun close() {
    closed = true
  }

  override fun isClosed(): Boolean = closed

  // ---- 以下接口方法本测试不使用 ----

  override fun copyStringToBuffer(columnIndex: Int, buffer: android.database.CharArrayBuffer) =
    unsupported()

  @Deprecated("Deprecated in Java")
  override fun deactivate() = unsupported()

  @Deprecated("Deprecated in Java")
  override fun requery(): Boolean = unsupported()

  override fun registerContentObserver(observer: ContentObserver?) = unsupported()

  override fun unregisterContentObserver(observer: ContentObserver?) = unsupported()

  override fun registerDataSetObserver(observer: DataSetObserver?) = unsupported()

  override fun unregisterDataSetObserver(observer: DataSetObserver?) = unsupported()

  override fun setNotificationUri(cr: android.content.ContentResolver?, uri: Uri?) = unsupported()

  override fun getNotificationUri(): Uri? = unsupported()

  override fun getWantsAllOnMoveCalls(): Boolean = unsupported()

  override fun setExtras(extras: Bundle?) = unsupported()

  override fun getExtras(): Bundle = unsupported()

  override fun respond(extras: Bundle?): Bundle = unsupported()

  private fun unsupported(): Nothing =
    throw UnsupportedOperationException("FakeCursor: not used by SmsAccess")
}
