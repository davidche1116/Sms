package com.dc16.sms

import android.content.ContentValues
import android.content.Context
import android.database.Cursor
import android.net.Uri
import android.provider.BaseColumns
import android.provider.Telephony
import android.util.Log
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicInteger

/** Query-related logic for SMS and MMS. */
internal class SmsQuery(private val smsAccess: SmsAccess) {

  private val context: Context get() = smsAccess.context

  // ---- Count cache: avoid repeated full-table counts on page turns ----
  // Keyed by (generation, selection, args); invalidated by TTL (30s) since the count
  // only changes when messages are added/removed, which is rare during browsing.
  private data class CountCacheEntry(val count: Int, val timestamp: Long)

  // 查询线程读写、写入线程清空（MainActivity 删除/插入后调 clearCountCache），
  // 必须用并发容器。代际号进一步保证「clear 与 put 交错」时旧值永不命中：
  // put 携带旧代际的 key，clear 后读取都用新代际，过期条目自然落空。
  private val countCache = ConcurrentHashMap<String, CountCacheEntry>()
  private val countCacheGen = AtomicInteger(0)
  private val COUNT_CACHE_TTL_MS = 30_000L

  /** 数据变更（插入/删除）后清空计数缓存，避免分页总数过期。 */
  fun clearCountCache() {
    countCacheGen.incrementAndGet()
    countCache.clear()
  }

