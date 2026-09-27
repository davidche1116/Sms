import 'package:flutter/material.dart';

import '../../generated/app_localizations.dart';

/// 首页「更多」菜单 Sheet：导出 / 导入 / 多选 / 申请权限。
Future<void> showMoreMenuSheet(
  BuildContext context, {
  required VoidCallback onExportAll,
  required VoidCallback onImportCsv,
  required VoidCallback onSelectMode,
  required VoidCallback onRequestPermission,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      final l10n = AppLocalizations.of(ctx);
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.ios_share),
              title: Text(l10n.exportAllCsv),
              onTap: () {
                Navigator.pop(ctx);
                onExportAll();
              },
            ),
            ListTile(
              leading: const Icon(Icons.upload_file_outlined),
              title: Text(l10n.importCsv),
              subtitle: Text(l10n.importCsvHint),
              onTap: () {
                Navigator.pop(ctx);
                onImportCsv();
              },
            ),
            ListTile(
              leading: const Icon(Icons.checklist_outlined),
              title: Text(l10n.multiSelect),
              onTap: () {
                Navigator.pop(ctx);
                onSelectMode();
              },
            ),
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: Text(l10n.requestSmsPermission),
              onTap: () {
                Navigator.pop(ctx);
                onRequestPermission();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
