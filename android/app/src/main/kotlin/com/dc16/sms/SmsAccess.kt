package com.dc16.sms

import android.app.Activity
import android.app.AppOpsManager
import android.app.role.RoleManager
import android.content.Context
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.os.Process
import android.provider.BaseColumns
import android.provider.Settings
import android.provider.Telephony
import android.util.Log

/**
 * 短信读取 / 默认角色 / 查询 / 删除。minSdk 29，只走 RoleManager。
 *
 * 门面类：对外 API 不变，内部委托给 [SmsQuery]、[SmsWrite]、[MiuiSupport]。
 */
class SmsAccess(val context: Context) {

  private val appOps: AppOpsManager
    get() = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager

  private val query = SmsQuery(this)
  private val write = SmsWrite(this)
  private val miui = MiuiSupport(context)

  /** checkSelf + AppOps，避免掉默认后假授权。 */
  fun hasReadSms(): Boolean {
    if (context.checkSelfPermission(android.Manifest.permission.READ_SMS)
      != android.content.pm.PackageManager.PERMISSION_GRANTED
    ) return false
    return try {
      // checkOpNoThrow：API 36+ 仍可用且未废弃；unsafeCheckOpNoThrow 已废弃。
      appOps.checkOpNoThrow(
        AppOpsManager.OPSTR_READ_SMS, Process.myUid(), context.packageName,
      ) == AppOpsManager.MODE_ALLOWED
    } catch (_: Exception) {
      true
    }
  }

  fun isDefaultSms(): Boolean? = try {
    val rm = context.getSystemService(RoleManager::class.java)
    when {
      rm == null -> Telephony.Sms.getDefaultSmsPackage(context) == context.packageName
      rm.isRoleAvailable(RoleManager.ROLE_SMS) -> rm.isRoleHeld(RoleManager.ROLE_SMS)
      else -> Telephony.Sms.getDefaultSmsPackage(context) == context.packageName
    }
  } catch (_: Exception) {
    null
  }

  /**
   * 统一「设为默认短信」唯一路径（MainActivity 只负责 launcher / pending 收尾）。
   *
   * 已是默认 → `had`；否则交给 [requestRole] 发起角色申请。挂起成功返回 `null`，
   * 最终 `had`/`no` 由系统回调补完；未能挂起 / 不可用 → 打开系统默认应用页并回 `no`。
   *
   * @param requestRole 发起角色申请（for-result）。`true`=已挂起；`false`=未能挂起。
   * @return `null`=已挂起等系统回调，调用方勿再回包；非 null=立即完成的线值（见 [ChannelCodes]）。
   */
  fun setDefaultSms(
    activity: Activity,
    requestRole: (Intent) -> Boolean,
  ): String? {
    if (isDefaultSms() == true) return ChannelCodes.SET_DEFAULT_HAD
    return try {
      val rm = context.getSystemService(RoleManager::class.java)
      val intent =
        if (rm != null && rm.isRoleAvailable(RoleManager.ROLE_SMS)) {
          rm.createRequestRoleIntent(RoleManager.ROLE_SMS)
        } else {
          null
        }
      if (intent != null && requestRole(intent)) {
        null
      } else {
        openDefaultSmsSettings(activity)
        ChannelCodes.SET_DEFAULT_NO
      }
    } catch (e: Exception) {
      Log.e(TAG, "setDefaultSms", e)
      openDefaultSmsSettings(activity)
      ChannelCodes.SET_DEFAULT_NO
    }
  }

  fun openDefaultSmsSettings(activity: Activity): Boolean = try {
    activity.startActivity(Intent(Settings.ACTION_MANAGE_DEFAULT_APPS_SETTINGS))
    true
  } catch (_: Exception) {
    false
  }

  /** 打开本应用的系统设置页（权限被长期拒绝时手动开启）。 */
  fun openAppSettings(activity: Activity): Boolean = try {
    activity.startActivity(
      Intent(
        Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
        android.net.Uri.fromParts("package", context.packageName, null),
      ),
    )
    true
  } catch (_: Exception) {
    false
  }

