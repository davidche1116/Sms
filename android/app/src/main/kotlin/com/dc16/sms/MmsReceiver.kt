package com.dc16.sms

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** WAP_PUSH_DELIVER 占位，满足 ROLE_SMS 组件要求。 */
class MmsReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent) = Unit
}
