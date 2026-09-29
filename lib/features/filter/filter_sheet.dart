import 'package:flutter/material.dart';

import '../../generated/app_localizations.dart';
import '../../models/sms_item.dart';

/// copyWith 的"不修改该字段"哨兵值。
const Object unset = Object();

/// 列表筛选条件。type：0 全部 / 1 仅收件箱 / 2 仅已发送（草稿归入发送侧）/ 3 仅彩信。
/// 不可变对象，通过 [copyWith] 生成新实例。
class SmsFilter {
  final String keyword;
  final DateTime? start;
  final DateTime? end;
  final int type;
  final String? sameAddress;
  final int? sameSim;

  const SmsFilter({
    this.keyword = '',
    this.start,
    this.end,
    this.type = 0,
    this.sameAddress,
    this.sameSim,
  });

  bool get active =>
      keyword.isNotEmpty ||
      start != null ||
      end != null ||
      type != 0 ||
      sameAddress != null ||
      sameSim != null;

  /// 返回一个新实例，仅修改指定字段。
  /// 使用 [unset] 表示"不修改该字段"，传 `null` 表示"清空该字段"。
  SmsFilter copyWith({
    Object? keyword = unset,
    Object? start = unset,
    Object? end = unset,
    Object? type = unset,
    Object? sameAddress = unset,
    Object? sameSim = unset,
  }) {
    return SmsFilter(
      keyword: keyword == unset ? this.keyword : keyword as String,
      start: start == unset ? this.start : start as DateTime?,
      end: end == unset ? this.end : end as DateTime?,
      type: type == unset ? this.type : type as int,
      sameAddress: sameAddress == unset
          ? this.sameAddress
          : sameAddress as String?,
      sameSim: sameSim == unset ? this.sameSim : sameSim as int?,
    );
  }

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
                                onChanged: (v) =>
                                    setLocal(() => f = f.copyWith(keyword: v)),
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
                                            () => f = f.copyWith(start: d),
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
                                            () => f = f.copyWith(end: d),
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
