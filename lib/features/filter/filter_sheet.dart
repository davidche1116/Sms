import 'package:flutter/material.dart';

import '../../generated/app_localizations.dart';
import '../../models/sms_item.dart';
import 'keyword_presets.dart';
import 'quick_range.dart';

/// copyWith 的"不修改该字段"哨兵值。
const Object unset = Object();

/// 列表筛选条件。type：0 全部 / 1 仅收件箱 / 2 仅已发送（草稿归入发送侧）/ 3 仅彩信。
/// 不可变对象，通过 [copyWith] 生成新实例。
///
/// 时间维度有两种互斥写法：
/// - 自定义区间 [start] / [end]（[end] 按当天 23:59:59.999 闭区间）；
/// - 快捷预设 [quickRange]（「早于 N」，边界精确到毫秒 + [quickAnchor] 锚点快照）。
class SmsFilter {
  /// 手动输入的关键词（单串子串匹配）。
  final String keyword;

  /// 类别预设展开后的关键词组（组内 OR）；与 [keyword] 互斥。
  final List<String> keywordGroup;

  /// 类别预设；只用于 chip 文案与「是否与当前选中同一个」判定，匹配看 [keywordGroup]。
  final SmsKeywordPreset? preset;

  final DateTime? start;
  final DateTime? end;
  final int type;
  final String? sameAddress;
  final int? sameSim;

  /// 时间快捷预设；非空时忽略 [start] / [end]。
  final SmsQuickRange? quickRange;

  /// 应用 [quickRange] 的时刻快照：翻页复用同一边界，避免 `DateTime.now()`
  /// 在 `load()` 与 `loadMore()` 之间漂移导致列表抖动。
  final DateTime? quickAnchor;

  const SmsFilter({
    this.keyword = '',
    this.keywordGroup = const <String>[],
    this.preset,
    this.start,
    this.end,
    this.type = 0,
    this.sameAddress,
    this.sameSim,
    this.quickRange,
    this.quickAnchor,
  });

  bool get active =>
      keyword.isNotEmpty ||
      keywordGroup.isNotEmpty ||
      quickRange != null ||
      start != null ||
      end != null ||
      type != 0 ||
      sameAddress != null ||
      sameSim != null;

  /// 生效起始时间：快捷预设是「早于 N」语义，起始侧不设限。
  DateTime? get effectiveStart => quickRange == null ? start : null;

  /// 生效截止时间：快捷预设按锚点精确计算，不套「当天 23:59:59.999」。
  DateTime? get effectiveEnd => quickRange == null
      ? end
      : cutoffOf(quickRange!, quickAnchor ?? DateTime.now());

  /// true 表示 [effectiveEnd] 已是精确毫秒边界，不要再扩到当天末尾。
  bool get endExact => quickRange != null;

  /// 类别预设的关键词组（下推给原生做 OR 匹配）；手动关键词仍走 [keyword] 单值通道。
  List<String> get presetKeywordsForQuery => keywordGroup;

  /// 应用时间快捷预设：顺手清掉自定义区间并快照锚点（两者互斥）。
  SmsFilter withQuickRange(SmsQuickRange range, DateTime anchor) {
    return copyWith(
      quickRange: range,
      quickAnchor: anchor,
      start: null,
      end: null,
    );
  }

  /// 应用类别预设：顺手清掉手动关键词（两者互斥）。
  SmsFilter withPreset(SmsKeywordPreset p, List<String> words) {
    return copyWith(preset: p, keywordGroup: words, keyword: '');
  }

