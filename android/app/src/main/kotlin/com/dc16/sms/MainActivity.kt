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

/**
 * MethodChannel.Result 一次性包装：success/error/notImplemented 只会发出一次。
 *
 * 防止「系统弹窗回调 + Activity 销毁收尾」或「handler catch + 销毁收尾」
 * 对同一个 Result 二次回包（Flutter 会抛 IllegalStateException）。
 */
private class OnceResult(private val raw: MethodChannel.Result) : MethodChannel.Result {
  @Volatile
  private var done = false

  override fun success(result: Any?) {
    if (done) return
    done = true
    try {
      raw.success(result)
    } catch (e: Exception) {
      Log.w("OnceResult", "success", e)
    }
  }

  override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
    if (done) return
    done = true
    try {
      raw.error(errorCode, errorMessage, errorDetails)
    } catch (e: Exception) {
      Log.w("OnceResult", "error", e)
    }
  }

  override fun notImplemented() {
    if (done) return
    done = true
    try {
      raw.notImplemented()
    } catch (e: Exception) {
      Log.w("OnceResult", "notImplemented", e)
    }
  }
}

class MainActivity : FlutterFragmentActivity() {
  private val channelName = "com.dc16.sms/smsApp"
  private lateinit var access: SmsAccess

  /** 等待系统权限弹窗结果后再回包，Dart 才能刷新。取出即清空，保证只 complete 一次。 */
  private var pendingRead: MethodChannel.Result? = null
  private var pendingRole: MethodChannel.Result? = null

  /** 原子取出并清空 pendingRead。 */
  private fun takePendingRead(): MethodChannel.Result? {
    val r = pendingRead
    pendingRead = null
    return r
  }

  /** 原子取出并清空 pendingRole。 */
  private fun takePendingRole(): MethodChannel.Result? {
    val r = pendingRole
    pendingRole = null
    return r
  }

  /**
   * Activity 销毁 / 引擎换绑前收尾挂起的 Result，绝不丢包。
   * 回 [ChannelCodes.ERROR_LIFECYCLE]，Dart 映射为 timeout 语义后再查一次状态。
   */
  private fun completePendingOnTeardown(reason: String) {
    takePendingRead()?.let { r ->
      Log.i("MainActivity", "completePendingRead on $reason")
      r.error(ChannelCodes.ERROR_LIFECYCLE, "requestReadSms cancelled: $reason", null)
    }
    takePendingRole()?.let { r ->
      Log.i("MainActivity", "completePendingRole on $reason")
      r.error(ChannelCodes.ERROR_LIFECYCLE, "setDefaultSms cancelled: $reason", null)
    }
  }

  private val requestRead =
    registerForActivityResult(ActivityResultContracts.RequestPermission()) {
      val r = takePendingRead()
      // 用户从系统弹窗返回后无论结果如何都回包，让 Dart 刷新
      r?.success(access.hasReadSms())
    }

  private val requestRole =
    registerForActivityResult(ActivityResultContracts.StartActivityForResult()) {
      val r = takePendingRole()
      // 用户从角色页返回后无论结果如何都回包，让 Dart 刷新
      r?.success(
        if (access.isDefaultSms() == true) ChannelCodes.SET_DEFAULT_HAD
        else ChannelCodes.SET_DEFAULT_NO,
      )
    }

