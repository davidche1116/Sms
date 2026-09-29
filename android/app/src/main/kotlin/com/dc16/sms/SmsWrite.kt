package com.dc16.sms

import android.content.ContentValues
import android.content.Context
import android.net.Uri
import android.provider.BaseColumns
import android.provider.Telephony
import android.util.Log

/** Write-related logic: delete, insert, test SMS operations. */
internal class SmsWrite(private val smsAccess: SmsAccess) {

  private val context: Context get() = smsAccess.context

  /**
   * 批量删除。按 `is_mms` 路由到 `content://sms` / `content://mms`，绝不跨表删。
   *
   * 入参每项为：
   * - [Number]：纯 SMS `_id`（旧调用兼容）
   * - Map `{"id": Int, "is_mms": 0|1}`：混合目标
   *
   * 逐 chunk 计入 failed：某 chunk 抛异常时该 chunk 内全部目标记失败并继续后续
   * chunk（尽量全成，与 `insertSmsBatch` 策略一致）。
   *
   * @return Map:
   *   ok       Boolean   false=整批未执行/整批失败；true=已受理（**可含部分失败**）
   *   deleted  Int       实际删除行数（SMS+MMS，contentResolver 返回值之和）
   *   failed   Int       失败条数
   *   error    String?   整批级错误：null|not_default|failed|unknown
   *   errors   List      [{index, code, message}]，index 为入参 targets 下标；-1=整批级
   */
  fun deleteSmsBatch(targets: List<Any?>): Map<String, Any?> {
    if (targets.isEmpty()) {
      return deleteResult(ok = true, deleted = 0, failed = 0, error = null, errors = emptyList())
    }
    if (smsAccess.isDefaultSms() != true) {
      return deleteResult(
        ok = false,
        deleted = 0,
        failed = targets.size,
        error = ChannelCodes.DELETE_ERROR_NOT_DEFAULT,
        errors = listOf(
          deleteError(-1, ChannelCodes.DELETE_ERROR_NOT_DEFAULT, "not default sms app"),
        ),
      )
    }
    val (sms, mms) = smsAccess.splitDeleteTargets(targets)
    val errors = mutableListOf<Map<String, Any?>>()
    var deleted = 0
    var failed = 0

    // 直接把 Telephony.*.CONTENT_URI（平台类型，桩里为 null）传给 delete，
    // 不经过非空 Kotlin 参数，避免 JVM 单测 NPE。因此 SMS/MMS 两段循环内联展开。
    for (chunk in sms.chunked(900)) {
      try {
        deleted += context.contentResolver.delete(
          Telephony.Sms.CONTENT_URI,
          "_id IN (${chunk.joinToString(",") { "?" }})",
          chunk.map { it.id.toString() }.toTypedArray(),
        )
      } catch (e: Exception) {
        Log.e(SmsAccess.TAG, "deleteSmsBatch sms", e)
        failed += chunk.size
        for (t in chunk) {
          errors.add(
            deleteError(t.index, ChannelCodes.DELETE_ERROR_FAILED, "delete failed"),
          )
        }
      }
    }
    for (chunk in mms.chunked(900)) {
      try {
        deleted += context.contentResolver.delete(
          Telephony.Mms.CONTENT_URI,
          "_id IN (${chunk.joinToString(",") { "?" }})",
          chunk.map { it.id.toString() }.toTypedArray(),
        )
      } catch (e: Exception) {
        Log.e(SmsAccess.TAG, "deleteSmsBatch mms", e)
        failed += chunk.size
        for (t in chunk) {
          errors.add(
            deleteError(t.index, ChannelCodes.DELETE_ERROR_FAILED, "delete failed"),
          )
        }
      }
    }

    // 零删零失败 = 成功（含「本就不在库中」）；零删且有失败 = 整批失败。
    if (deleted == 0 && failed > 0) {
      return deleteResult(
        ok = false,
        deleted = 0,
        failed = failed,
        error = ChannelCodes.DELETE_ERROR_FAILED,
        errors = errors,
      )
    }
    return deleteResult(
      ok = true,
      deleted = deleted,
      failed = failed,
      error = null,
      errors = errors,
    )
  }

