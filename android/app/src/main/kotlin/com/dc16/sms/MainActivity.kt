package com.dc16.sms

import android.app.role.RoleManager
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import android.provider.Telephony
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

    // startActivityForResult 已废弃，改用 Activity Result API。
    // 选择结果通过 onResume 后的 getDefaultSmsApp 重新读取，无需在此处理。
    private val roleRequestLauncher =
        registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getDefaultSmsApp" -> result.success(getDefaultSmsApp())
                "setDefaultSmsApp" -> result.success(setDefaultSmsApp())
                "resetDefaultSmsApp" -> result.success(resetDefaultSmsApp())
                else -> result.notImplemented()
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
