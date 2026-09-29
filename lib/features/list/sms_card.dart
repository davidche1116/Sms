import 'package:flutter/material.dart';

import '../../generated/app_localizations.dart';
import '../../models/sms_item.dart';

/// 列表项卡片：左滑删除（确认 + 失败回弹）、单击/长按回调、多选态左侧勾选（UI_DESIGN §6.1）。
class SmsCard extends StatelessWidget {
  const SmsCard({
    super.key,
    required this.item,
    required this.onDelete,
    required this.onTap,
    required this.onLongPress,
    this.todayStart,
    this.selectMode = false,
    this.selected = false,
  });

  final SmsItem item;

  /// 确认并删除当前条；返回 true 才让卡片划走，false（取消/失败）回弹。
  final Future<bool> Function() onDelete;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  /// 今日零点（由列表层缓存并传入），保证同一次渲染内 today/yesterday 判定一致。
  final DateTime? todayStart;
  final bool selectMode;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final e = item;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: ValueKey('sms_${e.uid ?? e.hashCode}'),
        direction: selectMode
            ? DismissDirection.none
            : DismissDirection.endToStart,
        // 删除在 confirmDismiss 内完成：成功才划走，取消/失败卡片回弹
        confirmDismiss: (_) => onDelete(),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 22),
          decoration: BoxDecoration(
            color: scheme.error,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.delete_outline, color: Colors.white),
        ),
        child: Card(
          margin: EdgeInsets.zero,
          shape: selected
              ? RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: scheme.primary, width: 1.5),
                )
              : null,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            onLongPress: onLongPress,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (selectMode)
                    Padding(
                      padding: const EdgeInsets.only(right: 12, top: 2),
                      child: Icon(
                        selected
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: selected ? scheme.primary : scheme.outline,
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (e.isMms)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                _TypeBadge(
                                  label: l10n.mmsBadge,
                                  color: scheme.tertiary,
                                ),
                                if (e.hasMedia) ...[
                                  const SizedBox(width: 6),
                                  _TypeBadge(
                                    label: l10n.mmsHasAttachment,
                                    color: scheme.outline,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        Text(
                          e.bodyOf(l10n),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.primary.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                l10n.simBadge(e.sim),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: scheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                e.address,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                            Text(
                              e.time(todayStart: todayStart),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