  /**
   * 导入插入：只新增，不改不删。需默认短信应用。
   * row: address, body, date(ms), type(1 inbox/2 sent/3 draft), sub_id
   *
   * 策略：**逐行 insert + 尽量全成 + 逐行明细**（不中途放弃）。
   *
   * 为何不用 `ContentResolver.applyBatch` 做整批提交：
   * 1. AOSP `SmsProvider` 不覆写 `applyBatch`，默认实现**逐条 apply、无事务**，
   *    中途失败已成功的行不回滚——「批」本身并不原子。
   * 2. `OperationApplicationException` **不暴露失败下标**（公开 API 只有
   *    `getNumSuccessfulYieldPoints`，语义是 yield 点数不是操作数），失败后无法
   *    安全定位续插起点；盲目重试整片会**重复插入**真实短信。
   * 因此选择可精确回溯的逐行路径：每行独立 insert，失败只影响该行并记录
   * `index/code/message`，其余行继续，保证 inserted 计数准确、错误可对应 CSV 行。
   *
   * 入参保持与 Dart 载荷 **1:1 下标**：非 Map 行不丢弃，按原下标记 failed，
   * 避免 `mapNotNull` 过滤导致 `errors[].index` 相对 Dart `rows` 错位。
   *
   * @param rows 通道原始列表，每项应为 Map；非 Map 记 `failed`/`invalid` 明细。
   * @return Map:
   *   ok       Boolean  是否非失败态（false=非默认/整批未执行）
   *   inserted Int      成功条数
   *   failed   Int      失败条数
   *   errors   List     [{index, code, message}]，index 为入参 rows 下标；-1=整批级
   */
  fun insertSmsBatch(rows: List<Any?>): Map<String, Any?> {
    if (rows.isEmpty()) {
      return insertResult(ok = true, inserted = 0, failed = 0, errors = emptyList())
    }
    if (smsAccess.isDefaultSms() != true) {
      return insertResult(
        ok = false,
        inserted = 0,
        failed = rows.size,
        errors = listOf(
          insertError(-1, ChannelCodes.INSERT_ERROR_NOT_DEFAULT, "not default sms app"),
        ),
      )
    }
    val errors = mutableListOf<Map<String, Any?>>()
    var inserted = 0
    var failed = 0
    rows.forEachIndexed { i, item ->
      val row = item as? Map<*, *>
      if (row == null) {
        failed++
        errors.add(insertError(i, ChannelCodes.INSERT_ERROR_INVALID, "invalid row: expected map"))
        return@forEachIndexed
      }
      try {
        val (uri, values) = buildInsert(row)
        if (context.contentResolver.insert(uri, values) != null) inserted++
        else {
          failed++
          errors.add(insertError(i, ChannelCodes.INSERT_ERROR_FAILED, "insert returned null"))
        }
      } catch (e: Exception) {
        Log.e(SmsAccess.TAG, "insertSmsBatch row $i", e)
        failed++
        errors.add(insertError(i, ChannelCodes.INSERT_ERROR_FAILED, "insert failed"))
      }
    }
    return insertResult(ok = true, inserted = inserted, failed = failed, errors = errors)
  }

  private fun buildInsert(row: Map<*, *>): Pair<Uri, ContentValues> {
    val type = (row["type"] as? Number)?.toInt() ?: Telephony.Sms.MESSAGE_TYPE_INBOX
    val date = (row["date"] as? Number)?.toLong() ?: System.currentTimeMillis()
    val uri = when (type) {
      Telephony.Sms.MESSAGE_TYPE_SENT,
      Telephony.Sms.MESSAGE_TYPE_OUTBOX,
      Telephony.Sms.MESSAGE_TYPE_FAILED,
      Telephony.Sms.MESSAGE_TYPE_QUEUED -> Telephony.Sms.Sent.CONTENT_URI
      Telephony.Sms.MESSAGE_TYPE_DRAFT -> Telephony.Sms.Draft.CONTENT_URI
      else -> Telephony.Sms.Inbox.CONTENT_URI
    }
    val v = ContentValues().apply {
      put(Telephony.Sms.ADDRESS, row["address"] as? String)
      put(Telephony.Sms.BODY, row["body"] as? String)
      put(Telephony.Sms.DATE, date)
      put(Telephony.Sms.DATE_SENT, date)
      put(Telephony.Sms.READ, 1)
      put(Telephony.Sms.SEEN, 1)
      put(Telephony.Sms.TYPE, type)
      val sub = (row["sub_id"] as? Number)?.toInt()
      if (sub != null) put(Telephony.Sms.SUBSCRIPTION_ID, sub)
    }
    return uri to v
  }

