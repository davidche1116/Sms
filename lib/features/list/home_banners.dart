import 'package:flutter/material.dart';

import '../../generated/app_localizations.dart';
import '../filter/filter_sheet.dart';

/// MIUI「通知类短信」软提示横幅。
class MiuiNotifBanner extends StatelessWidget {
  const MiuiNotifBanner({
    super.key,
    required this.onOpenGuide,
    required this.onDismiss,
  });

  final VoidCallback onOpenGuide;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: const Color(0xFFE6A23C).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onOpenGuide,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: Color(0xFFE6A23C),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.miuiBanner,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                IconButton(
                  tooltip: l10n.dismissHint,
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onDismiss,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 查询部分失败软提示横幅：不阻断列表使用，点按重试（复用下拉刷新）。
class PartialQueryBanner extends StatelessWidget {
  const PartialQueryBanner({super.key, required this.onRetry, this.onDismiss});

  /// 重试：与下拉刷新同一条路径（`HomePage._load`）。
  final VoidCallback onRetry;

  /// 关闭横幅（本次会话内不再显示）；null = 不提供关闭。
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Theme.of(context).colorScheme.errorContainer
            .withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onRetry,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            child: Row(
              children: [
                Icon(
                  Icons.sync_problem_outlined,
                  color: Theme.of(context).colorScheme.error,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${l10n.partialQueryBanner}，${l10n.partialQueryBannerHint}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                if (onDismiss != null)
                  IconButton(
                    tooltip: l10n.dismissHint,
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: onDismiss,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 筛选条件 Chips 条：删除即通过 [onChanged] 回调新筛选实例。
class FilterChipsBar extends StatelessWidget {
  const FilterChipsBar({
    super.key,
    required this.filter,
    required this.onChanged,
  });

  final SmsFilter filter;
  final ValueChanged<SmsFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (filter.sameAddress != null)
            Chip(
              label: Text(l10n.sameAddressChip(filter.sameAddress!)),
              onDeleted: () => onChanged(filter.copyWith(sameAddress: null)),
              deleteIcon: const Icon(Icons.close, size: 18),
            ),
          if (filter.sameSim != null)
            Chip(
              label: Text(l10n.sameSimChip(filter.sameSim!)),
              onDeleted: () => onChanged(filter.copyWith(sameSim: null)),
              deleteIcon: const Icon(Icons.close, size: 18),
            ),
          if (filter.keyword.isNotEmpty)
            Chip(
              label: Text(l10n.keywordChip(filter.keyword)),
              onDeleted: () => onChanged(filter.copyWith(keyword: '')),
              deleteIcon: const Icon(Icons.close, size: 18),
            ),
          if (filter.start != null || filter.end != null)
            Chip(
              label: Text(
                '${SmsFilter.fmtDate(filter.start)} – ${SmsFilter.fmtDate(filter.end)}',
              ),
              onDeleted: () =>
                  onChanged(filter.copyWith(start: null, end: null)),
              deleteIcon: const Icon(Icons.close, size: 18),
            ),
          if (filter.type != 0)
            Chip(
              label: Text(switch (filter.type) {
                1 => l10n.typeInbox,
                2 => l10n.typeSent,
                3 => l10n.typeMms,
                _ => l10n.typeAll,
              }),
              onDeleted: () => onChanged(filter.copyWith(type: 0)),
              deleteIcon: const Icon(Icons.close, size: 18),
            ),
          ActionChip(
            label: Text(l10n.clearAllFilters),
            onPressed: () => onChanged(const SmsFilter()),
          ),
        ],
      ),
    );
  }
}
