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

/// 筛选条件 Chips 条：删除即改 [filter] 并回调 [onChanged]。
class FilterChipsBar extends StatelessWidget {
  const FilterChipsBar({
    super.key,
    required this.filter,
    required this.onChanged,
  });

  final SmsFilter filter;
  final VoidCallback onChanged;

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
              onDeleted: () {
                filter.sameAddress = null;
                onChanged();
              },
              deleteIcon: const Icon(Icons.close, size: 18),
            ),
          if (filter.sameSim != null)
            Chip(
              label: Text(l10n.sameSimChip(filter.sameSim!)),
              onDeleted: () {
                filter.sameSim = null;
                onChanged();
              },
              deleteIcon: const Icon(Icons.close, size: 18),
            ),
          if (filter.keyword.isNotEmpty)
            Chip(
              label: Text(l10n.keywordChip(filter.keyword)),
              onDeleted: () {
                filter.keyword = '';
                onChanged();
              },
              deleteIcon: const Icon(Icons.close, size: 18),
            ),
          if (filter.start != null || filter.end != null)
            Chip(
              label: Text(
                '${SmsFilter.fmtDate(filter.start)} – ${SmsFilter.fmtDate(filter.end)}',
              ),
              onDeleted: () {
                filter
                  ..start = null
                  ..end = null;
                onChanged();
              },
              deleteIcon: const Icon(Icons.close, size: 18),
            ),
          if (filter.type != 0)
            Chip(
              label: Text(
                filter.type == 1 ? l10n.typeInbox : l10n.typeSent,
              ),
              onDeleted: () {
                filter.type = 0;
                onChanged();
              },
              deleteIcon: const Icon(Icons.close, size: 18),
            ),
          ActionChip(
            label: Text(l10n.clearAllFilters),
            onPressed: () {
              filter.reset();
              onChanged();
            },
          ),
        ],
      ),
    );
  }
}
