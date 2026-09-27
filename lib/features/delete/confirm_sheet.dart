import 'package:flutter/material.dart';

/// 删除确认弹层（UI_DESIGN §6.4）：确认文案 + >3000 提示 + 弱进度。
/// 返回 true 表示用户点了确认且 onDone 已执行。
Future<bool> showConfirmDeleteSheet(
  BuildContext context,
  int count,
  Future<void> Function() onDone,
) async {
  if (count == 0) return false;
  var progress = 0;
  final done = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('删除短信？', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('将删除 $count 条短信。删除后不可恢复。'),
            if (count > 3000) ...[
              const SizedBox(height: 8),
              Text(
                '数量较大（>3000），删除可能需要更久。',
                style: TextStyle(color: Theme.of(ctx).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            if (progress > 0 && progress < count)
              Column(
                children: [
                  LinearProgressIndicator(value: progress / count),
                  const SizedBox(height: 8),
                  Text('已完成 $progress / $count'),
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
                    child: const Text('取消'),
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
                            await onDone();
                            if (ctx.mounted) Navigator.pop(ctx, true);
                          },
                    child: Text(
                      progress > 0 && progress < count ? '删除中…' : '确认删除',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return done ?? false;
}