  /**
   * 查询短信 + 彩信，合并到同一列表（真分页，见 QUERY_DELETE_DESIGN §5）。
   *
   * 策略：
   * 1. **单 URI 优先**：默认只查 `Telephony.Sms/Mms.CONTENT_URI`（AOSP 上已是
   *    inbox/sent/draft 并集）；仅当整表结果为空才回落子箱 URI。
   * 2. **真分页**：SMS/MMS 各自按 `(date DESC, _id DESC)` 从 Provider 取流，
   *    尝试把 `LIMIT offset+limit` 下推到 sortOrder；读取侧无论 LIMIT 是否生效
   *    都在 `offset+limit` 条处短路，归并后只物化本页，绝不全库 LinkedHashMap。
   * 3. **total** 与切页解耦：分页时用轻量 count（投影仅 `_id`），全量时用可用行数。
   *
   * @param limit null=全量（兼容旧调用）；非空时按 date 降序切页
   * @param offset 跳过条数，仅在 limit 非空时生效
   * @return messages + total + error(null|permission|unknown) + partial + warnings，
   *   键与错误值见 [ChannelCodes]。语义：
   *   - 有数据但某路子查询失败 → `error=null, partial=true, warnings=[…]`（不丢其它路已有行）
   *   - 完全无数据且失败 → `error=permission|unknown`，`partial=false`（与 error 互斥）
   *   - 全成功 → `error=null, partial=false, warnings=[]`
   */
  fun querySms(
    address: String?,
    limit: Int? = null,
    offset: Int = 0,
    keyword: String? = null,
    startDateMs: Long? = null,
    endDateMs: Long? = null,
    type: Int? = null,
  ): Map<String, Any?> {
    if (!smsAccess.hasReadSms() && smsAccess.isDefaultSms() != true) {
      return mapOf(
        ChannelCodes.KEY_MESSAGES to emptyList<Any>(),
        ChannelCodes.KEY_TOTAL to 0,
        ChannelCodes.KEY_ERROR to ChannelCodes.QUERY_ERROR_PERMISSION,
        ChannelCodes.KEY_PARTIAL to false,
        ChannelCodes.KEY_WARNINGS to emptyList<Any>(),
      )
    }
    val safeOffset = offset.coerceAtLeast(0)
    val safeLimit = limit?.coerceAtLeast(0)
    // 每条有序流最多物化 offset+limit 条即可保证归并后切页正确。
    // `null` limit = 全量；分页即使用例把 offset+limit 加到 Int.MAX_VALUE 也不走全量物化。
    val unlimited = safeLimit == null
    val maxRows = when {
      unlimited -> Int.MAX_VALUE
      safeLimit == 0 -> 0
      else -> (safeOffset.toLong() + safeLimit.toLong())
        .coerceAtMost(Int.MAX_VALUE.toLong()).toInt()
    }

    // Build WHERE clause with all filter conditions
    val (sel, args) = buildSelection(
      address = address,
      keyword = keyword,
      startDateMs = startDateMs,
      endDateMs = endDateMs,
      type = type,
    )

    // type=3 (MMS only): skip SMS query entirely
    val sms: StreamScan
    if (type == 3) {
      sms = StreamScan.EMPTY
    } else {
    // URI 以 lambda 透传平台类型（JVM 桩里 CONTENT_URI=null），避免非空 Kotlin 参数 NPE。
    sms = scanStream(
      tableId = "sms",
      query = TableQuery { proj, s, a, sort ->
        context.contentResolver.query(Telephony.Sms.CONTENT_URI, proj, s, a, sort)
      },
      fallbacks = listOf(
        TableQuery { proj, s, a, sort ->
          context.contentResolver.query(Telephony.Sms.Inbox.CONTENT_URI, proj, s, a, sort)
        },
        TableQuery { proj, s, a, sort ->
          context.contentResolver.query(Telephony.Sms.Sent.CONTENT_URI, proj, s, a, sort)
        },
        TableQuery { proj, s, a, sort ->
          context.contentResolver.query(Telephony.Sms.Draft.CONTENT_URI, proj, s, a, sort)
        },
      ),
      projection = SmsAccess.PROJECTION,
      selection = sel,
      args = args,
      maxRows = maxRows,
      unlimited = unlimited,
      read = ::readRow,
    )
    }

    // 彩信 address 在 addr 表：优先下推 `_id IN`，过大则内存收窄（见 scanStream.keepRow）。
    // 彩信 keyword 在 part 表：同理，先查 part 表取匹配 mid，再与 MMS ID 集合求交。
    val warns = QueryWarns()
    val mmsAddrFilter = if (address.isNullOrEmpty()) null else queryMmsIdsByAddress(address, warns)
    val mmsKeywordFilter = if (keyword.isNullOrEmpty()) null else queryMmsIdsByKeyword(keyword, warns)
    // 两个过滤器都非空时取交集；任一为空集则 MMS 直接短路
    val mmsIdFilter: Set<Int>? = when {
      mmsAddrFilter == null -> mmsKeywordFilter
      mmsKeywordFilter == null -> mmsAddrFilter
      mmsAddrFilter.isEmpty() -> emptySet()
      mmsKeywordFilter.isEmpty() -> emptySet()
      else -> mmsAddrFilter.intersect(mmsKeywordFilter)
    }
    val mms: StreamScan
    if (mmsIdFilter != null && mmsIdFilter.isEmpty()) {
      mms = StreamScan.EMPTY
    } else {
      val ids = mmsIdFilter
      val pushIn = ids != null && ids.size <= SmsAccess.MMS_ID_IN_MAX
      // Build MMS selection: address filter + date range + type filter (msg_box)
      val mmsParts = mutableListOf<String>()
      val mmsArgList = mutableListOf<String>()
      if (pushIn) {
        mmsParts.add("_id IN (${ids.joinToString(",") { "?" }})")
        mmsArgList.addAll(ids.map { it.toString() })
      }
      // 彩信 date 列是**秒**（readMmsRow 读回时 ×1000 对齐毫秒），下推需 /1000；
      // endDateMs 为 23:59:59.999，截断到秒后仍是当天闭区间。
      if (startDateMs != null) {
        mmsParts.add("${Telephony.Mms.DATE} >= ?")
        mmsArgList.add((startDateMs / 1000).toString())
      }
      if (endDateMs != null) {
        mmsParts.add("${Telephony.Mms.DATE} <= ?")
        mmsArgList.add((endDateMs / 1000).toString())
      }
      // type=1 仅收件箱 / type=2 仅已发送。与 Dart `SmsItem.kind` 对齐：
      // 发送侧 = 非收件箱（草稿 msg_box=3 归入发送侧，见 filter_sheet.dart 契约）。
      when (type) {
        1 -> {
          mmsParts.add("${Telephony.Mms.MESSAGE_BOX}=?")
          mmsArgList.add(Telephony.Mms.MESSAGE_BOX_INBOX.toString())
        }
        2 -> {
          mmsParts.add("${Telephony.Mms.MESSAGE_BOX}<>?")
          mmsArgList.add(Telephony.Mms.MESSAGE_BOX_INBOX.toString())
        }
      }
      val mmsSel = if (mmsParts.isEmpty()) null else mmsParts.joinToString(" AND ")
      val mmsArgs = if (mmsArgList.isEmpty()) null else mmsArgList.toTypedArray()
      val memoryFilter = if (ids != null && !pushIn) ids else null
      mms = scanStream(
        tableId = "mms",
        query = TableQuery { proj, s, a, sort ->
          context.contentResolver.query(Telephony.Mms.CONTENT_URI, proj, s, a, sort)
        },
        fallbacks = listOf(
          TableQuery { proj, s, a, sort ->
            context.contentResolver.query(Telephony.Mms.Inbox.CONTENT_URI, proj, s, a, sort)
          },
          TableQuery { proj, s, a, sort ->
            context.contentResolver.query(Telephony.Mms.Sent.CONTENT_URI, proj, s, a, sort)
          },
          TableQuery { proj, s, a, sort ->
            context.contentResolver.query(Telephony.Mms.Draft.CONTENT_URI, proj, s, a, sort)
          },
        ),
        projection = SmsAccess.MMS_PROJECTION,
        selection = mmsSel,
        args = mmsArgs,
        maxRows = maxRows,
        unlimited = unlimited,
        read = ::readMmsRow,
        keepRow = memoryFilter?.let { ids -> { row: Map<String, Any?> -> (row["_id"] as? Int) in ids } },
      )
    }

    // 切页前必须全局定序：date 降序（null 最早）；同 date 时 is_mms 降序 + _id 降序作稳定次键，
    // 与 Dart `uid` 序一致，避免同 date 跨页抖动。
    val merged = mergeByDateDesc(listOf(sms.rows, mms.rows), maxRows)
    val page = if (safeLimit == null) {
      merged
    } else {
      merged.drop(safeOffset).take(safeLimit)
    }
    // 正文/号码只对本页彩信补全（addr/part 批量查），避免对全库 N+1。
    val enriched = enrichMmsRows(page, warns)
    val total = sms.total + mms.total
    val anyRow = total > 0 || sms.rows.isNotEmpty() || mms.rows.isNotEmpty()
    // 单路异常 → 对应 warning；不因单路失败丢弃其它路已有行。
    if (sms.security) warns.add(ChannelCodes.WARN_SMS_URI_SECURITY)
    if (sms.other) warns.add(ChannelCodes.WARN_SMS_URI_FAILED)
    if (mms.security) warns.add(ChannelCodes.WARN_MMS_URI_SECURITY)
    if (mms.other) warns.add(ChannelCodes.WARN_MMS_URI_FAILED)

    // error 与 partial 互斥：
    // - 完全无数据且有失败 → error（旧语义），partial=false
    // - 有数据但部分失败 → error=null, partial=true
    // - 全成功 / 空库无失败 → error=null, partial=false
    val error = when {
      anyRow -> null
      sms.security || mms.security -> ChannelCodes.QUERY_ERROR_PERMISSION
      sms.other || mms.other -> ChannelCodes.QUERY_ERROR_UNKNOWN
      else -> null
    }
    val partial = error == null && warns.isNotEmpty()
    return mapOf(
      ChannelCodes.KEY_MESSAGES to enriched,
      ChannelCodes.KEY_TOTAL to total,
      ChannelCodes.KEY_ERROR to error,
      ChannelCodes.KEY_PARTIAL to partial,
      ChannelCodes.KEY_WARNINGS to warns.toWireList(),
    )
  }