  // ---- MIUI (delegated) ----

  fun isMiui(): Boolean = miui.isMiui()

  fun miuiNotificationSmsState(): String = miui.miuiNotificationSmsState()

  @androidx.annotation.VisibleForTesting
  internal fun looksLikeServiceAddress(addr: String): Boolean = miui.looksLikeServiceAddress(addr)

  fun openMiuiPermissionEditor(activity: Activity): Boolean =
    miui.openMiuiPermissionEditor(activity) { openAppSettings(activity) }

  // ---- Test SMS (delegated) ----

  fun insertTestSms(count: Int, bodyPrefix: String): List<Int>? = write.insertTestSms(count, bodyPrefix)

  fun deleteTestSmsByPrefix(bodyPrefix: String): Int? = write.deleteTestSmsByPrefix(bodyPrefix)

  fun filterTestIds(ids: List<Int>, bodyPrefix: String): List<Int> = write.filterTestIds(ids, bodyPrefix)

  fun restoreDefaultSms(activity: Activity): String = try {
    if (isDefaultSms() != true) return ChannelCodes.RESTORE_NOT_DEFAULT
    activity.startActivity(Intent(Settings.ACTION_MANAGE_DEFAULT_APPS_SETTINGS))
    ChannelCodes.RESTORE_SETTINGS
  } catch (e: Exception) {
    Log.e(TAG, "restoreDefaultSms", e)
    ChannelCodes.ERROR
  }

  // ---- Query (delegated) ----

  fun querySms(
    address: String?,
    limit: Int? = null,
    offset: Int = 0,
    keyword: String? = null,
    startDateMs: Long? = null,
    endDateMs: Long? = null,
    type: Int? = null,
  ): Map<String, Any?> = query.querySms(address, limit, offset, keyword, startDateMs, endDateMs, type)

  // ---- Delete / Insert (delegated) ----

  fun deleteSmsBatch(targets: List<Any?>): Map<String, Any?> = write.deleteSmsBatch(targets)

  fun insertSmsBatch(rows: List<Any?>): Map<String, Any?> = write.insertSmsBatch(rows)

  /** 数据变更后调用，清空分页计数缓存。 */
  fun clearCountCache() = query.clearCountCache()

  // ---- MMS insert (delegated) ----

  @androidx.annotation.VisibleForTesting
  internal fun insertMmsNotification(
    n: MmsPduParser.MmsNotification,
    subId: Int?,
  ): Int? = write.insertMmsNotification(n, subId)

  // ---- Row readers (kept here for tests) ----

  @androidx.annotation.VisibleForTesting
  internal fun readRow(c: Cursor): Map<String, Any?> {
    fun col(n: String) = c.getColumnIndex(n)
    fun long(i: Int): Long? = if (i >= 0 && !c.isNull(i)) c.getLong(i) else null
    fun int(i: Int): Int? = if (i >= 0 && !c.isNull(i)) c.getInt(i) else null
    fun str(i: Int): String? = if (i >= 0 && !c.isNull(i)) c.getString(i) else null
    return mapOf(
      "_id" to long(col(BaseColumns._ID))?.toInt(),
      "thread_id" to long(col(Telephony.Sms.THREAD_ID))?.toInt(),
      "address" to str(col(Telephony.Sms.ADDRESS)),
      "body" to str(col(Telephony.Sms.BODY)),
      "date" to long(col(Telephony.Sms.DATE)),
      "date_sent" to long(col(Telephony.Sms.DATE_SENT)),
      "read" to int(col(Telephony.Sms.READ)),
      "type" to int(col(Telephony.Sms.TYPE)),
      "sub_id" to int(col(Telephony.Sms.SUBSCRIPTION_ID)),
      "is_mms" to 0,
    )
  }

