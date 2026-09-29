/// 短信 / 彩信条目模型：字段与通道契约对齐（QUERY_DELETE_DESIGN §10）。
///
/// 身份：wire 用 `_id` + `is_mms` 二元组（SMS / MMS 的 `_id` 互不相干）。
/// 列表去重、多选、隐藏用 [uid]（MMS 加偏移），删除仍用原生 `_id` + [isMms] 路由。
library;

import '../generated/app_localizations.dart';

enum SmsKind { received, sent, draft }

class SmsItem {
  const SmsItem({
    required this.body,
    required this.address,
    this.id,
    this.threadId,
    this.dateMs,
    this.type = 1,
    this.sim = 1,
    this.read = true,
    this.isMms = false,
    this.hasMedia = false,
  });

  /// 系统 `_id`，删除与多选的唯一依据；查询层已丢弃无 id 行，此处仅防御。
  /// 彩信时是 `content://mms` 的 `_id`，与 SMS `_id` 可能同号。
  final int? id;
  final int? threadId;
  final String address;
  final String body;

  /// 原始 date（毫秒），排序与日期筛选依据；null 视为最早。
  final int? dateMs;

  /// Telephony type：1=INBOX 2/4/5/6=SENT/OUTBOX/FAILED/QUEUED 3=DRAFT。
  /// 彩信侧映射自 `msg_box`，取值同构。
  final int type;

  /// sub_id，SIM 槽位。
  final int sim;
  final bool read;

  /// 是否彩信（wire `is_mms=1`）。
  final bool isMms;

  /// 彩信是否含非文本附件（图片/音频/视频等）。短信恒为 false。
  final bool hasMedia;

  /// MMS 在选择/隐藏键空间中的偏移，避开 SMS `_id` 冲突。
  /// 原生 id 均为非负 Int，偏移取 2^30 在 32 位 id 空间内不会溢出。
  static const int mmsUidOffset = 1 << 30;

  /// 跨 SMS/MMS 唯一键：多选 / 隐藏 / 去重 / 卡片 key 用它，不用 [id]。
  int? get uid => id == null ? null : (isMms ? id! + mmsUidOffset : id);

  DateTime? get date =>
      dateMs == null ? null : DateTime.fromMillisecondsSinceEpoch(dateMs!);

  /// 业务类型（QUERY_DELETE_DESIGN §5.8）：缺省按收件处理。
  SmsKind get kind => switch (type) {
    1 => SmsKind.received,
    3 => SmsKind.draft,
    _ => SmsKind.sent,
  };

  /// 列表 / 导出用正文。彩信无文本 part 时给本地化占位摘要。
  String bodyOf(AppLocalizations l10n) {
    if (!isMms) return body;
    if (body.isNotEmpty) return body;
    return hasMedia ? l10n.mmsBodyWithAttachment : l10n.mmsBodyPlaceholder;
  }

  /// 今天只显时:分，更早显 MM-DD。
  String time({DateTime? todayStart}) {
    final d = date;
    if (d == null) return '';
    final today = todayStart ?? DateTime.now();
    final sameDay =
        d.year == today.year && d.month == today.month && d.day == today.day;
    if (sameDay) {
      return '${d.hour.toString().padLeft(2, '0')}:'
          '${d.minute.toString().padLeft(2, '0')}';
    }
    return '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  /// 日分组键（与 locale 无关，保证同一天唯一）。
  String get dayKey {
    final d = date;
    if (d == null) return 'unknown';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  /// 今天 / 昨天 / YYYY-MM-DD（按自然日差值，正确处理跨月跨年）。
  String dayLabelOf(AppLocalizations l10n, {DateTime? todayStart}) {
    final d = date;
    if (d == null) return l10n.dayUnknown;
    final today = todayStart ?? DateTime.now();
    final diff = DateTime(
      today.year,
      today.month,
      today.day,
    ).difference(DateTime(d.year, d.month, d.day)).inDays;
    if (diff == 0) return l10n.dayToday;
    if (diff == 1) return l10n.dayYesterday;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}