  /**
   * 构建 SMS 查询的 WHERE 条件和参数。
   *
   * 支持：address 精确匹配、keyword LIKE 匹配 body/address、
   * 日期范围、type 过滤（1=收件箱, 2=已发送（含草稿等非收件）, 3=草稿, 4=待发, 5=失败）。
   */
  private fun buildSelection(
    address: String?,
    keyword: String?,
    startDateMs: Long?,
    endDateMs: Long?,
    type: Int?,
  ): Pair<String?, Array<String>?> {
    val parts = mutableListOf<String>()
    val argList = mutableListOf<String>()

    if (!address.isNullOrEmpty()) {
      parts.add("${Telephony.Sms.ADDRESS}=?")
      argList.add(address)
    }

    if (!keyword.isNullOrEmpty()) {
      parts.add("(${Telephony.Sms.BODY} LIKE ? OR ${Telephony.Sms.ADDRESS} LIKE ?)")
      val like = "%$keyword%"
      argList.add(like)
      argList.add(like)
    }

    if (startDateMs != null) {
      parts.add("${Telephony.Sms.DATE} >= ?")
      argList.add(startDateMs.toString())
    }

    if (endDateMs != null) {
      parts.add("${Telephony.Sms.DATE} <= ?")
      argList.add(endDateMs.toString())
    }

    if (type != null && type > 0) {
      when (type) {
        // 2=仅已发送：契约「草稿归入发送侧」（filter_sheet.dart），Dart `SmsItem.kind`
        // 把 type!=1 全部归为非收件，下推保持一致（含 DRAFT/OUTBOX/FAILED/QUEUED）。
        2 -> {
          parts.add("${Telephony.Sms.TYPE}<>?")
          argList.add(Telephony.Sms.MESSAGE_TYPE_INBOX.toString())
        }
        else -> {
          parts.add("${Telephony.Sms.TYPE}=?")
          argList.add(type.toString())
        }
      }
    }

    return if (parts.isEmpty()) null to null
    else parts.joinToString(" AND ") to argList.toTypedArray()
  }