  /**
   * 彩信元数据行（`content://mms`）。
   *
   * 无 `msg_box` 列时视为非彩信 schema（如测试里误喂的 SMS Cursor）返回 null，避免污染合并结果。
   * `date` 在彩信表是**秒**，统一换算成毫秒与 SMS 对齐。
   */
  @androidx.annotation.VisibleForTesting
  internal fun readMmsRow(c: Cursor): Map<String, Any?>? {
    fun col(n: String) = c.getColumnIndex(n)
    if (col(Telephony.Mms.MESSAGE_BOX) < 0) return null
    fun long(i: Int): Long? = if (i >= 0 && !c.isNull(i)) c.getLong(i) else null
    fun int(i: Int): Int? = if (i >= 0 && !c.isNull(i)) c.getInt(i) else null
    return mapOf(
      "_id" to long(col(BaseColumns._ID))?.toInt(),
      "thread_id" to long(col(Telephony.Mms.THREAD_ID))?.toInt(),
      "address" to null, // 彩信 address 在 addr 表，页面级补全
      "body" to null, // 同上，part 表补全
      "date" to mmsDateToMs(long(col(Telephony.Mms.DATE))),
      "date_sent" to mmsDateToMs(long(col(Telephony.Mms.DATE_SENT))),
      "read" to int(col(Telephony.Mms.READ)),
      // msg_box 取值与 SMS type 同构：1 inbox / 2 sent / 3 draft / 4 outbox / 5 failed
      "type" to int(col(Telephony.Mms.MESSAGE_BOX)),
      "sub_id" to int(col(Telephony.Mms.SUBSCRIPTION_ID)),
      "is_mms" to 1,
    )
  }

  /** 彩信 `date` 是秒；小于 1e11 视为秒并放大到毫秒，否则原样保留（个别 ROM 直接给毫秒）。 */
  @androidx.annotation.VisibleForTesting
  internal fun mmsDateToMs(secOrMs: Long?): Long? =
    secOrMs?.let { if (it < 100_000_000_000L) it * 1000 else it }

  // ---- Delete target splitting (kept here for tests) ----

  /** 删除目标：保留入参下标，便于 errors[].index 对齐 `{id,is_mms}` 载荷。 */
  internal data class DeleteTarget(val index: Int, val id: Int, val isMms: Boolean)

  /** 把混合入参拆成 SMS / MMS 两组目标（含入参下标）。未知形态直接丢弃，绝不猜测路由。 */
  @androidx.annotation.VisibleForTesting
  internal fun splitDeleteTargets(
    targets: List<Any?>,
  ): Pair<List<DeleteTarget>, List<DeleteTarget>> {
    val sms = mutableListOf<DeleteTarget>()
    val mms = mutableListOf<DeleteTarget>()
    targets.forEachIndexed { i, t ->
      when (t) {
        is Number -> sms.add(DeleteTarget(i, t.toInt(), isMms = false))
        is Map<*, *> -> {
          val id = (t["id"] as? Number)?.toInt() ?: return@forEachIndexed
          val isMms = isMmsFlag(t["is_mms"])
          (if (isMms) mms else sms).add(DeleteTarget(i, id, isMms))
        }
      }
    }
    return sms to mms
  }

  /** `is_mms` 线值：1 / true 视为彩信；0 / false / 缺失视为短信。 */
  @androidx.annotation.VisibleForTesting
  internal fun isMmsFlag(v: Any?): Boolean =
    v == true || (v as? Number)?.toInt() == 1

