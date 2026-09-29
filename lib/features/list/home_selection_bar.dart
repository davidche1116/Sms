import 'package:flutter/material.dart';

import '../../generated/app_localizations.dart';
import 'sms_list_controller.dart';

/// 多选模式底部操作栏。
class HomeSelectionBar extends StatelessWidget {
  const HomeSelectionBar({
    super.key,
    required this.controller,
    required this.onExport,
    required this.onDelete,
  });

  final SmsListController controller;
  final VoidCallback onExport;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: controller.selected.isEmpty || controller.exporting
                    ? null
                    : onExport,
                child: Text(l10n.exportSelected),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: scheme.error),
                onPressed: controller.selected.isEmpty ? null : onDelete,
                child: Text(l10n.deleteSelected),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
