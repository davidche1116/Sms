package com.davidche1116.sms

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
  packageName: String = "com.davidche1116.sms",
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
