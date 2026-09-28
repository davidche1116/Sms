import 'package:flutter/material.dart';

import '../../generated/app_localizations.dart';

/// 删除进度共享状态：弹层写入取消请求、读取已完成数；删除循环写入进度、读取取消。
///
/// 无状态机库：单向字段 + 一次 attach 通知，弹层用 `setState` 重绘。
class DeleteProgress {
  DeleteProgress(this.total);

  /// 目标总数（与确认弹层文案一致）。
  final int total;

  /// 已成功完成块的条数（顺序前缀）。
  int done = 0;

  /// 是否已开始删除（按下确认后即 true，首块完成前 done 仍可为 0）。
  bool started = false;

  /// 用户已请求停止；删除循环应在下一块前退出。
  bool cancelRequested = false;

  void Function()? _notify;

  void attach(void Function() notify) => _notify = notify;

  void start() {
    started = true;
    _notify?.call();
  }

  void report(int done) {
    this.done = done;
    _notify?.call();
  }

  void requestCancel() {
    if (cancelRequested) return;
    cancelRequested = true;
    _notify?.call();
  }

  /// 删除进行中（已开始且尚未走完）。
  bool get running => started && done < total;
}

/// 删除确认弹层（UI_DESIGN §6.4）：确认文案 + >3000 提示 + 真实分块进度 + 可取消。
///
/// [onDelete] 接收 [DeleteProgress]：用 `report` 上报真实进度，
/// 轮询 `cancelRequested` 响应停止（已发出的块不撤回，未发出的不再发）。
/// 返回「用户确认且至少删掉一条」；取消或零删除失败返回 false，调用方（如滑删）可据此回弹 UI。
Future<bool> showConfirmDeleteSheet(
  BuildContext context,
  int count,
  Future<bool> Function(DeleteProgress progress) onDelete,
) async {
  if (count == 0) return false;
  final progress = DeleteProgress(count);
  final done = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) {
        final l10n = AppLocalizations.of(ctx);
        progress.attach(() {
          if (ctx.mounted) setLocal(() {});
        });
        final running = progress.running;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.deleteSmsTitle,
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
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
                if (progress.started)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      LinearProgressIndicator(
                        value: count == 0 ? 1 : progress.done / count,
                      ),
                      const SizedBox(height: 8),
                      Text(l10n.deleteProgress(progress.done, count)),
                      if (progress.done > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          l10n.deleteCannotUndo(progress.done),
                          style: TextStyle(
                            color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: progress.started
                            ? (progress.cancelRequested
                                  ? null
                                  : () => progress.requestCancel())
                            : () => Navigator.pop(ctx, false),
                        child: Text(
                          progress.started
                              ? (progress.cancelRequested
                                    ? l10n.stoppingDelete
                                    : l10n.stopDelete)
                              : l10n.cancel,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Theme.of(ctx).colorScheme.error,
                        ),
                        onPressed: progress.started
                            ? null
                            : () async {
                                progress.start();
                                final ok = await onDelete(progress);
                                if (ctx.mounted) Navigator.pop(ctx, ok);
                              },
                        child: Text(
                          progress.started && running
                              ? l10n.deleting
                              : l10n.confirmDelete,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
  return done ?? false;
}
