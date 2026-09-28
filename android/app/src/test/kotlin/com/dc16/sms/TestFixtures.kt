package com.dc16.sms

import android.app.role.RoleManager
import android.content.ContentResolver
import android.content.Context
import android.content.pm.ApplicationInfo
import org.mockito.kotlin.anyOrNull
import org.mockito.kotlin.mock
import org.mockito.kotlin.whenever

/**
 * 构造 [SmsAccess] 测试用的 Mock [Context]。
 *
 * - `defaultSms`：RoleManager.isRoleHeld(ROLE_SMS)
 * - `debuggable`：ApplicationInfo.FLAG_DEBUGGABLE
 * - 未 stub 的 AppOps 会走 [SmsAccess.hasReadSms] 的 catch 分支返回 true（与真机
 *   “AppOps 不可用时假定已授权”一致）；需要精确控制读权限时再补 stub。
 */
internal fun mockSmsContext(
  resolver: ContentResolver,
  defaultSms: Boolean = true,
  debuggable: Boolean = true,
  packageName: String = "com.dc16.sms",
): Context {
  val ctx = mock<Context>()
  val appInfo = ApplicationInfo().apply {
    flags = if (debuggable) ApplicationInfo.FLAG_DEBUGGABLE else 0
  }
  whenever(ctx.applicationInfo).thenReturn(appInfo)
  whenever(ctx.packageName).thenReturn(packageName)
  whenever(ctx.contentResolver).thenReturn(resolver)

  val roleManager = mock<RoleManager>()
  whenever(ctx.getSystemService(RoleManager::class.java)).thenReturn(roleManager)
  whenever(roleManager.isRoleAvailable(RoleManager.ROLE_SMS)).thenReturn(true)
  whenever(roleManager.isRoleHeld(RoleManager.ROLE_SMS)).thenReturn(defaultSms)
  return ctx
}

/** 一行短信的标准列（与 [SmsAccess] PROJECTION 顺序一致，按名取用即可）。 */
internal fun smsRow(
  id: Int,
  threadId: Int = 1,
  address: String? = "10086",
  body: String? = "hello",
  date: Long? = 1_700_000_000_000L + id,
  dateSent: Long? = date,
  read: Int? = 1,
  type: Int? = 1,
  subId: Int? = 1,
): List<Any?> = listOf(id.toLong(), threadId.toLong(), address, body, date, dateSent, read, type, subId)

internal val SMS_CURSOR_COLUMNS = listOf(
  "_id", "thread_id", "address", "body", "date", "date_sent", "read", "type", "sub_id",
)

internal fun smsCursor(vararg rows: List<Any?>): FakeCursor =
  FakeCursor(SMS_CURSOR_COLUMNS, rows.toList())

/** 彩信元数据行（`content://mms` 投影）。date 传**秒**（与真机一致）。 */
internal fun mmsRow(
  id: Int,
  threadId: Int = 1,
  dateSec: Long? = 1_700_000_000L + id,
  dateSentSec: Long? = dateSec,
  read: Int? = 1,
  msgBox: Int? = 1,
  subId: Int? = 1,
): List<Any?> = listOf(id.toLong(), threadId.toLong(), dateSec, dateSentSec, read, msgBox, subId)

internal val MMS_CURSOR_COLUMNS = listOf(
  "_id", "thread_id", "date", "date_sent", "read", "msg_box", "sub_id",
)

internal fun mmsCursor(vararg rows: List<Any?>): FakeCursor =
  FakeCursor(MMS_CURSOR_COLUMNS, rows.toList())

/** addr 表行：msg_id, address, type。 */
internal val MMS_ADDR_COLUMNS = listOf("msg_id", "address", "type")

internal fun mmsAddrCursor(vararg rows: List<Any?>): FakeCursor =
  FakeCursor(MMS_ADDR_COLUMNS, rows.toList())

/** part 表行：mid, ct, text, _data。 */
internal val MMS_PART_COLUMNS = listOf("mid", "ct", "text", "_data")

internal fun mmsPartCursor(vararg rows: List<Any?>): FakeCursor =
  FakeCursor(MMS_PART_COLUMNS, rows.toList())

/** 捕获 ContentResolver.delete 的 selectionArgs，便于断言 chunk 边界。 */
internal fun stubDeleteCounting(resolver: ContentResolver): MutableList<List<String>> {
  val chunks = mutableListOf<List<String>>()
  // URI 参数在 JVM 单测下是 null（android.jar 桩不初始化 Telephony.Sms.CONTENT_URI），
  // 必须用 anyOrNull() 而不是 any()。
  whenever(resolver.delete(anyOrNull(), anyOrNull(), anyOrNull())).thenAnswer { inv ->
    val args = inv.getArgument<Array<String>?>(2)?.toList().orEmpty()
    chunks.add(args)
    args.size
  }
  return chunks
}

/**
 * SMS/MMS Provider 替身（整表有数据的主路径）。
 *
 * JVM 桩里 `Telephony.*.CONTENT_URI == null`，无法靠 URI 区分整表/子箱。
 * **主路径**（整表非空）下 `scanStream` 只会查整表：count（sort=null）与 rows（带 ORDER BY）
 * 都回同一张表的 Cursor——`.count` 即 total，短路读取即分页。
 *
 * 行数据请按 **Provider 顺序**（date DESC, _id DESC）放入；全量路径会再定序兜底。
 * 子箱回落请用 [stubEmptyPrimaryThenBoxes]。
 */
