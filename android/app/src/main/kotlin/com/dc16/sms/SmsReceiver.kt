package com.dc16.sms

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony

/**
 * SMS_DELIVER：仅默认短信应用会收到。
 * 必须写入系统短信库，否则来信会丢。
 */
class SmsReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent) {
    if (intent.action != Telephony.Sms.Intents.SMS_DELIVER_ACTION) return
    val msgs = Telephony.Sms.Intents.getMessagesFromIntent(intent) ?: return
    for (m in msgs) {
      SmsAccess.insertInbox(context, m.originatingAddress, m.messageBody, m.timestampMillis)
    }
  }
}
