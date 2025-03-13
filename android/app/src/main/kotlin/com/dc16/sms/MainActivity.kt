package com.dc16.sms

import android.app.role.RoleManager
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Telephony
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
            if (Build.VERSION.SDK_INT > Build.VERSION_CODES.P) {
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
            if (Build.VERSION.SDK_INT > Build.VERSION_CODES.P) {
                val roleManager = getSystemService(RoleManager::class.java)
                val isRoleHeld = roleManager?.isRoleHeld(RoleManager.ROLE_SMS) ?: false
                if (isRoleHeld) {
                    return "had"
                }
                val roleRequestIntent = roleManager?.createRequestRoleIntent(RoleManager.ROLE_SMS)
                roleRequestIntent?.let {
                    startActivityForResult(it, 12)
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
     * 重置默认短信应用为系统应用
     * @return 返回重置状态："ok"(重置成功)，"no"(重置失败)
     */
    private fun resetDefaultSmsApp(): String {
        val packageManager = packageManager
        
        // 尝试启动Android默认短信应用
        packageManager.getLaunchIntentForPackage("com.android.mms")?.let { intent ->
            startActivity(intent)
            return "ok"
        }
        
        // 尝试启动Google短信应用
        packageManager.getLaunchIntentForPackage("com.google.android.apps.messaging")?.let { intent ->
            startActivity(intent)
            return "ok"
        }
        
        return "no"
    }
}
