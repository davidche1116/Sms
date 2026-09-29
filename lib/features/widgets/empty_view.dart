import 'package:flutter/material.dart';

import '../../generated/app_localizations.dart';

/// 空态三态：需要权限 / 筛选无果 / 没有短信（UI_DESIGN §6.6）。
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.filterActive,
    required this.onAction,
    this.needPermission = false,
    this.onSecondary,
  });

  final bool filterActive;
  final VoidCallback onAction;
  final bool needPermission;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Icon(
              needPermission
                  ? Icons.lock_outline
                  : filterActive
                  ? Icons.search_off_outlined
                  : Icons.inbox_outlined,
              size: 36,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            needPermission
                ? l10n.needPermissionTitle
                : filterActive
                ? l10n.noMatchTitle
                : l10n.emptyTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            needPermission
                ? l10n.needPermissionBody
                : filterActive
                ? l10n.noMatchBody
                : l10n.emptyBody,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: onAction,
            child: Text(
              needPermission
                  ? l10n.requestSmsPermission
                  : filterActive
                  ? l10n.clearFilters
                  : l10n.reload,
            ),
          ),
          if (needPermission && onSecondary != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onSecondary,
              child: Text(l10n.setDefaultForDelete),
            ),
          ],
        ],
      ),
    );

    // Sliver 里 LayoutBuilder 可能拿到无界高度；只在有界时做「撑满居中 + 可滚」。
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxH = constraints.maxHeight;
        final bounded = maxH.isFinite && maxH > 0;
        if (!bounded) return Center(child: content);
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: maxH),
            child: Center(child: content),
          ),
        );
      },
    );
  }
}