  companion object {
    const val TAG = "SmsAccess"

    internal val PROJECTION = arrayOf(
      BaseColumns._ID,
      Telephony.Sms.THREAD_ID,
      Telephony.Sms.ADDRESS,
      Telephony.Sms.BODY,
      Telephony.Sms.DATE,
      Telephony.Sms.DATE_SENT,
      Telephony.Sms.READ,
      Telephony.Sms.TYPE,
      Telephony.Sms.SUBSCRIPTION_ID,
    )

    /**
     * 多 URI 回落策略（历史原因，git `8aa3f62` 修「掉默认后空列表」）：
     * 部分 OEM（HyperOS/MIUI）在**非默认短信应用**下对 `content://sms` 整表返回空游标，
     * 而 `content://sms/inbox|sent|draft` 在仅有 READ_SMS 时仍可读。
     * AOSP 上整表已是并集，同批数据再查 4 个 URI 纯属重复扫描，因此：
     * **先查整表，仅当结果为空才回落子箱**（子箱互斥，归并后按 `_id` 去重）。
     * 回落不含 outbox/failed（那些只在整表可见；整表空时通常也读不到）。
     * 彩信（`content://mms`）同策略，见 querySms 内 fallbacks lambda。
     */
    internal val MMS_PROJECTION = arrayOf(
      BaseColumns._ID,
      Telephony.Mms.THREAD_ID,
      Telephony.Mms.DATE,
      Telephony.Mms.DATE_SENT,
      Telephony.Mms.READ,
      Telephony.Mms.MESSAGE_BOX,
      Telephony.Mms.SUBSCRIPTION_ID,
    )

    /** Provider 排序：date 降序（null 最早由归并比较器兜底）+ _id 降序稳定次键。 */
    internal val DATE_ID_SORT = "${Telephony.Sms.DATE} DESC, ${BaseColumns._ID} DESC"

    /** `_id IN (...)` 下推上限，与删除分片一致（SQLite 变量数留余量）。 */
    internal const val MMS_ID_IN_MAX = 900

    /** 全局定序：date 降序（null 最早）→ is_mms 降序 → _id 降序，与 Dart `uid` 序一致。 */
    internal val ROW_ORDER =
      compareByDescending<Map<String, Any?>> { (it["date"] as? Number)?.toLong() ?: Long.MIN_VALUE }
        .thenByDescending { (it["is_mms"] as? Number)?.toInt() ?: 0 }
        .thenByDescending { (it["_id"] as? Number)?.toInt() ?: 0 }

    /** part 表文本列：公开 API 无常量，provider 列名就是 `text`。 */
    internal const val PART_TEXT_COLUMN = "text"

    /**
     * `content://mms/addr` / `content://mms/part`：`Telephony.Mms.Addr` / `Part`
     * 未暴露 CONTENT_URI 常量，只能字面量构造。
     * 返回平台类型（可为 null）：JVM 桩里 `Uri.parse` 不可用，回落 `Telephony.Mms.CONTENT_URI`
     * （同样为 null）；与 SMS 路径一致，mock resolver 不关心 URI 值。
     */
    internal fun mmsAddrUri() = try {
      Uri.parse("content://mms/addr")
    } catch (_: Exception) {
      Telephony.Mms.CONTENT_URI
    }

    internal fun mmsPartUri() = try {
      Uri.parse("content://mms/part")
    } catch (_: Exception) {
      Telephony.Mms.CONTENT_URI
    }

    /** addr.type：137=FROM（收件对端），151=TO（发件对端）。公开 API 无具名常量。 */
    internal const val MMS_ADDR_TYPE_FROM = 137
    internal const val MMS_ADDR_TYPE_TO = 151

    /** 可拼进正文摘要的文本 part 类型。 */
    internal val TEXT_PART_CTS = setOf(
      "text/plain",
      "text/x-vcard",
      "text/x-vcalendar",
      "text/html",
    )

    /** 供 Receiver 写入新短信。 */
    fun insertInbox(context: Context, address: String?, body: String?, date: Long): Boolean =
      try {
        val v = android.content.ContentValues().apply {
          put(Telephony.Sms.ADDRESS, address)
          put(Telephony.Sms.BODY, body)
          put(Telephony.Sms.DATE, date)
          put(Telephony.Sms.DATE_SENT, date)
          put(Telephony.Sms.READ, 0)
          put(Telephony.Sms.SEEN, 0)
          put(Telephony.Sms.TYPE, Telephony.Sms.MESSAGE_TYPE_INBOX)
        }
        context.contentResolver.insert(Telephony.Sms.Inbox.CONTENT_URI, v) != null
      } catch (e: Exception) {
        Log.e(TAG, "insertInbox", e)
        false
      }
  }
}