  private fun insertResult(
    ok: Boolean,
    inserted: Int,
    failed: Int,
    errors: List<Map<String, Any?>>,
  ): Map<String, Any?> = mapOf(
    ChannelCodes.KEY_OK to ok,
    ChannelCodes.KEY_INSERTED to inserted,
    ChannelCodes.KEY_FAILED to failed,
    ChannelCodes.KEY_ERRORS to errors,
  )

  private fun insertError(index: Int, code: String, message: String): Map<String, Any?> = mapOf(
    ChannelCodes.KEY_INDEX to index,
    ChannelCodes.KEY_CODE to code,
    ChannelCodes.KEY_MESSAGE to message,
  )

  private fun deleteResult(
    ok: Boolean,
    deleted: Int,
    failed: Int,
    error: String?,
    errors: List<Map<String, Any?>>,
  ): Map<String, Any?> = mapOf(
    ChannelCodes.KEY_OK to ok,
    ChannelCodes.KEY_DELETED to deleted,
    ChannelCodes.KEY_FAILED to failed,
    ChannelCodes.KEY_ERROR to error,
    ChannelCodes.KEY_ERRORS to errors,
  )

  private fun deleteError(index: Int, code: String, message: String): Map<String, Any?> = mapOf(
    ChannelCodes.KEY_INDEX to index,
    ChannelCodes.KEY_CODE to code,
    ChannelCodes.KEY_MESSAGE to message,
  )

  /**
   * QA 专用：插入带唯一前缀的测试短信，只新增、不改旧数据。
   * 仅 debuggable 包可用，避免 release 留写库入口。
   * @return 插入成功的 _id 列表；null=非默认/非 debug/失败
   */
  fun insertTestSms(count: Int, bodyPrefix: String): List<Int>? {
    if (smsAccess.isDefaultSms() != true) return null
    val flags = context.applicationInfo.flags
    if ((flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) == 0) return null
    return try {
      val ids = mutableListOf<Int>()
      val now = System.currentTimeMillis()
      repeat(count.coerceIn(1, 20)) { i ->
        val v = android.content.ContentValues().apply {
          put(Telephony.Sms.ADDRESS, "10086")
          put(Telephony.Sms.BODY, "$bodyPrefix #${i + 1}")
          put(Telephony.Sms.DATE, now + i)
          put(Telephony.Sms.DATE_SENT, now + i)
          put(Telephony.Sms.READ, 1)
          put(Telephony.Sms.SEEN, 1)
          put(Telephony.Sms.TYPE, Telephony.Sms.MESSAGE_TYPE_INBOX)
        }
        val uri = context.contentResolver.insert(Telephony.Sms.Inbox.CONTENT_URI, v)
        val id = uri?.lastPathSegment?.toIntOrNull()
        if (id != null) ids.add(id)
      }
      ids
    } catch (e: Exception) {
      Log.e(SmsAccess.TAG, "insertTestSms", e)
      null
    }
  }

  /**
   * QA 专用：只删除 body 以前缀开头的短信（绝不匹配真实短信）。
   * @return 删除条数；null=非默认/失败
   */
  fun deleteTestSmsByPrefix(bodyPrefix: String): Int? {
    if (bodyPrefix.isBlank()) return null
    if (smsAccess.isDefaultSms() != true) return null
    val flags = context.applicationInfo.flags
    if ((flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) == 0) return null
    return try {
      context.contentResolver.delete(
        Telephony.Sms.CONTENT_URI,
        "${Telephony.Sms.BODY} LIKE ?",
        arrayOf("$bodyPrefix%"),
      )
    } catch (e: Exception) {
      Log.e(SmsAccess.TAG, "deleteTestSmsByPrefix", e)
      null
    }
  }

  /** 只保留 body 以前缀开头的 id，用于 QA 删除前的安全过滤。 */
  fun filterTestIds(ids: List<Int>, bodyPrefix: String): List<Int> {
    if (ids.isEmpty() || bodyPrefix.isBlank()) return emptyList()
    return try {
      val keep = mutableSetOf<Int>()
      context.contentResolver.query(
        Telephony.Sms.CONTENT_URI,
        arrayOf(BaseColumns._ID, Telephony.Sms.BODY),
        "${Telephony.Sms.BODY} LIKE ?",
        arrayOf("$bodyPrefix%"),
        null,
      )?.use { c ->
        while (c.moveToNext()) {
          keep.add(c.getInt(0))
        }
      }
      ids.filter { it in keep }
    } catch (e: Exception) {
      Log.e(SmsAccess.TAG, "filterTestIds", e)
      emptyList()
    }
  }