  private fun readRow(c: Cursor): Map<String, Any?> = smsAccess.readRow(c)
  private fun readMmsRow(c: Cursor): Map<String, Any?>? = smsAccess.readMmsRow(c)

  /**
   * 查询过程中的部分失败收集（按 code 去重）。
   *
   * message 一律使用固定文案（[messageOf]），**绝不**携带 exception.message /
   * URI / 文件路径，避免把 Provider 内部路径泄漏到线协议。
   */
  private class QueryWarns {
    private val codes = LinkedHashSet<String>()
    fun add(code: String) {
      codes.add(code)
    }

    fun isNotEmpty(): Boolean = codes.isNotEmpty()
    fun toWireList(): List<Map<String, Any?>> = codes.map { code ->
      mapOf(
        ChannelCodes.KEY_CODE to code,
        ChannelCodes.KEY_MESSAGE to messageOf(code),
      )
    }

    private fun messageOf(code: String): String = when (code) {
      ChannelCodes.WARN_SMS_URI_SECURITY -> "sms query restricted"
      ChannelCodes.WARN_SMS_URI_FAILED -> "sms query failed"
      ChannelCodes.WARN_MMS_URI_SECURITY -> "mms query restricted"
      ChannelCodes.WARN_MMS_URI_FAILED -> "mms query failed"
      ChannelCodes.WARN_MMS_ADDR_FAILED -> "mms address lookup failed"
      ChannelCodes.WARN_MMS_PART_FAILED -> "mms body lookup failed"
      else -> "query incomplete"
    }
  }

  /** 一条有序流的扫描结果。 */
  private class StreamScan(
    val rows: List<Map<String, Any?>>,
    val total: Int,
    val security: Boolean = false,
    val other: Boolean = false,
  ) {
    companion object {
      val EMPTY = StreamScan(emptyList(), 0)
    }
  }

  /** readRows 结果：可用行 + 游标是否出现过任意原始行（含无 _id 被丢弃的）。 */
  private class StreamRows(
    val rows: List<Map<String, Any?>>,
    val sawRow: Boolean,
  )

  /** 单表查询入口：URI 在调用点以平台类型直传 ContentResolver（见 querySms）。 */
  private fun interface TableQuery {
    fun query(
      projection: Array<String>,
      selection: String?,
      args: Array<String>?,
      sort: String?,
    ): Cursor?
  }

