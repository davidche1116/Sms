import 'package:flutter/material.dart';

import '../../generated/app_localizations.dart';

/// 删除确认弹层（UI_DESIGN §6.4）：确认文案 + >3000 提示 + 弱进度。
/// [onDone] 返回是否真正删掉；弹层最终返回「用户确认且删除成功」。
/// 取消或删除失败均返回 false，调用方（如滑删）可据此回弹 UI。
Future<bool> showConfirmDeleteSheet(
  BuildContext context,
  int count,
  Future<bool> Function() onDone,
) async {
  if (count == 0) return false;
  var progress = 0;
  final done = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) {
        final l10n = AppLocalizations.of(ctx);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.deleteSmsTitle, style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(l10n.deleteSmsBody(count)),
              if (count > 3000) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.deleteLargeWarn,
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              if (progress > 0 && progress < count)
                Column(
                  children: [
                    LinearProgressIndicator(value: progress / count),
                    const SizedBox(height: 8),
                    Text(l10n.deleteProgress(progress, count)),
                  ],
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: progress > 0 && progress < count
                          ? null
                          : () => Navigator.pop(ctx, false),
                      child: Text(l10n.cancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(ctx).colorScheme.error,
                      ),
                      onPressed: progress > 0
                          ? null
                          : () async {
                              // 进度仅作提示；实际删除一次批量调用
                              setLocal(() => progress = 1);
                              final ok = await onDone();
                              if (ctx.mounted) Navigator.pop(ctx, ok);
                            },
                      child: Text(
                        progress > 0 && progress < count
                            ? l10n.deleting
                            : l10n.confirmDelete,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ),
  );
  return done ?? false;
}
