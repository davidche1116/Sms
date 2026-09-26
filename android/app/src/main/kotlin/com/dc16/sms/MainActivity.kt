package com.dc16.sms

import android.Manifest
import android.app.role.RoleManager
import android.content.Intent
import android.os.Build
import androidx.activity.result.contract.ActivityResultContracts
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
  private val channelName = "com.dc16.sms/smsApp"
  private lateinit var access: SmsAccess

  /** 等待系统权限弹窗结果后再回包，Dart 才能刷新。 */
  private var pendingRead: MethodChannel.Result? = null
  private var pendingRole: MethodChannel.Result? = null

  private val requestRead =
    registerForActivityResult(ActivityResultContracts.RequestPermission()) {
      val r = pendingRead
      pendingRead = null
      r?.success(access.hasReadSms())
    }

  private val requestRole =
    registerForActivityResult(ActivityResultContracts.StartActivityForResult()) {
      val r = pendingRole
      pendingRole = null
      // 用户从角色页返回后无论结果如何都回包，让 Dart 刷新
      r?.success(if (access.isDefaultSms() == true) "had" else "no")
    }

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    access = SmsAccess(applicationContext)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
      .setMethodCallHandler { call, result ->
        try {
          when (call.method) {
            "hasReadSmsPermission" -> result.success(access.hasReadSms())
            "requestReadSms" -> {
              if (access.hasReadSms()) {
                result.success(true)
              } else if (pendingRead != null) {
                result.success(false)
              } else {
                pendingRead = result
                requestRead.launch(Manifest.permission.READ_SMS)
              }
            }
            "isDefaultSms" -> result.success(access.isDefaultSms())
            "setDefaultSms" -> launchRoleRequest(result)
            "restoreDefaultSms" -> result.success(access.restoreDefaultSms(this))
            "openDefaultSmsSettings" ->
              result.success(access.openDefaultSmsSettings(this))
            "querySms" -> {
              val addr = (call.arguments as? Map<*, *>)?.get("address") as? String
              result.success(access.querySms(addr))
            }
            "deleteSmsBatch" -> {
              val ids = (call.arguments as? List<*>)?.mapNotNull { (it as? Number)?.toInt() }
              result.success(access.deleteSmsBatch(ids ?: emptyList()))
            }
            else -> result.notImplemented()
          }
        } catch (e: Exception) {
          result.error("error", e.message, null)
        }
      }
  }

  /** 优先 RoleManager 申请；失败则打开系统默认应用设置页。 */
  private fun launchRoleRequest(result: MethodChannel.Result) {
    if (access.isDefaultSms() == true) {
      result.success("had")
      return
    }
    try {
      val rm = getSystemService(RoleManager::class.java)
      val intent =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && rm != null && rm.isRoleAvailable(RoleManager.ROLE_SMS)
        ) {
          rm.createRequestRoleIntent(RoleManager.ROLE_SMS)
        } else {
          null
        }
      if (intent != null && pendingRole == null) {
        pendingRole = result
        requestRole.launch(intent)
      } else {
        // 角色申请不可用 / 正在请求中 → 直接打开系统默认应用页
        access.openDefaultSmsSettings(this)
        result.success("no")
      }
    } catch (e: Exception) {
      access.openDefaultSmsSettings(this)
      result.success("no")
    }
  }
}
