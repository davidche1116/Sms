package com.dc16.sms

import android.Manifest
import android.app.role.RoleManager
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.os.Build
import android.util.Log
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
            "openAppSettings" -> result.success(access.openAppSettings(this))
            "isMiui" -> result.success(access.isMiui())
            "miuiNotificationSmsState" -> result.success(access.miuiNotificationSmsState())
            "openMiuiPermissionEditor" ->
              result.success(access.openMiuiPermissionEditor(this))
            "insertTestSms" -> {
              val args = call.arguments as? Map<*, *>
              val count = (args?.get("count") as? Number)?.toInt() ?: 3
              val prefix = args?.get("bodyPrefix") as? String ?: "SMSCLEANUP_TEST"
              val ids = access.insertTestSms(count, prefix)
              if (ids == null) result.success(mapOf("ok" to false, "ids" to emptyList<Int>()))
              else result.success(mapOf("ok" to true, "ids" to ids))
            }
            "deleteTestSmsByPrefix" -> {
              val prefix = (call.arguments as? Map<*, *>)?.get("bodyPrefix") as? String
                ?: "SMSCLEANUP_TEST"
              val n = access.deleteTestSmsByPrefix(prefix)
              result.success(mapOf("ok" to (n != null), "deleted" to (n ?: 0)))
            }
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
    handleQaIntent(intent)
  }

  override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    handleQaIntent(intent)
  }

  /**
   * debug 包 QA 入口：adb 跳转触发，只操作带测试前缀的短信。
   *  - action=com.dc16.sms.QA_INSERT_TEST   extra count=3 bodyPrefix=SMSCLEANUP_TEST
   *  - action=com.dc16.sms.QA_DELETE_TEST   extra bodyPrefix=SMSCLEANUP_TEST
   * 结果写入 filesDir/qa_result.txt，便于 run-as 回读。
   */
  private fun handleQaIntent(intent: Intent?) {
    if (intent == null) return
    if ((applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) == 0) return
    val action = intent.action ?: return
    val prefix = intent.getStringExtra("bodyPrefix") ?: "SMSCLEANUP_TEST"
    when (action) {
      "com.dc16.sms.QA_INSERT_TEST" -> {
        val count = intent.getIntExtra("count", 3)
        val ids = access.insertTestSms(count, prefix)
        writeQaResult("INSERT ok=${ids != null} ids=$ids prefix=$prefix")
      }
      "com.dc16.sms.QA_DELETE_TEST" -> {
        val n = access.deleteTestSmsByPrefix(prefix)
        writeQaResult("DELETE ok=${n != null} deleted=$n prefix=$prefix")
      }
      "com.dc16.sms.QA_DELETE_IDS" -> {
        val ids = intent.getIntArrayExtra("ids")?.toList() ?: emptyList()
        // 只允许删除 body 带测试前缀的 id，真实短信直接拒绝
        val safe = access.filterTestIds(ids, prefix)
        val n = access.deleteSmsBatch(safe)
        writeQaResult("DELETE_IDS requested=$ids safe=$safe deleted=$n prefix=$prefix")
      }
    }
  }

  private fun writeQaResult(line: String) {
    try {
      java.io.File(filesDir, "qa_result.txt").writeText(line)
      Log.i("QaIntent", line)
    } catch (e: Exception) {
      Log.e("QaIntent", "writeQaResult", e)
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
