/// 短信条目模型：字段与通道契约对齐（QUERY_DELETE_DESIGN §10）。
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
  });

  /// 系统 `_id`，删除与多选的唯一依据；查询层已丢弃无 id 行，此处仅防御。
  final int? id;
  final int? threadId;
  final String address;
  final String body;

  /// 原始 date（毫秒），排序与日期筛选依据；null 视为最早。
  final int? dateMs;

  /// Telephony type：1=INBOX 2/4/5/6=SENT/OUTBOX/FAILED/QUEUED 3=DRAFT。
  final int type;

  /// sub_id，SIM 槽位。
  final int sim;
  final bool read;

  DateTime? get date =>
      dateMs == null ? null : DateTime.fromMillisecondsSinceEpoch(dateMs!);

  /// 业务类型（QUERY_DELETE_DESIGN §5.8）：缺省按收件处理。
  SmsKind get kind => switch (type) {
    1 => SmsKind.received,
    3 => SmsKind.draft,
    _ => SmsKind.sent,
  };

  /// 今天只显时:分，更早显 MM-DD。
  String get time {
    final d = date;
    if (d == null) return '';
    final now = DateTime.now();
    final sameDay =
        d.year == now.year && d.month == now.month && d.day == now.day;
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
  String dayLabelOf(AppLocalizations l10n) {
    final d = date;
    if (d == null) return l10n.dayUnknown;
    final now = DateTime.now();
    final diff = DateTime(now.year, now.month, now.day)
        .difference(DateTime(d.year, d.month, d.day))
        .inDays;
    if (diff == 0) return l10n.dayToday;
    if (diff == 1) return l10n.dayYesterday;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}