internal class SmsProviderStub {
  var sms: List<List<Any?>> = emptyList()
  var mms: List<List<Any?>> = emptyList()
  var mmsAddrIds: List<List<Any?>> = emptyList()
  var mmsAddr: List<List<Any?>> = emptyList()
  var mmsPart: List<List<Any?>> = emptyList()

  /**
   * 每次 query 之前的钩子：返回 null 走默认 stub 行为；抛异常则该次查询失败。
   * 用于精确模拟「一路成功、一路 SecurityException」等部分失败场景。
   */
  var onQuery: ((org.mockito.invocation.InvocationOnMock) -> Unit?)? = null

  data class QueryCall(
    val kind: String, // sms | mms | addr | addrIds | part
    val isCount: Boolean,
    val sort: String?,
    val selection: String?,
    val args: List<String?>? = null,
  )

  val queryLog = mutableListOf<QueryCall>()

  fun install(resolver: ContentResolver) {
    whenever(resolver.query(anyOrNull(), anyOrNull(), anyOrNull(), anyOrNull(), anyOrNull()))
      .thenAnswer { inv ->
        onQuery?.invoke(inv)
        val proj = inv.getArgument<Array<String>?>(1)?.toList()
        val selection = inv.getArgument<String?>(2)
        val args = inv.getArgument<Array<String>?>(3)?.toList()
        val sort = inv.getArgument<String?>(4)
        when {
          proj != null && proj.size == 1 && proj[0] == "msg_id" -> {
            queryLog += QueryCall("addrIds", false, sort, selection, args)
            rowsCursor(MMS_ADDR_COLUMNS, mmsAddrIds)
          }
          proj != null && proj.contains("msg_id") && proj.contains("address") -> {
            // enrich：msg_id, address, type
            queryLog += QueryCall("addr", false, sort, selection, args)
            rowsCursor(MMS_ADDR_COLUMNS, mmsAddr)
          }
          proj != null && proj.contains("mid") -> {
            queryLog += QueryCall("part", false, sort, selection, args)
            rowsCursor(MMS_PART_COLUMNS, mmsPart)
          }
          proj != null && proj.contains("msg_box") -> {
            queryLog += QueryCall("mms", sort == null, sort, selection, args)
            rowsCursor(MMS_CURSOR_COLUMNS, mms)
          }
          proj != null && proj.contains("body") -> {
            queryLog += QueryCall("sms", sort == null, sort, selection, args)
            rowsCursor(SMS_CURSOR_COLUMNS, sms)
          }
          else -> null
        }
      }
  }
}

/**
 * 整表为空、数据落在 inbox/sent/draft 的回落场景。
 *
 * 调用序（每条流）：`count(整表)=0` → `(count box → rows box)*`；
 * 全量时则是 `rows(整表)=空` → `(count box → rows box)*`。
 * 用计数器区分第 1 次（整表）与后续（子箱，按 inbox→sent→draft）。
 */
internal fun stubEmptyPrimaryThenBoxes(
  resolver: ContentResolver,
  smsInbox: List<List<Any?>> = emptyList(),
  smsSent: List<List<Any?>> = emptyList(),
  smsDraft: List<List<Any?>> = emptyList(),
  mmsInbox: List<List<Any?>> = emptyList(),
  mmsSent: List<List<Any?>> = emptyList(),
  mmsDraft: List<List<Any?>> = emptyList(),
  smsProjectionHasBody: Boolean = true,
) {
  val smsBoxes = listOf(smsInbox, smsSent, smsDraft)
  val mmsBoxes = listOf(mmsInbox, mmsSent, mmsDraft)
  var smsIdx = 0 // 下一子箱下标（rows 取走后 +1；count 与 rows 共用当前箱）
  var mmsIdx = 0
  var smsSawPrimary = false
  var mmsSawPrimary = false

  fun next(
    boxes: List<List<List<Any?>>>,
    columns: List<String>,
    isCount: Boolean,
    sawPrimary: () -> Boolean,
    markPrimary: () -> Unit,
    idx: () -> Int,
    bump: () -> Unit,
  ): FakeCursor {
    if (!sawPrimary()) {
      markPrimary()
      // 整表：count 回 0 行 / rows 回空游标
      return rowsCursor(columns, emptyList())
    }
    val rows: List<List<Any?>> = boxes.getOrElse(idx()) { emptyList() }
    if (isCount) {
      // 子箱 count：与下一次 rows 同一箱。不 bump（rows 时再 bump）。
      return rowsCursor(columns, rows)
    }
    bump()
    return rowsCursor(columns, rows)
  }

  whenever(resolver.query(anyOrNull(), anyOrNull(), anyOrNull(), anyOrNull(), anyOrNull()))
    .thenAnswer { inv ->
      val proj = inv.getArgument<Array<String>?>(1)?.toList()
      val sort = inv.getArgument<String?>(4)
      val isCount = sort == null
      when {
        proj != null && proj.contains("body") -> next(
          smsBoxes, SMS_CURSOR_COLUMNS, isCount,
          { smsSawPrimary }, { smsSawPrimary = true },
          { smsIdx }, { smsIdx++ },
        )
        proj != null && proj.contains("msg_box") -> next(
          mmsBoxes, MMS_CURSOR_COLUMNS, isCount,
          { mmsSawPrimary }, { mmsSawPrimary = true },
          { mmsIdx }, { mmsIdx++ },
        )
        else -> null
      }
    }
}

private fun rowsCursor(columns: List<String>, rows: List<List<Any?>>): FakeCursor =
  FakeCursor(columns, rows)