  /// 返回一个新实例，仅修改指定字段。
  /// 使用 [unset] 表示"不修改该字段"，传 `null` 表示"清空该字段"。
  SmsFilter copyWith({
    Object? keyword = unset,
    Object? keywordGroup = unset,
    Object? preset = unset,
    Object? start = unset,
    Object? end = unset,
    Object? type = unset,
    Object? sameAddress = unset,
    Object? sameSim = unset,
    Object? quickRange = unset,
    Object? quickAnchor = unset,
  }) {
    return SmsFilter(
      keyword: keyword == unset ? this.keyword : keyword as String,
      keywordGroup: keywordGroup == unset
          ? this.keywordGroup
          : keywordGroup as List<String>,
      preset: preset == unset ? this.preset : preset as SmsKeywordPreset?,
      start: start == unset ? this.start : start as DateTime?,
      end: end == unset ? this.end : end as DateTime?,
      type: type == unset ? this.type : type as int,
      sameAddress: sameAddress == unset
          ? this.sameAddress
          : sameAddress as String?,
      sameSim: sameSim == unset ? this.sameSim : sameSim as int?,
      quickRange: quickRange == unset
          ? this.quickRange
          : quickRange as SmsQuickRange?,
      quickAnchor: quickAnchor == unset
          ? this.quickAnchor
          : quickAnchor as DateTime?,
    );
  }

  /// 单条是否命中筛选（不含隐藏列表）。可单测。
  bool matches(SmsItem e) {
    if (sameAddress != null && e.address != sameAddress) return false;
    if (sameSim != null && e.sim != sameSim) return false;
    // 类别预设：组内 OR。与原生 SQL 保持一致——SQLite LIKE 对 ASCII 大小写不敏感，
    // 所以两侧统一转小写，避免「ICBC」「OTP」之类在两端命中不一致。
    if (keywordGroup.isNotEmpty) {
      final body = e.body.toLowerCase();
      final address = e.address.toLowerCase();
      var hit = false;
      for (final k in keywordGroup) {
        final w = k.toLowerCase();
        if (body.contains(w) || address.contains(w)) {
          hit = true;
          break;
        }
      }
      if (!hit) return false;
    }
    final q = keyword.trim();
    if (q.isNotEmpty) {
      final body = e.body.toLowerCase();
      final address = e.address.toLowerCase();
      final k = q.toLowerCase();
      if (!body.contains(k) && !address.contains(k)) return false;
    }
    final st = effectiveStart;
    final en = effectiveEnd;
    if (st != null || en != null) {
      final d = e.date;
      if (d == null) return false;
      if (st != null && d.isBefore(st)) return false;
      if (en != null) {
        // 快捷预设已是精确毫秒边界；自定义结束日期按当天 23:59:59.999 闭区间
        final limit = endExact
            ? en
            : DateTime(en.year, en.month, en.day, 23, 59, 59, 999);
        if (d.isAfter(limit)) return false;
      }
    }
    switch (type) {
      case 1:
        if (e.kind != SmsKind.received) return false;
      case 2:
        if (e.kind == SmsKind.received) return false;
      case 3:
        if (!e.isMms) return false;
      default:
        break;
    }
    return true;
  }