  /**
   * 扫一条有序流（SMS 或 MMS）。
   *
   * - **全量**（[unlimited]，`limit == null`）：读完整流，`total` = 可用行数。
   * - **分页**：先 count 拿 `total` 并判断整表是否为空；
   *   行只读前 `maxRows = offset+limit` 条。`LIMIT` 下推 sortOrder（Telephony 的 SQLite
   *   接受 `ORDER BY … LIMIT n`）；若 OEM 忽略 LIMIT，读取侧仍短路在 `maxRows`，
   *   不会全量物化。
   * - **多 URI**：仅当整表为空才回落 Inbox/Sent/Draft。见 [MMS_PROJECTION] 上方注释。
   */
  private fun scanStream(
    tableId: String,
    query: TableQuery,
    fallbacks: List<TableQuery>,
    projection: Array<String>,
    selection: String?,
    args: Array<String>?,
    maxRows: Int,
    unlimited: Boolean,
    read: (Cursor) -> Map<String, Any?>?,
    keepRow: ((Map<String, Any?>) -> Boolean)? = null,
  ): StreamScan {
    var security = false
    var other = false

    fun readRows(table: TableQuery, limit: Int, pushLimit: Boolean): StreamRows {
      val out = ArrayList<Map<String, Any?>>()
      if (limit <= 0) return StreamRows(out, sawRow = false)
      // keepRow 内存过滤时不能下推 LIMIT（会把命中行截断在过滤前），改纯短路扫描。
      val sort = if (pushLimit && limit != Int.MAX_VALUE) {
        "${SmsAccess.DATE_ID_SORT} LIMIT $limit"
      } else {
        SmsAccess.DATE_ID_SORT
      }
      var sawRow = false
      try {
        table.query(projection, selection, args, sort)?.use { c ->
          while (out.size < limit && c.moveToNext()) {
            sawRow = true
            val row = read(c) ?: continue
            if (row["_id"] == null) continue
            if (keepRow != null && !keepRow(row)) continue
            out.add(row)
          }
        }
      } catch (e: SecurityException) {
        security = true
      } catch (e: Exception) {
        other = true
        Log.e(SmsAccess.TAG, "query stream", e)
      }
      // Provider 已按 sortOrder（date DESC, _id DESC）返回有序数据；
      // 单流内 is_mms 值相同，无需再按 ROW_ORDER 重排。
      // 个别 ROM 不保证序时，mergeByDateDesc 仍按 ROW_ORDER 逐行比较兜底。
      return StreamRows(out, sawRow)
    }

    /**
     * keepRow 内存过滤时 selection 不含 id 条件，聚合 count 统计的是全表，
     * 必须逐行应用 keepRow 才能拿到过滤后 total（MMS id 过滤超 MMS_ID_IN_MAX 的稀有路径）。
     */
    fun countRowsFiltered(table: TableQuery): Int = try {
      var n = 0
      table.query(projection, selection, args, null)?.use { c ->
        while (c.moveToNext()) {
          val row = read(c) ?: continue
          if (row["_id"] == null) continue
          if (keepRow != null && !keepRow(row)) continue
          n++
        }
      }
      n
    } catch (e: SecurityException) {
      security = true
      -1
    } catch (e: Exception) {
      other = true
      Log.e(SmsAccess.TAG, "count stream filtered", e)
      -1
    }

    fun countRows(table: TableQuery, tableId: String): Int = try {
      // Cache key from generation + query parameters (selection + args) + table identifier
      val cacheKey = buildString {
        append(countCacheGen.get())
        append("|")
        append(tableId)
        append("|")
        append(selection ?: "")
        append("|")
        if (args != null) {
          for (a in args) append(a).append(",")
        }
      }
      val now = System.currentTimeMillis()
      val cached = countCache[cacheKey]
      if (cached != null && (now - cached.timestamp) < COUNT_CACHE_TTL_MS) {
        return cached.count
      }
      // 优先用 COUNT(*) 聚合投影：Provider 只需返回一行一列，避免为取行数
      // 把整张表灌进 CursorWindow（大库上每翻一页都白付一次全表游标）。
      // 个别 OEM Provider 不支持聚合投影（返回 null、列名不匹配或抛异常），
      // 此时回落到全投影方案（与行查询同 schema，单测可按列名区分 SMS/MMS）。
      try {
        val c = table.query(arrayOf("COUNT(*)"), selection, args, null)
        if (c != null) {
          val idx = c.getColumnIndex("COUNT(*)")
          if (idx >= 0) {
            val result = c.use {
              if (it.moveToFirst()) it.getInt(idx) else 0
            }
            countCache[cacheKey] = CountCacheEntry(result, now)
            return result
          }
          c.close()
        }
      } catch (e: Exception) {
        Log.w(SmsAccess.TAG, "COUNT(*) projection failed, falling back to full projection", e)
      }
      // 回落：全投影只取 .count。
      Log.w(SmsAccess.TAG, "countRows: using full-projection cursor fallback (slow path)")
      val c = table.query(projection, selection, args, null)
      // null 游标视作空表（0），不触发「未知 → 回落」；空表才会走子箱回落。
      val result = if (c == null) 0 else c.use { it.count }
      countCache[cacheKey] = CountCacheEntry(result, now)
      return result
    } catch (e: SecurityException) {
      security = true
      -1
    } catch (e: Exception) {
      other = true
      Log.e(SmsAccess.TAG, "count stream", e)
      -1
    }

    /** 仅当整表为空时回落子箱；子箱有序流归并去重（同 _id 只保留先到者）。 */
    fun fallback(): StreamScan {
      val streams = ArrayList<List<Map<String, Any?>>>(fallbacks.size)
      var total = 0
      for ((i, table) in fallbacks.withIndex()) {
        val n = if (keepRow != null) countRowsFiltered(table) else countRows(table, "$tableId:fallback:$i")
        if (n == 0) continue
        if (n > 0) total += n
        streams.add(readRows(table, maxRows, pushLimit = keepRow == null).rows)
      }
      val merged = LinkedHashMap<Int, Map<String, Any?>>()
      for (row in mergeByDateDesc(streams, maxRows)) {
        val id = row["_id"] as? Int ?: continue
        merged.putIfAbsent(id, row)
      }
      return StreamScan(merged.values.toList(), total, security, other)
    }

    if (unlimited) {
      val scanned = readRows(query, Int.MAX_VALUE, pushLimit = false)
      // 有原始行即止（含无 _id 被丢弃的——那不是「整表空」）；空才回落。
      if (scanned.sawRow || security) {
        return StreamScan(scanned.rows, scanned.rows.size, security, other)
      }
      return fallback()
    }

    val primaryCount = if (keepRow != null) countRowsFiltered(query) else countRows(query, tableId)
    if (primaryCount > 0) {
      return StreamScan(
        readRows(query, maxRows, pushLimit = keepRow == null).rows,
        primaryCount,
        security,
        other,
      )
    }
    if (primaryCount == 0) {
      // 整表空：回落子箱（历史 OEM 坑，见 FALLBACK_URIS 注释）。
      return fallback()
    }
    // count 失败（-1）：先试读本表，有行则用行数当 total；否则回落。
    val scanned = readRows(query, maxRows, pushLimit = keepRow == null)
    if (scanned.sawRow) {
      return StreamScan(scanned.rows, scanned.rows.size, security, other)
    }
    return fallback()
  }

