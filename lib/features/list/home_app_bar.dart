import 'package:flutter/material.dart';

import '../../generated/app_localizations.dart';
import '../../models/sms_item.dart';
import 'sms_list_controller.dart';

/// 首页 AppBar：普通态与多选态。
class HomeAppBar extends StatelessWidget {
  const HomeAppBar({
    super.key,
    required this.controller,
    required this.visibleCount,
    required this.visibleItems,
    required this.onFilter,
    required this.onSettings,
    required this.onMenu,
  });

  final SmsListController controller;
  final int visibleCount;
  final List<SmsItem> visibleItems;
  final VoidCallback onFilter;
  final VoidCallback onSettings;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppBar(
      leading: controller.selectMode
          ? IconButton(
              icon: const Icon(Icons.close),
              onPressed: controller.clearSelectMode,
            )
          : null,
      title: controller.selectMode
          ? Text(l10n.selectedCount(controller.selected.length))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.homeTitle),
                Text(
                  controller.hasMore
                      ? (controller.total != null
                            ? l10n.loadedPartial(
                                visibleCount,
                                controller.total!,
                              )
                            : l10n.loadedCount(visibleCount))
                      : l10n.messageCount(visibleCount),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
      actions: [
        if (controller.selectMode)
          TextButton(
            onPressed: () => controller.toggleSelectAll(visibleItems),
            child: Text(
              l10n.selectAll,
              style: const TextStyle(color: Colors.white),
            ),
          )
        else ...[
          IconButton(
            tooltip: l10n.searchFilter,
            icon: const Icon(Icons.search),
            onPressed: onFilter,
          ),
          IconButton(
            tooltip: l10n.settings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: onSettings,
          ),
          IconButton(
            tooltip: l10n.more,
            icon: const Icon(Icons.more_vert),
            onPressed: onMenu,
          ),
        ],
      ],
    );
  }
}
