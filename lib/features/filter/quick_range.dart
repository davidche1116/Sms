import '../../generated/app_localizations.dart';

/// 时间快捷筛选预设。
///
/// 语义统一为「截止点在 N 之前」（清理旧短信）：命中条件为 `date <= cutoff`，
/// 起始侧不设限。需要「最近 N 天」语义时，把 [SmsFilter.effectiveStart] 与
/// [SmsFilter.effectiveEnd] 的取值对调即可，其余逻辑不用动。
enum SmsQuickRange { d7, d15, d30, m3, m6, y1 }

/// 计算 [range] 相对锚点 [anchor] 的截止时刻。
///
/// 天数量用 [Duration] 精确相减；月 / 年按**日历**回退，月末按当月最后一天
/// 收窄（如 3/31 减一个月 = 2/28 或 2/29），比「一律按 30 天」更符合直觉。
///
/// 传入 [anchor] 而不是直接读 `DateTime.now()`，是为了让同一轮筛选的首页与
/// 后续翻页共用同一边界（否则 `loadMore()` 时边界漂移，列表内容会抖动）。
DateTime cutoffOf(SmsQuickRange range, DateTime anchor) {
  return switch (range) {
    SmsQuickRange.d7 => anchor.subtract(const Duration(days: 7)),
    SmsQuickRange.d15 => anchor.subtract(const Duration(days: 15)),
    SmsQuickRange.d30 => anchor.subtract(const Duration(days: 30)),
    SmsQuickRange.m3 => _subMonths(anchor, 3),
    SmsQuickRange.m6 => _subMonths(anchor, 6),
    SmsQuickRange.y1 => _subMonths(anchor, 12),
  };
}

/// 日历减法：保留时刻（时 / 分 / 秒 / 毫秒），只回退年月日。
DateTime _subMonths(DateTime a, int months) {
  var year = a.year;
  var month = a.month - months;
  while (month <= 0) {
    month += 12;
    year -= 1;
  }
  // 次月 1 日往前一天 = 本月最后一天（不依赖 day=0 的归一化行为）。
  final firstOfNext = month == 12
      ? DateTime(year + 1, 1, 1)
      : DateTime(year, month + 1, 1);
  final lastDay = firstOfNext.subtract(const Duration(days: 1)).day;
  final day = a.day < lastDay ? a.day : lastDay;
  return DateTime(
    year,
    month,
    day,
    a.hour,
    a.minute,
    a.second,
    a.millisecond,
    a.microsecond,
  );
}

/// Chip / 按钮文案（显示名走 l10n）。
String quickRangeLabel(AppLocalizations l10n, SmsQuickRange range) {
  return switch (range) {
    SmsQuickRange.d7 => l10n.quickRange7d,
    SmsQuickRange.d15 => l10n.quickRange15d,
    SmsQuickRange.d30 => l10n.quickRange30d,
    SmsQuickRange.m3 => l10n.quickRange3m,
    SmsQuickRange.m6 => l10n.quickRange6m,
    SmsQuickRange.y1 => l10n.quickRange1y,
  };
}
