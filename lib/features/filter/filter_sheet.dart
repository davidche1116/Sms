import 'package:flutter/material.dart';

import '../../generated/app_localizations.dart';
import '../../models/sms_item.dart';

/// 列表筛选条件。type：0 全部 / 1 仅收件箱 / 2 仅已发送（草稿归入发送侧）/ 3 仅彩信。
class SmsFilter {
  String keyword = '';
  DateTime? start;
  DateTime? end;
  int type = 0;
  String? sameAddress;
  int? sameSim;

  bool get active =>
      keyword.isNotEmpty ||
      start != null ||
      end != null ||
      type != 0 ||
      sameAddress != null ||
      sameSim != null;

  void reset() {
    keyword = '';
    start = null;
    end = null;
    type = 0;
    sameAddress = null;
    sameSim = null;
  }

  /// 完整拷贝 [other] 的全部字段。新增字段只需改这里，避免回写时漏字段。
  void applyFrom(SmsFilter other) {
    keyword = other.keyword;
    start = other.start;
    end = other.end;
    type = other.type;
    sameAddress = other.sameAddress;
    sameSim = other.sameSim;
  }

  SmsFilter copy() => SmsFilter()..applyFrom(this);

  /// 单条是否命中筛选（不含隐藏列表）。可单测。
  bool matches(SmsItem e) {
    if (sameAddress != null && e.address != sameAddress) return false;
    if (sameSim != null && e.sim != sameSim) return false;
    final q = keyword.trim();
    if (q.isNotEmpty && !e.body.contains(q) && !e.address.contains(q)) {
      return false;
    }
    if (start != null || end != null) {
      final d = e.date;
      if (d == null) return false;
      if (start != null && d.isBefore(start!)) return false;
      if (end != null) {
        // 结束日期按当天 23:59:59.999 闭区间
        final endOfDay = DateTime(
          end!.year,
          end!.month,
          end!.day,
          23,
          59,
          59,
          999,
        );
        if (d.isAfter(endOfDay)) return false;
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
  final f = current.copy();
  return showModalBottomSheet<SmsFilter>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      final l10n = AppLocalizations.of(ctx);
      // 键盘弹起时抬高弹层；按钮放固定底栏，永远完整可见（不进滚动区）。
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
                builder: (ctx, setLocal) => Column(
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
                              decoration: InputDecoration(
                                labelText: l10n.keywordLabel,
                                prefixIcon: const Icon(Icons.search),
                              ),
                              onChanged: (v) => setLocal(() => f.keyword = v),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.date_range_outlined),
                                    label: Text(
                                      f.start == null
                                          ? l10n.startDate
                                          : SmsFilter.fmtDate(f.start),
                                    ),
                                    onPressed: () async {
                                      final d = await showDatePicker(
                                        context: ctx,
                                        initialDate: f.start ?? DateTime.now(),
                                        firstDate: DateTime(2000),
                                        lastDate: DateTime(2100),
                                      );
                                      if (d != null) {
                                        setLocal(() => f.start = d);
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.date_range_outlined),
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
                                      if (d != null) setLocal(() => f.end = d);
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
                              onChanged: (v) => setLocal(() => f.type = v ?? 0),
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
                            onPressed: () => setLocal(f.reset),
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
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
