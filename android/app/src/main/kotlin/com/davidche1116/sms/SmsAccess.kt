package com.davidche1116.sms

import android.app.Activity
import android.app.AppOpsManager
import android.app.role.RoleManager
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.os.Process
import android.provider.BaseColumns
import android.provider.Settings
import android.provider.Telephony
import android.util.Log

/** 短信读取 / 默认角色 / 查询 / 删除。minSdk 29，只走 RoleManager。 */
class SmsAccess(private val context: Context) {

  private val appOps: AppOpsManager
    get() = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager

  /** checkSelf + AppOps，避免掉默认后假授权。 */
  fun hasReadSms(): Boolean {
    if (context.checkSelfPermission(android.Manifest.permission.READ_SMS)
      != android.content.pm.PackageManager.PERMISSION_GRANTED
    ) return false
    return try {
      appOps.unsafeCheckOpNoThrow(
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

  /** had | no | error（见 [ChannelCodes]） */
  fun setDefaultSms(activity: Activity): String = try {
    val rm = context.getSystemService(RoleManager::class.java)
    if (isDefaultSms() == true) return ChannelCodes.SET_DEFAULT_HAD
    val intent = rm?.createRequestRoleIntent(RoleManager.ROLE_SMS)
    if (intent != null) {
      activity.startActivity(intent)
      ChannelCodes.SET_DEFAULT_NO
    } else ChannelCodes.ERROR
  } catch (e: Exception) {
    Log.e(TAG, "setDefaultSms", e)
    ChannelCodes.ERROR
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

  /** 是否 MIUI（ro.miui.ui.version.name 非空）。 */
  fun isMiui(): Boolean = try {
    val cl = Class.forName("android.os.SystemProperties")
    val get = cl.getMethod("get", String::class.java)
    (get.invoke(null, "ro.miui.ui.version.name") as? String)?.isNotEmpty() == true
  } catch (_: Exception) {
    false
  }

  /**
   * MIUI「通知类短信」状态。
   * @return "allow" / "likely_off" / "unknown"（见 [ChannelCodes]）
   *
   * MIUI 私有开关，标准 AppOps 字符串多半不存在；结合两路信号：
   *  1) 已知 op 名 / 数值 MIUIOP；
   *  2) 查询结果启发式：若已能读到 10086/95566 等服务号，视为已开通；
   *     若只有点对点手机号且条数很少，大概率未开通（未开通时常见只有个位数）。
   */
  fun miuiNotificationSmsState(): String {
    if (!isMiui()) return ChannelCodes.MIUI_UNKNOWN

    val candidates = listOf(
      "RECEIVE_NOTIFICATION_SMS",
      "READ_NOTIFICATION_SMS",
      "RECEIVE_SMS_NOTIFICATION",
      "GET_RECEIVE_NOTIFICATION_SMS",
    )
    for (op in candidates) {
      try {
        val mode = appOps.unsafeCheckOpNoThrow(op, Process.myUid(), context.packageName)
        when (mode) {
          AppOpsManager.MODE_ALLOWED -> return ChannelCodes.MIUI_ALLOW
          AppOpsManager.MODE_IGNORED, AppOpsManager.MODE_ERRORED -> return ChannelCodes.MIUI_LIKELY_OFF
        }
      } catch (_: Exception) {
        // op 名不存在
      }
    }

    // 启发式：看库里是否已经出现服务号短信
    return try {
      var service = 0
      var total = 0
      context.contentResolver.query(
        Telephony.Sms.CONTENT_URI,
        arrayOf(Telephony.Sms.ADDRESS),
        null,
        null,
        "${Telephony.Sms.DATE} DESC",
      )?.use { c ->
        while (c.moveToNext() && total < 80) {
          total++
          val addr = c.getString(0) ?: continue
          if (looksLikeServiceAddress(addr)) service++
        }
      }
      when {
        service > 0 -> ChannelCodes.MIUI_ALLOW
        total in 1..20 -> ChannelCodes.MIUI_LIKELY_OFF
        else -> ChannelCodes.MIUI_UNKNOWN
      }
    } catch (_: Exception) {
      ChannelCodes.MIUI_UNKNOWN
    }
  }

  /** 10086 / 95566 / 106xxx 等服务号，或非手机号格式。 */
  @androidx.annotation.VisibleForTesting
  internal fun looksLikeServiceAddress(addr: String): Boolean {
    val a = addr.trim()
    if (a.isEmpty()) return false
    if (a.startsWith("106")) return true
    if (a.length <= 6) return true
    return !a.matches(Regex("^\\+?\\d{7,15}$"))
  }

  /**
   * 打开 MIUI 权限编辑页（权限管理 · 其他权限 · 通知类短信）。
   * 失败则回落到系统应用详情页。
   */
  fun openMiuiPermissionEditor(activity: Activity): Boolean {
    val miui = Intent("miui.intent.action.APP_PERM_EDITOR").apply {
      setPackage("com.miui.securitycenter")
      putExtra("extra_pkgname", context.packageName)
    }
    return try {
      activity.startActivity(miui)
      true
    } catch (_: Exception) {
      openAppSettings(activity)
    }
  }

  /**
   * QA 专用：插入带唯一前缀的测试短信，只新增、不改旧数据。
   * 仅 debuggable 包可用，避免 release 留写库入口。
   * @return 插入成功的 _id 列表；null=非默认/非 debug/失败
   */
  fun insertTestSms(count: Int, bodyPrefix: String): List<Int>? {
    if (isDefaultSms() != true) return null
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
      Log.e(TAG, "insertTestSms", e)
      null
    }
  }

  /**
   * QA 专用：只删除 body 以前缀开头的短信（绝不匹配真实短信）。
   * @return 删除条数；null=非默认/失败
   */
  fun deleteTestSmsByPrefix(bodyPrefix: String): Int? {
    if (bodyPrefix.isBlank()) return null
    if (isDefaultSms() != true) return null
    val flags = context.applicationInfo.flags
    if ((flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) == 0) return null
    return try {
      context.contentResolver.delete(
        Telephony.Sms.CONTENT_URI,
        "${Telephony.Sms.BODY} LIKE ?",
        arrayOf("$bodyPrefix%"),
      )
    } catch (e: Exception) {
      Log.e(TAG, "deleteTestSmsByPrefix", e)
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
      Log.e(TAG, "filterTestIds", e)
      emptyList()
    }
  }

  /**
   * 还原为系统默认短信。
   * Q+ 起 ACTION_CHANGE_DEFAULT 对第三方已失效，无法代用户释放 ROLE_SMS，
   * 只能打开系统「默认应用」页让用户手动改。
   * @return "settings" 已打开设置 / "not_default" 本就不是默认 / "error"（见 [ChannelCodes]）
   */
  fun restoreDefaultSms(activity: Activity): String = try {
    if (isDefaultSms() != true) return ChannelCodes.RESTORE_NOT_DEFAULT
    activity.startActivity(Intent(Settings.ACTION_MANAGE_DEFAULT_APPS_SETTINGS))
    ChannelCodes.RESTORE_SETTINGS
  } catch (e: Exception) {
    Log.e(TAG, "restoreDefaultSms", e)
    ChannelCodes.ERROR
  }

  /**
   * 查询短信 + 彩信，合并到同一列表。
   *
   * @param limit null=全量（兼容旧调用）；非空时按 date 降序切页
   * @param offset 跳过条数，仅在 limit 非空时生效
   * @return messages + total + error(null|permission|unknown)，键与错误值见 [ChannelCodes]
   */
  fun querySms(address: String?, limit: Int? = null, offset: Int = 0): Map<String, Any?> {
    if (!hasReadSms() && isDefaultSms() != true) {
      return mapOf(
        ChannelCodes.KEY_MESSAGES to emptyList<Any>(),
        ChannelCodes.KEY_TOTAL to 0,
        ChannelCodes.KEY_ERROR to ChannelCodes.QUERY_ERROR_PERMISSION,
      )
    }
    val sel = if (address.isNullOrEmpty()) null else "${Telephony.Sms.ADDRESS}=?"
    val args = if (address.isNullOrEmpty()) null else arrayOf(address)
    // SMS / MMS 的 _id 互不相干，必须分表去重后再合并，否则同号 id 会互相吞掉。
    val smsById = LinkedHashMap<Int, Map<String, Any?>>()
    val mmsById = LinkedHashMap<Int, Map<String, Any?>>()
    var security = false
    var other = false
    for (uri in SMS_URIS) {
      try {
        context.contentResolver.query(uri, PROJECTION, sel, args, null)?.use { c ->
          while (c.moveToNext()) {
            val row = readRow(c)
            val id = row["_id"] as? Int ?: continue
            smsById.putIfAbsent(id, row)
          }
        }
      } catch (e: SecurityException) {
        security = true
      } catch (e: Exception) {
        other = true
        Log.e(TAG, "query $uri", e)
      }
    }
    // 彩信 address 在 addr 表，无法用 SQL selection 过滤：先取匹配 msg_id 再在内存收窄。
    val mmsAddrFilter = if (address.isNullOrEmpty()) null else queryMmsIdsByAddress(address)
    if (mmsAddrFilter == null || mmsAddrFilter.isNotEmpty()) {
      for (uri in MMS_URIS) {
        try {
          context.contentResolver.query(uri, MMS_PROJECTION, null, null, null)?.use { c ->
            while (c.moveToNext()) {
              val row = readMmsRow(c) ?: continue
              val id = row["_id"] as? Int ?: continue
              if (mmsAddrFilter != null && id !in mmsAddrFilter) continue
              mmsById.putIfAbsent(id, row)
            }
          }
        } catch (e: SecurityException) {
          security = true
        } catch (e: Exception) {
          other = true
          Log.e(TAG, "query $uri", e)
        }
      }
    }
    // 切页前必须全局定序：date 降序（null 最早）；同 date 时 is_mms 降序 + _id 降序作稳定次键，
    // 与 Dart `uid` 序一致，避免同 date 跨页抖动。
    val all = (smsById.values + mmsById.values).sortedWith(
      compareByDescending<Map<String, Any?>> { (it["date"] as? Number)?.toLong() ?: Long.MIN_VALUE }
        .thenByDescending { (it["is_mms"] as? Number)?.toInt() ?: 0 }
        .thenByDescending { (it["_id"] as? Number)?.toInt() ?: 0 },
    )
    val total = all.size
    val page = if (limit == null) {
      all
    } else {
      all.drop(offset.coerceAtLeast(0)).take(limit.coerceAtLeast(0))
    }
    // 正文/号码只对本页彩信补全（addr/part 批量查），避免对全库 N+1。
    val enriched = enrichMmsRows(page)
    val anyRow = smsById.isNotEmpty() || mmsById.isNotEmpty()
    val error = when {
      anyRow -> null
      security -> ChannelCodes.QUERY_ERROR_PERMISSION
      other -> ChannelCodes.QUERY_ERROR_UNKNOWN
      else -> null
    }
    return mapOf(
      ChannelCodes.KEY_MESSAGES to enriched,
      ChannelCodes.KEY_TOTAL to total,
      ChannelCodes.KEY_ERROR to error,
    )
  }

  /**
   * 批量删除。按 `is_mms` 路由到 `content://sms` / `content://mms`，绝不跨表删。
   *
   * 入参每项为：
   * - [Number]：纯 SMS `_id`（旧调用兼容）
   * - Map `{"id": Int, "is_mms": 0|1}`：混合目标
   *
   * @return 行数；null=非默认/失败
   */
  fun deleteSmsBatch(targets: List<Any?>): Int? {
    if (targets.isEmpty()) return 0
    if (isDefaultSms() != true) return null
    val (smsIds, mmsIds) = splitDeleteTargets(targets)
    return try {
      // 直接把 Telephony.*.CONTENT_URI（平台类型，桩里为 null）传给 delete，
      // 不经过非空 Kotlin 参数，避免 JVM 单测 NPE。
      var n = 0
      for (chunk in smsIds.chunked(900)) {
        n += context.contentResolver.delete(
          Telephony.Sms.CONTENT_URI,
          "_id IN (${chunk.joinToString(",") { "?" }})",
          chunk.map { it.toString() }.toTypedArray(),
        )
      }
      for (chunk in mmsIds.chunked(900)) {
        n += context.contentResolver.delete(
          Telephony.Mms.CONTENT_URI,
          "_id IN (${chunk.joinToString(",") { "?" }})",
          chunk.map { it.toString() }.toTypedArray(),
        )
      }
      n
    } catch (e: Exception) {
      Log.e(TAG, "deleteSmsBatch", e)
      null
    }
  }

  /** 把混合入参拆成 SMS / MMS 两组 id。未知形态直接丢弃，绝不猜测路由。 */
  @androidx.annotation.VisibleForTesting
  internal fun splitDeleteTargets(targets: List<Any?>): Pair<List<Int>, List<Int>> {
    val sms = mutableListOf<Int>()
    val mms = mutableListOf<Int>()
    for (t in targets) {
      when (t) {
        is Number -> sms.add(t.toInt())
        is Map<*, *> -> {
          val id = (t["id"] as? Number)?.toInt() ?: continue
          if (isMmsFlag(t["is_mms"])) mms.add(id) else sms.add(id)
        }
      }
    }
    return sms to mms
  }

  /** `is_mms` 线值：1 / true 视为彩信；0 / false / 缺失视为短信。 */
  @androidx.annotation.VisibleForTesting
  internal fun isMmsFlag(v: Any?): Boolean =
    v == true || (v as? Number)?.toInt() == 1

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
   * @return Map:
   *   ok       Boolean  是否非失败态（false=非默认/整批未执行）
   *   inserted Int      成功条数
   *   failed   Int      失败条数
   *   errors   List     [{index, code, message}]，index 为入参 rows 下标；-1=整批级
   */
  fun insertSmsBatch(rows: List<Map<String, Any?>>): Map<String, Any?> {
    if (rows.isEmpty()) {
      return insertResult(ok = true, inserted = 0, failed = 0, errors = emptyList())
    }
    if (isDefaultSms() != true) {
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
    rows.forEachIndexed { i, row ->
      try {
        val (uri, values) = buildInsert(row)
        if (context.contentResolver.insert(uri, values) != null) inserted++
        else {
          failed++
          errors.add(insertError(i, ChannelCodes.INSERT_ERROR_FAILED, "insert returned null"))
        }
      } catch (e: Exception) {
        Log.e(TAG, "insertSmsBatch row $i", e)
        failed++
        errors.add(insertError(i, ChannelCodes.INSERT_ERROR_FAILED, e.message ?: "insert failed"))
      }
    }
    return insertResult(ok = true, inserted = inserted, failed = failed, errors = errors)
  }

  private fun buildInsert(row: Map<String, Any?>): Pair<Uri, ContentValues> {
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

  /**
   * 从 `content://mms/addr` 取匹配号码的 msg_id 集合。
   * 失败回空集（宁可少显示彩信，也不误含无关行）。
   */
  private fun queryMmsIdsByAddress(address: String): Set<Int> = try {
    val ids = mutableSetOf<Int>()
    context.contentResolver.query(
      mmsAddrUri(),
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
    Log.e(TAG, "queryMmsIdsByAddress", e)
    emptySet()
  }

  /**
   * 给本页彩信补 address / body 摘要 / has_media。
   * addr + part 各一次批量查询（`IN` 分片），不是逐条 N+1。
   */
  private fun enrichMmsRows(page: List<Map<String, Any?>>): List<Map<String, Any?>> {
    val mmsIds = page.mapNotNull { row ->
      if (isMmsFlag(row["is_mms"])) row["_id"] as? Int else null
    }
    if (mmsIds.isEmpty()) return page
    val addrs = queryMmsAddresses(mmsIds)
    val bodies = queryMmsBodies(mmsIds)
    return page.map { row ->
      if (!isMmsFlag(row["is_mms"])) row
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
   */
  private fun queryMmsAddresses(ids: List<Int>): Map<Int, String> {
    val best = mutableMapOf<Int, Pair<Int, String>>() // msgId -> (priority, address)
    fun priorityOf(type: Int): Int = when (type) {
      MMS_ADDR_TYPE_FROM -> 0
      MMS_ADDR_TYPE_TO -> 1
      else -> 2
    }
    forChunked(ids) { chunk ->
      try {
        context.contentResolver.query(
          mmsAddrUri(),
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
        Log.e(TAG, "queryMmsAddresses", e)
      }
    }
    return best.mapValues { it.value.second }
  }

  /**
   * msg_id → (文本摘要, 是否含媒体附件)。
   * 文本取 `ct` 为 text/plain · text/x-vcard · text/x-vcalendar · text/html 的 part 的 `text` 列拼接；
   * 媒体看 image/ · audio/ · video/ 或带 `_data` 的 application/ 任意类型。
   */
  private fun queryMmsBodies(ids: List<Int>): Map<Int, Pair<String, Boolean>> {
    val texts = mutableMapOf<Int, MutableList<String>>()
    val media = mutableSetOf<Int>()
    forChunked(ids) { chunk ->
      try {
        context.contentResolver.query(
          mmsPartUri(),
          arrayOf(
            Telephony.Mms.Part.MSG_ID,
            Telephony.Mms.Part.CONTENT_TYPE,
            PART_TEXT_COLUMN,
            Telephony.Mms.Part._DATA,
          ),
          "mid IN (${chunk.joinToString(",") { "?" }})",
          chunk.map { it.toString() }.toTypedArray(),
          null,
        )?.use { c ->
          val midCol = c.getColumnIndex(Telephony.Mms.Part.MSG_ID)
          val ctCol = c.getColumnIndex(Telephony.Mms.Part.CONTENT_TYPE)
          val textCol = c.getColumnIndex(PART_TEXT_COLUMN)
          val dataCol = c.getColumnIndex(Telephony.Mms.Part._DATA)
          while (c.moveToNext()) {
            if (midCol < 0 || c.isNull(midCol)) continue
            val mid = c.getInt(midCol)
            val ct = (if (ctCol >= 0 && !c.isNull(ctCol)) c.getString(ctCol) else null)
              ?.lowercase().orEmpty()
            when {
              ct in TEXT_PART_CTS -> {
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
        Log.e(TAG, "queryMmsBodies", e)
      }
    }
    return ids.associateWith { id ->
      (texts[id]?.joinToString("\n").orEmpty()) to (id in media)
    }
  }

  private inline fun forChunked(ids: List<Int>, block: (List<Int>) -> Unit) {
    ids.chunked(900).forEach(block)
  }

  companion object {
    private const val TAG = "SmsAccess"
    private val PROJECTION = arrayOf(
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
    private val SMS_URIS = listOf(
      Telephony.Sms.CONTENT_URI,
      Telephony.Sms.Inbox.CONTENT_URI,
      Telephony.Sms.Sent.CONTENT_URI,
      Telephony.Sms.Draft.CONTENT_URI,
    )
    private val MMS_PROJECTION = arrayOf(
      BaseColumns._ID,
      Telephony.Mms.THREAD_ID,
      Telephony.Mms.DATE,
      Telephony.Mms.DATE_SENT,
      Telephony.Mms.READ,
      Telephony.Mms.MESSAGE_BOX,
      Telephony.Mms.SUBSCRIPTION_ID,
    )
    private val MMS_URIS = listOf(
      Telephony.Mms.CONTENT_URI,
      Telephony.Mms.Inbox.CONTENT_URI,
      Telephony.Mms.Sent.CONTENT_URI,
      Telephony.Mms.Draft.CONTENT_URI,
    )

    /** part 表文本列：公开 API 无常量，provider 列名就是 `text`。 */
    private const val PART_TEXT_COLUMN = "text"

    /**
     * `content://mms/addr` / `content://mms/part`：`Telephony.Mms.Addr` / `Part`
     * 未暴露 CONTENT_URI 常量，只能字面量构造。
     * 返回平台类型（可为 null）：JVM 桩里 `Uri.parse` 不可用，回落 `Telephony.Mms.CONTENT_URI`
     * （同样为 null）；与 SMS 路径一致，mock resolver 不关心 URI 值。
     */
    private fun mmsAddrUri() = try {
      Uri.parse("content://mms/addr")
    } catch (_: Exception) {
      Telephony.Mms.CONTENT_URI
    }

    private fun mmsPartUri() = try {
      Uri.parse("content://mms/part")
    } catch (_: Exception) {
      Telephony.Mms.CONTENT_URI
    }

    /** addr.type：137=FROM（收件对端），151=TO（发件对端）。公开 API 无具名常量。 */
    private const val MMS_ADDR_TYPE_FROM = 137
    private const val MMS_ADDR_TYPE_TO = 151

    /** 可拼进正文摘要的文本 part 类型。 */
    private val TEXT_PART_CTS = setOf(
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
