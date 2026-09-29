package com.dc16.sms

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.util.Log

/**
 * WAP_PUSH_DELIVER（`application/vnd.wap.mms-message`）：仅默认短信应用会收到。
 *
 * 与 [SmsReceiver] 对等：必须写入系统彩信库，否则来信会丢。PDU 在 `intent` 的
 * `"data"` extra（参见 `Telephony.Sms.Intents.WAP_PUSH_DELIVER_ACTION` 文档）。
 *
 * 落库范围见 [SmsAccess.insertMmsNotification]：元数据骨架（inbox + addr + 主题
 * text part）。完整 smil / 媒体下载重建依赖非公开 `PduPersister`，本应用不做；
 * 需要完整彩信正文时请临时切回系统信息应用接收（README「彩信支持范围」）。
 */
class MmsReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent) {
    try {
      if (intent.action != Telephony.Sms.Intents.WAP_PUSH_DELIVER_ACTION) return
      val pdu = intent.getByteArrayExtra(EXTRA_DATA) ?: return
      val n = MmsPduParser.parseNotification(pdu) ?: return
      // 系统只投递给默认应用；仍按 insertInbox 同级 try/catch 兜底，失败不崩。
      val subId = intent.getLongExtra(EXTRA_SUBSCRIPTION, -1L)
        .let { if (it < 0) null else it.toInt() }
      SmsAccess(context).insertMmsNotification(n, subId)
    } catch (e: Exception) {
      // 广播绝不让进程崩溃；丢一条记日志由系统行为决定是否重投。
      Log.e("MmsReceiver", "onReceive", e)
    }
  }

  private companion object {
    /** WAP_PUSH_DELIVER 文档约定：完整 MMS PDU 在 `data`。 */
    const val EXTRA_DATA = "data"

    /** 可选 subscription id（文档约定 key）。 */
    const val EXTRA_SUBSCRIPTION = "subscription"
  }
}
