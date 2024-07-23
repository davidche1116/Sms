package com.dc16.sms

import io.flutter.embedding.android.FlutterFragmentActivity
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.content.IntentFilter
import android.provider.Telephony
import android.os.Build
import android.os.Build.VERSION
import android.os.Build.VERSION_CODES
import android.app.role.RoleManager
import android.content.ContentValues
import android.net.Uri
import android.provider.Settings
import android.content.pm.PackageManager

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.dc16.sms/smsApp"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            // This method is invoked on the main thread.
                call, result ->
            if (call.method == "getDefaultSmsApp") {
                result.success(getDefaultSmsApp())
            } else if (call.method == "setDefaultSmsApp") {
                result.success(setDefaultSmsApp())
            } else if (call.method == "resetDefaultSmsApp") {
                result.success(resetDefaultSmsApp())
            } else {
                result.notImplemented()
            }
        }
    }

    private fun getDefaultSmsApp(): String {
        val defaultSmsApp = Telephony.Sms.getDefaultSmsPackage(this)
        if (defaultSmsApp == null) {
            if (Build.VERSION.SDK_INT > Build.VERSION_CODES.P) {
                val roleManager = getSystemService(RoleManager::class.java)
                val had = roleManager.isRoleHeld(RoleManager.ROLE_SMS)
                if (had) {
                    val packageName: String = getPackageName()
                    return packageName
                } else {
                    return ""
                }
            }
        }
        return defaultSmsApp
    }

    private fun setDefaultSmsApp(): String {
        val packageName: String = getPackageName()
        val defaultName: String = getDefaultSmsApp()
        if (defaultName == "" || !packageName.equals(defaultName)) {
            if (Build.VERSION.SDK_INT > Build.VERSION_CODES.P) {
                val roleManager = getSystemService(RoleManager::class.java)
                val had = roleManager.isRoleHeld(RoleManager.ROLE_SMS)
                if (had) {
                    return "had"
                }
                val roleRequestIntent = roleManager.createRequestRoleIntent(RoleManager.ROLE_SMS)
                startActivityForResult(roleRequestIntent, 12)
            } else {
                val intent = Intent(Telephony.Sms.Intents.ACTION_CHANGE_DEFAULT)
                intent.putExtra(Telephony.Sms.Intents.EXTRA_PACKAGE_NAME, packageName)
                startActivity(intent)
            }
            return "no"
        }
        return "ok"
    }

    private fun resetDefaultSmsApp(): String {
        val packageManager: PackageManager = getPackageManager();
        val intent: Intent? = packageManager.getLaunchIntentForPackage("com.android.mms")
        if (intent != null) {
            startActivity(intent)
            return "ok"
        } else {
            return "no"
        }
    }
}