  /// 供测试 / Chip 文案使用。
  static String fmtDate(DateTime? d) => d == null
      ? ''
      : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// 搜索 / 筛选弹层（单一入口，UI_DESIGN §6.3）。返回应用后的筛选；直接关闭返回 null。
Future<SmsFilter?> showFilterSheet(BuildContext context, SmsFilter current) {
  SmsFilter f = current;
  return showModalBottomSheet<SmsFilter>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      final l10n = AppLocalizations.of(ctx);
      // 键盘弹起时抬高弹层；按钮放固定底栏，永远完整可见（不进滚动区）。
      // Controller 在 StatefulBuilder 外创建一次，避免每次重建丢失光标位置。
      final keywordController = TextEditingController(text: f.keyword);
      return AnimatedPadding(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.85,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: StatefulBuilder(
                builder: (ctx, setLocal) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                l10n.searchFilter,
                                style: Theme.of(ctx).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: keywordController,
                                decoration: InputDecoration(
                                  labelText: l10n.keywordLabel,
                                  prefixIcon: const Icon(Icons.search),
                                ),
                                onChanged: (v) => setLocal(
                                  () => f = f.copyWith(
                                    keyword: v,
                                    // 手动输入与类别预设互斥
                                    preset: null,
                                    keywordGroup: const <String>[],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                l10n.keywordPresetLabel,
                                style: Theme.of(ctx).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final p in SmsKeywordPreset.values)
                                    FilterChip(
                                      label: Text(presetLabel(l10n, p)),
                                      selected: f.preset == p,
                                      onSelected: (_) => setLocal(() {
                                        if (f.preset == p) {
                                          f = f.copyWith(
                                            preset: null,
                                            keywordGroup: const <String>[],
                                          );
                                        } else {
                                          f = f.withPreset(
                                            p,
                                            presetKeywords(
                                              p,
                                              Localizations.localeOf(ctx),
                                            ),
                                          );
                                          keywordController.clear();
                                        }
                                      }),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                l10n.quickRangeLabel,
                                style: Theme.of(ctx).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final r in SmsQuickRange.values)
                                    FilterChip(
                                      label: Text(quickRangeLabel(l10n, r)),
                                      selected: f.quickRange == r,
                                      onSelected: (_) => setLocal(() {
                                        f = f.quickRange == r
                                            ? f.copyWith(
                                                quickRange: null,
                                                quickAnchor: null,
                                              )
                                            : f.withQuickRange(
                                                r,
                                                DateTime.now(),
                                              );
                                      }),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                l10n.quickRangeHint,
                                style: Theme.of(ctx).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      icon: const Icon(
                                        Icons.date_range_outlined,
                                      ),
                                      label: Text(
                                        f.start == null
                                            ? l10n.startDate
                                            : SmsFilter.fmtDate(f.start),
                                      ),
                                      onPressed: () async {
                                        final d = await showDatePicker(
                                          context: ctx,
                                          initialDate:
                                              f.start ?? DateTime.now(),
                                          firstDate: DateTime(2000),
                                          lastDate: DateTime(2100),
                                        );
                                        if (d != null) {
                                          setLocal(
                                            () => f = f.copyWith(
                                              start: d,
                                              // 自定义区间与快捷预设互斥
                                              quickRange: null,
                                              quickAnchor: null,
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      icon: const Icon(
                                        Icons.date_range_outlined,
                                      ),
                                      label: Text(
                                        f.end == null
                                            ? l10n.endDate
                                            : SmsFilter.fmtDate(f.end),
                                      ),
                                      onPressed: () async {
                                        final d = await showDatePicker(
                                          context: ctx,
                                          initialDate: f.end ?? DateTime.now(),
                                          firstDate: DateTime(2000),
                                          lastDate: DateTime(2100),
                                        );
                                        if (d != null) {
                                          setLocal(
                                            () => f = f.copyWith(
                                              end: d,
                                              quickRange: null,
                                              quickAnchor: null,
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<int>(
                                initialValue: f.type,
                                decoration: InputDecoration(
                                  labelText: l10n.typeLabel,
                                ),
                                items: [
                                  DropdownMenuItem(
                                    value: 0,
                                    child: Text(l10n.typeAll),
                                  ),
                                  DropdownMenuItem(
                                    value: 1,
                                    child: Text(l10n.typeInbox),
                                  ),
                                  DropdownMenuItem(
                                    value: 2,
                                    child: Text(l10n.typeSent),
                                  ),
                                  DropdownMenuItem(
                                    value: 3,
                                    child: Text(l10n.typeMms),
                                  ),
                                ],
                                onChanged: (v) => setLocal(
                                  () => f = f.copyWith(type: v ?? 0),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                keywordController.clear();
                                setLocal(() => f = const SmsFilter());
                              },
                              child: Text(l10n.reset),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: () {
                                // 收起键盘再回填，避免 IME 挡住动画
                                FocusScope.of(ctx).unfocus();
                                Navigator.pop(ctx, f);
                              },
                              child: Text(l10n.done),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
    },
  );
}
