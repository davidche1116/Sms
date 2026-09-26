package com.dc16.sms

import android.app.Service
import android.content.Intent
import android.os.IBinder

/** RESPOND_VIA_MESSAGE 占位，满足 ROLE_SMS 组件要求。 */
class HeadlessSmsSendService : Service() {
  override fun onBind(intent: Intent?): IBinder? = null
  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    stopSelf(startId)
    return START_NOT_STICKY
  }
}
