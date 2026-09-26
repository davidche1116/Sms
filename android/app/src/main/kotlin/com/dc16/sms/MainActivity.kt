package com.dc16.sms

import android.app.role.RoleManager
import android.content.Intent
import android.content.pm.PackageManager
import android.database.Cursor
import android.os.Build
import android.provider.BaseColumns
import android.provider.Settings
import android.provider.Telephony
import android.util.Log
import androidx.activity.result.contract.ActivityResultContracts
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * MainActivity类负责处理SMS应用的主要功能
 * 包括获取、设置和重置默认短信应用
 */
class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.dc16.sms/smsApp"

    /**
     * 单次 SQL 的占位符上限：SQLite 默认 SQLITE_MAX_VARIABLE_NUMBER 为 999，
     * 留出余量按 900 一批切分。
     */
    private val DELETE_CHUNK_SIZE = 900

    /**
     * 只投影 Dart 侧真正消费的列。不要改成 `null`（全列）：部分 ROM 会在
     * 结果里塞进 `creator` 等文本列，插件式 `getInt` 读它们会抛异常。
     */
    private val SMS_QUERY_PROJECTION = arrayOf(
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

    // startActivityForResult 已废弃，改用 Activity Result API。
    // 选择结果通过 onResume 后的 getDefaultSmsApp 重新读取，无需在此处理。
    private val roleRequestLauncher =
        registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            // 通道回调里任何未捕获异常都会变成进程崩溃（用户看到的"闪退"）。
            // 统一兜住后回 error，由 Dart 侧按失败处理。
            try {
                when (call.method) {
                    "getDefaultSmsApp" -> result.success(getDefaultSmsApp())
                    "setDefaultSmsApp" -> result.success(setDefaultSmsApp())
                    "resetDefaultSmsApp" -> result.success(resetDefaultSmsApp())
                    "deleteSmsBatch" -> result.success(deleteSmsBatch(call.arguments))
                    "querySms" -> result.success(querySms(call.arguments))
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                Log.e("MainActivity", "method ${call.method} failed", e)
                result.error("error", e.message, null)
            }
        }
    }

    /**
     * 获取当前默认短信应用
     * @return 返回当前默认短信应用的包名，如果没有则返回空字符串
     */
    private fun getDefaultSmsApp(): String {
        val defaultSmsApp = Telephony.Sms.getDefaultSmsPackage(this)
        if (defaultSmsApp == null) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val roleManager = getSystemService(RoleManager::class.java)
                val isRoleHeld = roleManager?.isRoleHeld(RoleManager.ROLE_SMS) ?: false
                if (isRoleHeld) {
                    return packageName
                }
                return ""
            }
        }
        return defaultSmsApp ?: ""
    }

    /**
     * 设置当前应用为默认短信应用
     * @return 返回设置状态："had"(已经是默认应用)，"ok"(设置成功)，"no"(需要用户确认)
     */
    private fun setDefaultSmsApp(): String {
        val packageName = this.packageName
        val defaultName = getDefaultSmsApp()
        
        if (defaultName.isEmpty() || packageName != defaultName) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val roleManager = getSystemService(RoleManager::class.java)
                val isRoleHeld = roleManager?.isRoleHeld(RoleManager.ROLE_SMS) ?: false
                if (isRoleHeld) {
                    return "had"
                }
                val roleRequestIntent = roleManager?.createRequestRoleIntent(RoleManager.ROLE_SMS)
                roleRequestIntent?.let {
                    roleRequestLauncher.launch(it)
                }
            } else {
                val intent = Intent(Telephony.Sms.Intents.ACTION_CHANGE_DEFAULT)
                intent.putExtra(Telephony.Sms.Intents.EXTRA_PACKAGE_NAME, packageName)
                startActivity(intent)
            }
            return "no"
        }
        return "ok"
    }

    /**
     * 批量删除短信。
     *
     * sms_advanced 只提供逐条删除，3000 条就是 3000 次跨进程调用，耗时可达
     * 分钟级。这里在原生侧按 `_id IN (...)` 分批删除，次数降到
     * ceil(n / 900) 次。
     *
     * @param arguments id 列表
     * @return 实际删除的行数；`null` 表示参数非法或删除过程中抛出异常，
     *         调用方应回退到逐条删除。
     */
    private fun deleteSmsBatch(arguments: Any?): Int? {
        val ids = (arguments as? List<*>)?.mapNotNull { (it as? Number)?.toInt() }
            ?: return null
        if (ids.isEmpty()) return 0

        return try {
            var deleted = 0
            ids.chunked(DELETE_CHUNK_SIZE).forEach { chunk ->
                val placeholders = chunk.joinToString(",") { "?" }
                deleted += contentResolver.delete(
                    Telephony.Sms.CONTENT_URI,
                    "_id IN ($placeholders)",
                    chunk.map { it.toString() }.toTypedArray(),
                )
            }
            deleted
        } catch (e: Exception) {
            Log.e("MainActivity", "deleteSmsBatch failed", e)
            null
        }
    }

    /**
     * 读取短信（收件箱 + 已发送 + 草稿）。
     *
     * 与 sms_advanced 插件查询路径并行提供一条自管通道：
     * - 只按已知列名取值，避免插件对任意列 `getInt` 在 `creator` 等文本列上
     *   抛 NumberFormatException / IllegalStateException 导致 MethodChannel
     *   回调崩溃（掉默认短信后更易触发）；
     * - 全路径 try/catch，SecurityException 映射为 permission，不让异常冒泡。
     *
     * @param arguments 可选 Map，`address` 非空时只返回该号码的短信。
     * @return `{"messages": [...], "error": null|"permission"|"unknown"}`，
     *         messages 为 SmsMessage.fromJson 可解析的 Map 列表。
     */
    private fun querySms(arguments: Any?): Map<String, Any?> {
        val address = (arguments as? Map<*, *>)?.get("address") as? String
        val selection: String?
        val selectionArgs: Array<String>?
        if (address.isNullOrEmpty()) {
            selection = null
            selectionArgs = null
        } else {
            selection = "${Telephony.Sms.ADDRESS} = ?"
            selectionArgs = arrayOf(address)
        }

        return try {
            val messages = ArrayList<Map<String, Any?>>(64)
            // content://sms 一张表覆盖 inbox/sent/draft 等全部类型，避免
            // 分 URI 查询时某一类失败导致整次查询落空。
            contentResolver.query(
                Telephony.Sms.CONTENT_URI,
                SMS_QUERY_PROJECTION,
                selection,
                selectionArgs,
                null,
            ).use { cursor ->
                if (cursor != null) {
                    while (cursor.moveToNext()) {
                        messages.add(readSmsRow(cursor))
                    }
                }
            }
            mapOf("messages" to messages, "error" to null)
        } catch (e: SecurityException) {
            Log.w("MainActivity", "querySms permission denied", e)
            mapOf("messages" to emptyList<Any>(), "error" to "permission")
        } catch (e: Exception) {
            Log.e("MainActivity", "querySms failed", e)
            mapOf("messages" to emptyList<Any>(), "error" to "unknown")
        }
    }

    private fun readSmsRow(cursor: Cursor): Map<String, Any?> {
        fun col(name: String): Int = cursor.getColumnIndex(name)
        fun longOrNull(index: Int): Long? =
            if (index >= 0 && !cursor.isNull(index)) cursor.getLong(index) else null
        fun intOrNull(index: Int): Int? =
            if (index >= 0 && !cursor.isNull(index)) cursor.getInt(index) else null
        fun stringOrNull(name: String): String? {
            val index = col(name)
            return if (index >= 0 && !cursor.isNull(index)) cursor.getString(index) else null
        }

        return mapOf(
            "_id" to longOrNull(col(BaseColumns._ID))?.toInt(),
            "thread_id" to longOrNull(col(Telephony.Sms.THREAD_ID))?.toInt(),
            "address" to stringOrNull(Telephony.Sms.ADDRESS),
            "body" to stringOrNull(Telephony.Sms.BODY),
            "date" to longOrNull(col(Telephony.Sms.DATE)),
            "date_sent" to longOrNull(col(Telephony.Sms.DATE_SENT)),
            "read" to intOrNull(col(Telephony.Sms.READ)),
            "type" to intOrNull(col(Telephony.Sms.TYPE)),
            "sub_id" to intOrNull(col(Telephony.Sms.SUBSCRIPTION_ID)),
        )
    }

    /**
     * 判断某个包是否已安装。
     *
     * 未在本应用 `<queries>` 中声明的包，在 Android 11+ 的包可见性限制下会抛
     * NameNotFoundException，因此这里按"不可见即未安装"处理。
     */
    private fun isPackageInstalled(pkg: String): Boolean {
        return try {
            packageManager.getPackageInfo(pkg, 0) != null
        } catch (e: PackageManager.NameNotFoundException) {
            false
        }
    }

    /**
     * 将默认短信应用交还给系统短信应用。
     *
     * Android Q(10) 起默认短信应用由 RoleManager 角色机制管控，
     * Telephony.Sms.Intents.ACTION_CHANGE_DEFAULT 对第三方应用失效，且
     * RoleManager 只允许应用为自己申请角色、无法代他人释放。因此在 Q 及以上
     * 只能引导用户到系统的"默认应用"设置页手动切换。
     *
     * Q 以下仍可用 ACTION_CHANGE_DEFAULT 直接指定目标包名，由系统弹窗确认。
     *
     * @return "settings" 表示已打开系统默认应用设置页（需用户手动切换）；
     *         "ok" 表示已发起系统切换流程（需用户在系统对话框确认）；
     *         "no" 表示未找到可切换的系统短信应用或发起失败。
     */
    private fun resetDefaultSmsApp(): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            return try {
                startActivity(Intent(Settings.ACTION_MANAGE_DEFAULT_APPS_SETTINGS))
                "settings"
            } catch (e: Exception) {
                "no"
            }
        }

        val targets = listOf(
            "com.android.mms",
            "com.google.android.apps.messaging",
        )
        val installed = targets.firstOrNull(::isPackageInstalled) ?: return "no"

        return try {
            val intent = Intent(Telephony.Sms.Intents.ACTION_CHANGE_DEFAULT)
            intent.putExtra(Telephony.Sms.Intents.EXTRA_PACKAGE_NAME, installed)
            startActivity(intent)
            "ok"
        } catch (e: Exception) {
            "no"
        }
    }
}