  /**
   * 有序流归并（date 降序，null 最早；同 date 时 is_mms 降序 + _id 降序）。
   * 每个入参流必须已按同序排好；只产出前 [maxRows] 条。
   */
  private fun mergeByDateDesc(
    streams: List<List<Map<String, Any?>>>,
    maxRows: Int,
  ): List<Map<String, Any?>> {
    if (maxRows <= 0) return emptyList()
    val live = streams.filter { it.isNotEmpty() }
    if (live.isEmpty()) return emptyList()
    if (live.size == 1) return live[0].take(maxRows)
    val out = ArrayList<Map<String, Any?>>()
    val idx = IntArray(live.size)
    while (out.size < maxRows) {
      var bestStream = -1
      for (s in live.indices) {
        val i = idx[s]
        if (i >= live[s].size) continue
        if (bestStream < 0) {
          bestStream = s
          continue
        }
        if (SmsAccess.ROW_ORDER.compare(live[s][i], live[bestStream][idx[bestStream]]) < 0) {
          bestStream = s
        }
      }
      if (bestStream < 0) break
      out.add(live[bestStream][idx[bestStream]])
      idx[bestStream]++
    }
    return out
  }

  /**
   * 从 `content://mms/addr` 取匹配号码的 msg_id 集合。
   * 失败回空集（宁可少显示彩信，也不误含无关行），并记 [ChannelCodes.WARN_MMS_ADDR_FAILED]。
   */
  private fun queryMmsIdsByAddress(address: String, warns: QueryWarns): Set<Int> = try {
    val ids = mutableSetOf<Int>()
    context.contentResolver.query(
      SmsAccess.mmsAddrUri(),
      arrayOf(Telephony.Mms.Addr.MSG_ID),
      "${Telephony.Mms.Addr.ADDRESS}=?",
      arrayOf(address),
      null,
    )?.use { c ->
      while (c.moveToNext()) {
        val i = c.getColumnIndex(Telephony.Mms.Addr.MSG_ID)
        if (i >= 0 && !c.isNull(i)) ids.add(c.getInt(i))
      }
    }
    ids
  } catch (e: Exception) {
    Log.e(SmsAccess.TAG, "queryMmsIdsByAddress", e)
    warns.add(ChannelCodes.WARN_MMS_ADDR_FAILED)
    emptySet()
  }