  /**
   * 默认短信应用收到彩信通知（`WAP_PUSH_DELIVER`）时写入骨架行。
   *
   * 只落元数据（`content://mms` + `addr` + 主题 text part）：完整 smil/媒体 part
   * 落库依赖非公开的 `PduPersister`，本应用不做下载重建（见 README「彩信支持范围」）。
   * 骨架行保证新彩信**不丢条**（可浏览/导出/删除），正文占位由 Dart 侧补齐。
   *
   * AOSP MmsProvider 字段：`msg_box` / `read` / `seen` / `date`（**秒**）/ `m_id` /
   * `sub_id` / `thread_id` / `ct_l` / `m_type` / `sub`。
   *
   * @return 插入的 mms `_id`；null=失败
   */
  @androidx.annotation.VisibleForTesting
  internal fun insertMmsNotification(
    n: MmsPduParser.MmsNotification,
    subId: Int?,
  ): Int? = try {
    // 彩信表 date 是秒；通知 Date 缺失/非法时用当前时间。
    val dateSec = n.dateSec?.takeIf { it > 0 } ?: (System.currentTimeMillis() / 1000)
    val address = n.from
    val threadId = address?.let { addr ->
      try {
        Telephony.Threads.getOrCreateThreadId(context, addr)
      } catch (_: Exception) {
        null
      }
    }
    val v = android.content.ContentValues().apply {
      put(Telephony.Mms.MESSAGE_BOX, Telephony.Mms.MESSAGE_BOX_INBOX)
      put(Telephony.Mms.READ, 0)
      put(Telephony.Mms.SEEN, 0)
      put(Telephony.Mms.DATE, dateSec)
      put(Telephony.Mms.DATE_SENT, dateSec)
      put(Telephony.Mms.MESSAGE_TYPE, n.messageType)
      put(Telephony.Mms.TEXT_ONLY, 0)
      if (threadId != null) put(Telephony.Mms.THREAD_ID, threadId)
      if (n.messageId != null) put(Telephony.Mms.MESSAGE_ID, n.messageId)
      if (n.subject != null) put(Telephony.Mms.SUBJECT, n.subject)
      if (n.contentLocation != null) put(Telephony.Mms.CONTENT_LOCATION, n.contentLocation)
      if (subId != null && subId >= 0) put(Telephony.Mms.SUBSCRIPTION_ID, subId)
    }
    val uri = context.contentResolver.insert(Telephony.Mms.Inbox.CONTENT_URI, v)
    val id = uri?.lastPathSegment?.toIntOrNull() ?: return null
    if (address != null) insertMmsAddr(id, address)
    // 主题写入 text part，使本应用列表正文摘要非空（无主题时 Dart 显示「[彩信]」）。
    val subject = n.subject
    if (!subject.isNullOrEmpty()) insertMmsTextPart(id, subject)
    id
  } catch (e: Exception) {
    Log.e(SmsAccess.TAG, "insertMmsNotification", e)
    null
  }

  /** `content://mms/addr` 写一行 FROM（type=137）。失败忽略，不回滚主行。 */
  private fun insertMmsAddr(msgId: Int, address: String) {
    try {
      val v = android.content.ContentValues().apply {
        put(Telephony.Mms.Addr.MSG_ID, msgId)
        put(Telephony.Mms.Addr.ADDRESS, address)
        put(Telephony.Mms.Addr.TYPE, SmsAccess.MMS_ADDR_TYPE_FROM)
        put(Telephony.Mms.Addr.CHARSET, 0)
      }
      context.contentResolver.insert(SmsAccess.mmsAddrUri(), v)
    } catch (e: Exception) {
      Log.e(SmsAccess.TAG, "insertMmsAddr", e)
    }
  }

  /** `content://mms/part` 写一行 text/plain（主题/摘要）。 */
  private fun insertMmsTextPart(msgId: Int, text: String) {
    try {
      val v = android.content.ContentValues().apply {
        put(Telephony.Mms.Part.MSG_ID, msgId)
        put(Telephony.Mms.Part.CONTENT_TYPE, "text/plain")
        put(Telephony.Mms.Part.TEXT, text)
        put(Telephony.Mms.Part.CHARSET, 106) // UTF-8
      }
      context.contentResolver.insert(SmsAccess.mmsPartUri(), v)
    } catch (e: Exception) {
      Log.e(SmsAccess.TAG, "insertMmsTextPart", e)
    }
  }
}