  override fun onDestroy() {
    completePendingOnTeardown("onDestroy")
    super.onDestroy()
  }

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    // 引擎换绑时旧 pending 的 Result 已无法被系统回调送达，先收尾
    completePendingOnTeardown("configureFlutterEngine")
    access = SmsAccess(applicationContext)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
      .setMethodCallHandler { call, rawResult ->
        // 一次性包装：系统回调 / 销毁收尾 / 异常 catch 对同一 Result 只回一次
        val result = OnceResult(rawResult)
        try {
          when (call.method) {
            "hasReadSmsPermission" -> result.success(access.hasReadSms())
            "requestReadSms" -> {
              if (access.hasReadSms()) {
                result.success(true)
              } else if (pendingRead != null) {
                // 已有弹窗在途，不重复 launch；直接回 false，Dart 会再查权限
                result.success(false)
              } else {
                pendingRead = result
                try {
                  requestRead.launch(Manifest.permission.READ_SMS)
                } catch (e: Exception) {
                  // launch 失败：收回 pending 交给外层 error，避免悬挂
                  takePendingRead()
                  throw e
                }
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
              if (ids == null) {
                result.success(
                  mapOf(ChannelCodes.KEY_OK to false, ChannelCodes.KEY_IDS to emptyList<Int>()),
                )
              } else {
                result.success(mapOf(ChannelCodes.KEY_OK to true, ChannelCodes.KEY_IDS to ids))
              }
            }
            "deleteTestSmsByPrefix" -> {
              val prefix = (call.arguments as? Map<*, *>)?.get("bodyPrefix") as? String
                ?: "SMSCLEANUP_TEST"
              val n = access.deleteTestSmsByPrefix(prefix)
              result.success(
                mapOf(ChannelCodes.KEY_OK to (n != null), ChannelCodes.KEY_DELETED to (n ?: 0)),
              )
            }
            "querySms" -> {
              val args = call.arguments as? Map<*, *>
              val addr = args?.get("address") as? String
              val limit = (args?.get("limit") as? Number)?.toInt()
              val offset = (args?.get("offset") as? Number)?.toInt() ?: 0
              result.success(access.querySms(addr, limit, offset))
            }
            "deleteSmsBatch" -> {
              val ids = (call.arguments as? List<*>)?.mapNotNull { (it as? Number)?.toInt() }
              result.success(access.deleteSmsBatch(ids ?: emptyList()))
            }
            "insertSmsBatch" -> {
              val raw = (call.arguments as? List<*>) ?: emptyList<Any>()
              val rows = raw.mapNotNull { item ->
                (item as? Map<*, *>)?.let { m ->
                  mapOf<String, Any?>(
                    "address" to m["address"] as? String,
                    "body" to m["body"] as? String,
                    "date" to (m["date"] as? Number)?.toLong(),
                    "type" to (m["type"] as? Number)?.toInt(),
                    "sub_id" to (m["sub_id"] as? Number)?.toInt(),
                  )
                }
              }
              result.success(access.insertSmsBatch(rows))
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
      "com.dc16.sms.QA_QUERY_STATE" -> {
        val miui = access.isMiui()
        val notif = access.miuiNotificationSmsState()
        val read = access.hasReadSms()
        val def = access.isDefaultSms()
        writeQaResult("STATE miui=$miui notif=$notif read=$read default=$def")
      }
      "com.dc16.sms.QA_IMPORT_TEST" -> {
        // 与 CSV 导入同一 insertSmsBatch 通道，仅写入带前缀的测试行
        val rows = listOf(
          mapOf<String, Any?>(
            "address" to "10086",
            "body" to "$prefix import #1",
            "date" to System.currentTimeMillis(),
            "type" to 1,
            "sub_id" to 1,
          ),
          mapOf<String, Any?>(
            "address" to "13800000000",
            "body" to "$prefix import #2",
            "date" to System.currentTimeMillis(),
            "type" to 2,
            "sub_id" to 1,
          ),
        )
        val n = access.insertSmsBatch(rows)
        writeQaResult("IMPORT_BATCH ok=${n != null} inserted=$n prefix=$prefix")
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
      result.success(ChannelCodes.SET_DEFAULT_HAD)
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
        try {
          requestRole.launch(intent)
        } catch (e: Exception) {
          // launch 失败：收回 pending，走下方 fallback 回包
          takePendingRole()
          access.openDefaultSmsSettings(this)
          result.success(ChannelCodes.SET_DEFAULT_NO)
        }
      } else {
        // 角色申请不可用 / 正在请求中 → 直接打开系统默认应用页
        access.openDefaultSmsSettings(this)
        result.success(ChannelCodes.SET_DEFAULT_NO)
      }
    } catch (e: Exception) {
      access.openDefaultSmsSettings(this)
      result.success(ChannelCodes.SET_DEFAULT_NO)
    }
  }
}
