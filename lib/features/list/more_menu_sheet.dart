import 'package:flutter/material.dart';

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
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.ios_share),
            title: const Text('导出全部 CSV'),
            onTap: () {
              Navigator.pop(ctx);
              onExportAll();
            },
          ),
          ListTile(
            leading: const Icon(Icons.upload_file_outlined),
            title: const Text('导入 CSV'),
            subtitle: const Text('写入系统短信库（需设为默认）'),
            onTap: () {
              Navigator.pop(ctx);
              onImportCsv();
            },
          ),
          ListTile(
            leading: const Icon(Icons.checklist_outlined),
            title: const Text('多选'),
            onTap: () {
              Navigator.pop(ctx);
              onSelectMode();
            },
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('申请短信权限'),
            onTap: () {
              Navigator.pop(ctx);
              onRequestPermission();
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