  /**
   * 从 `content://mms/part` 取正文匹配关键词的 mid 集合。
   * MMS 正文存储在 part 表而非 mms 表，无法直接在 mms 查询中下推 keyword。
   * 失败回空集并记 warning。
   */
  private fun queryMmsIdsByKeyword(keyword: String, warns: QueryWarns): Set<Int> = try {
    val ids = mutableSetOf<Int>()
    context.contentResolver.query(
      SmsAccess.mmsPartUri(),
      arrayOf(Telephony.Mms.Part.MSG_ID),
      "${Telephony.Mms.Part.TEXT} LIKE ?",
      arrayOf("%$keyword%"),
      null,
    )?.use { c ->
      while (c.moveToNext()) {
        val i = c.getColumnIndex(Telephony.Mms.Part.MSG_ID)
        if (i >= 0 && !c.isNull(i)) ids.add(c.getInt(i))
      }
    }
    ids
  } catch (e: Exception) {
    Log.e(SmsAccess.TAG, "queryMmsIdsByKeyword", e)
    warns.add(ChannelCodes.WARN_MMS_PART_FAILED)
    emptySet()
  }

  /**
   * 给本页彩信补 address / body 摘要 / has_media。
   * addr + part 各一次批量查询（`IN` 分片），不是逐条 N+1。
   * 单路失败记 warning，不阻断另一路；失败字段按空串/无媒体回落。
   */
  private fun enrichMmsRows(
    page: List<Map<String, Any?>>,
    warns: QueryWarns,
  ): List<Map<String, Any?>> {
    val mmsIds = page.mapNotNull { row ->
      if (smsAccess.isMmsFlag(row["is_mms"])) row["_id"] as? Int else null
    }
    if (mmsIds.isEmpty()) return page
    val addrs = queryMmsAddresses(mmsIds, warns)
    val bodies = queryMmsBodies(mmsIds, warns)
    return page.map { row ->
      if (!smsAccess.isMmsFlag(row["is_mms"])) row
      else {
        val id = row["_id"] as? Int
        val bodyInfo = id?.let { bodies[it] }
        row + mapOf(
          "address" to (id?.let { addrs[it] } ?: ""),
          "body" to (bodyInfo?.first ?: ""),
          "has_media" to (if (bodyInfo?.second == true) 1 else 0),
        )
      }
    }
  }

