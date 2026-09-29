package com.dc16.sms

import android.app.Activity
import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.os.Process
import android.provider.Telephony

/** MIUI-specific logic: detection, notification SMS state, permission editor. */
internal class MiuiSupport(private val context: Context) {

  private val appOps: AppOpsManager
    get() = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager

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
        // checkOpNoThrow：API 36+ 仍可用且未废弃；unsafeCheckOpNoThrow 已废弃。
        val mode = appOps.checkOpNoThrow(op, Process.myUid(), context.packageName)
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
  fun openMiuiPermissionEditor(activity: Activity, fallback: () -> Boolean): Boolean {
    val miui = Intent("miui.intent.action.APP_PERM_EDITOR").apply {
      setPackage("com.miui.securitycenter")
      putExtra("extra_pkgname", context.packageName)
    }
    return try {
      activity.startActivity(miui)
      true
    } catch (_: Exception) {
      fallback()
    }
  }
}
