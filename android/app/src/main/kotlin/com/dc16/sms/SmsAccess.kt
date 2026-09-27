package com.dc16.sms

import android.app.Activity
import android.app.AppOpsManager
import android.app.role.RoleManager
import android.content.Context
import android.content.Intent
import android.database.Cursor
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

  /** had | no | error */
  fun setDefaultSms(activity: Activity): String = try {
    val rm = context.getSystemService(RoleManager::class.java)
    if (isDefaultSms() == true) return "had"
    val intent = rm?.createRequestRoleIntent(RoleManager.ROLE_SMS)
    if (intent != null) {
      activity.startActivity(intent)
      "no"
    } else "error"
  } catch (e: Exception) {
    Log.e(TAG, "setDefaultSms", e)
    "error"
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
   * @return "allow" / "likely_off" / "unknown"
   *
   * MIUI 私有开关，标准 AppOps 字符串多半不存在；结合两路信号：
   *  1) 已知 op 名 / 数值 MIUIOP；
   *  2) 查询结果启发式：若已能读到 10086/95566 等服务号，视为已开通；
   *     若只有点对点手机号且条数很少，大概率未开通（未开通时常见只有个位数）。
   */
  fun miuiNotificationSmsState(): String {
    if (!isMiui()) return "unknown"

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
          AppOpsManager.MODE_ALLOWED -> return "allow"
          AppOpsManager.MODE_IGNORED, AppOpsManager.MODE_ERRORED -> return "likely_off"
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
        service > 0 -> "allow"
        total in 1..20 -> "likely_off"
        else -> "unknown"
      }
    } catch (_: Exception) {
      "unknown"
    }
  }

  /** 10086 / 95566 / 106xxx 等服务号，或非手机号格式。 */
  private fun looksLikeServiceAddress(addr: String): Boolean {
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
   * @return "settings" 已打开设置 / "not_default" 本就不是默认 / "error"
   */
  fun restoreDefaultSms(activity: Activity): String = try {
    if (isDefaultSms() != true) return "not_default"
    activity.startActivity(Intent(Settings.ACTION_MANAGE_DEFAULT_APPS_SETTINGS))
    "settings"
  } catch (e: Exception) {
    Log.e(TAG, "restoreDefaultSms", e)
    "error"
  }

  /**
   * @return messages + error(null|permission|unknown)
   */
  fun querySms(address: String?): Map<String, Any?> {
    if (!hasReadSms() && isDefaultSms() != true) {
      return mapOf("messages" to emptyList<Any>(), "error" to "permission")
    }
    val sel = if (address.isNullOrEmpty()) null else "${Telephony.Sms.ADDRESS}=?"
    val args = if (address.isNullOrEmpty()) null else arrayOf(address)
    val byId = LinkedHashMap<Int, Map<String, Any?>>()
    var security = false
    var other = false
    for (uri in URIS) {
      try {
        context.contentResolver.query(uri, PROJECTION, sel, args, null)?.use { c ->
          while (c.moveToNext()) {
            val row = readRow(c)
            val id = row["_id"] as? Int ?: continue
            byId.putIfAbsent(id, row)
          }
        }
      } catch (e: SecurityException) {
        security = true
      } catch (e: Exception) {
        other = true
        Log.e(TAG, "query $uri", e)
      }
    }
    return when {
      byId.isNotEmpty() -> mapOf("messages" to byId.values.toList(), "error" to null)
      security -> mapOf("messages" to emptyList<Any>(), "error" to "permission")
      other -> mapOf("messages" to emptyList<Any>(), "error" to "unknown")
      else -> mapOf("messages" to emptyList<Any>(), "error" to null)
    }
  }

  /** @return 行数；null=非默认/失败 */
  fun deleteSmsBatch(ids: List<Int>): Int? {
    if (ids.isEmpty()) return 0
    if (isDefaultSms() != true) return null
    return try {
      var n = 0
      ids.chunked(900).forEach { chunk ->
        n += context.contentResolver.delete(
          Telephony.Sms.CONTENT_URI,
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

  /**
   * 导入插入：只新增，不改不删。需默认短信应用。
   * row: address, body, date(ms), type(1 inbox/2 sent/3 draft), sub_id
   * @return 成功条数；null=非默认/失败
   */
  fun insertSmsBatch(rows: List<Map<String, Any?>>): Int? {
    if (rows.isEmpty()) return 0
    if (isDefaultSms() != true) return null
    return try {
      var n = 0
      for (row in rows) {
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
        val v = android.content.ContentValues().apply {
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
        if (context.contentResolver.insert(uri, v) != null) n++
      }
      n
    } catch (e: Exception) {
      Log.e(TAG, "insertSmsBatch", e)
      null
    }
  }

  private fun readRow(c: Cursor): Map<String, Any?> {
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
    )
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
    private val URIS = listOf(
      Telephony.Sms.CONTENT_URI,
      Telephony.Sms.Inbox.CONTENT_URI,
      Telephony.Sms.Sent.CONTENT_URI,
      Telephony.Sms.Draft.CONTENT_URI,
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