  /**
   * msg_id → 对端号码。收件优先 FROM(137)，否则 TO(151)，再否则首个非空。
   * 失败记 [ChannelCodes.WARN_MMS_ADDR_FAILED]，该路返回空映射。
   */
  private fun queryMmsAddresses(ids: List<Int>, warns: QueryWarns): Map<Int, String> {
    val best = mutableMapOf<Int, Pair<Int, String>>() // msgId -> (priority, address)
    fun priorityOf(type: Int): Int = when (type) {
      SmsAccess.MMS_ADDR_TYPE_FROM -> 0
      SmsAccess.MMS_ADDR_TYPE_TO -> 1
      else -> 2
    }
    forChunked(ids) { chunk ->
      try {
        context.contentResolver.query(
          SmsAccess.mmsAddrUri(),
          arrayOf(
            Telephony.Mms.Addr.MSG_ID,
            Telephony.Mms.Addr.ADDRESS,
            Telephony.Mms.Addr.TYPE,
          ),
          "msg_id IN (${chunk.joinToString(",") { "?" }})",
          chunk.map { it.toString() }.toTypedArray(),
          null,
        )?.use { c ->
          val idCol = c.getColumnIndex(Telephony.Mms.Addr.MSG_ID)
          val addrCol = c.getColumnIndex(Telephony.Mms.Addr.ADDRESS)
          val typeCol = c.getColumnIndex(Telephony.Mms.Addr.TYPE)
          while (c.moveToNext()) {
            if (idCol < 0 || c.isNull(idCol)) continue
            val msgId = c.getInt(idCol)
            val addr = if (addrCol >= 0 && !c.isNull(addrCol)) c.getString(addrCol) else continue
            if (addr.isEmpty()) continue
            val type = if (typeCol >= 0 && !c.isNull(typeCol)) c.getInt(typeCol) else 0
            val p = priorityOf(type)
            val cur = best[msgId]
            if (cur == null || p < cur.first) best[msgId] = p to addr
          }
        }
      } catch (e: Exception) {
        Log.e(SmsAccess.TAG, "queryMmsAddresses", e)
        warns.add(ChannelCodes.WARN_MMS_ADDR_FAILED)
      }
    }
    return best.mapValues { it.value.second }
  }

  /**
   * msg_id → (文本摘要, 是否含媒体附件)。
   * 文本取 `ct` 为 text/plain · text/x-vcard · text/x-vcalendar · text/html 的 part 的 `text` 列拼接；
   * 媒体看 image/ · audio/ · video/ 或带 `_data` 的 application/ 任意类型。
   * 失败记 [ChannelCodes.WARN_MMS_PART_FAILED]，该路按空摘要回落。
   */
  private fun queryMmsBodies(ids: List<Int>, warns: QueryWarns): Map<Int, Pair<String, Boolean>> {
    val texts = mutableMapOf<Int, MutableList<String>>()
    val media = mutableSetOf<Int>()
    forChunked(ids) { chunk ->
      try {
        context.contentResolver.query(
          SmsAccess.mmsPartUri(),
          arrayOf(
            Telephony.Mms.Part.MSG_ID,
            Telephony.Mms.Part.CONTENT_TYPE,
            SmsAccess.PART_TEXT_COLUMN,
            Telephony.Mms.Part._DATA,
          ),
          "mid IN (${chunk.joinToString(",") { "?" }})",
          chunk.map { it.toString() }.toTypedArray(),
          null,
        )?.use { c ->
          val midCol = c.getColumnIndex(Telephony.Mms.Part.MSG_ID)
          val ctCol = c.getColumnIndex(Telephony.Mms.Part.CONTENT_TYPE)
          val textCol = c.getColumnIndex(SmsAccess.PART_TEXT_COLUMN)
          val dataCol = c.getColumnIndex(Telephony.Mms.Part._DATA)
          while (c.moveToNext()) {
            if (midCol < 0 || c.isNull(midCol)) continue
            val mid = c.getInt(midCol)
            val ct = (if (ctCol >= 0 && !c.isNull(ctCol)) c.getString(ctCol) else null)
              ?.lowercase().orEmpty()
            when {
              ct in SmsAccess.TEXT_PART_CTS -> {
                val text = if (textCol >= 0 && !c.isNull(textCol)) c.getString(textCol) else null
                if (!text.isNullOrEmpty()) {
                  texts.getOrPut(mid) { mutableListOf() }.add(text)
                }
              }
              ct.startsWith("image/") ||
                ct.startsWith("audio/") ||
                ct.startsWith("video/") -> media.add(mid)
              ct.startsWith("application/") &&
                ct != "application/smil" &&
                dataCol >= 0 &&
                !c.isNull(dataCol) -> media.add(mid)
            }
          }
        }
      } catch (e: Exception) {
        Log.e(SmsAccess.TAG, "queryMmsBodies", e)
        warns.add(ChannelCodes.WARN_MMS_PART_FAILED)
      }
    }
    return ids.associateWith { id ->
      (texts[id]?.joinToString("\n").orEmpty()) to (id in media)
    }
  }

  private inline fun forChunked(ids: List<Int>, block: (List<Int>) -> Unit) {
    ids.chunked(900).forEach(block)
  }
}
