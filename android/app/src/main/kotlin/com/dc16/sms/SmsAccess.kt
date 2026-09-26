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
