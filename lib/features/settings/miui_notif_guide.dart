import 'package:flutter/material.dart';

import '../../generated/app_localizations.dart';
import '../../services/sms_repository.dart';

/// MIUI 通知类短信引导弹层的选择（null = 稍后再说 / 关闭）。
enum MiuiGuideAction {
  /// 去开启通知类短信（打开 MIUI 权限编辑页）。
  openMiui,
}

/// MIUI「通知类短信」引导弹层。返回 [MiuiGuideAction.openMiui] 或 null（稍后）。
///
/// 该权限是 MIUI 私有项，**无法**用系统 API 代为授权，只能跳转
/// 应用信息 → 权限管理 → 其他权限。申请 READ_SMS 成功后自动跟上这一步。
Future<MiuiGuideAction?> showMiuiNotificationSmsSheet(BuildContext context) {
  return showModalBottomSheet<MiuiGuideAction>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      final l10n = AppLocalizations.of(ctx);
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.primary
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.sms_failed_outlined, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.miuiGuideTitle,
                      style: Theme.of(ctx).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                l10n.miuiGuideBody,
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, MiuiGuideAction.openMiui),
                child: Text(l10n.openMiuiNotifSms),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.later),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// 申请读权限，成功后在 MIUI 上自动跟上「通知类短信」引导。
///
/// 返回是否拿到 READ_SMS。MIUI 引导不阻塞返回值。
/// 系统超时 / Activity 销毁未回包时 toast「系统未返回结果…」，
/// 不把超时误报成用户拒绝。
Future<bool> requestReadSmsWithMiuiGuide(
  BuildContext context,
  SmsRepository repo, {
  Future<void> Function()? onRefresh,
}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final r = await repo.requestReadSms();
  if (!context.mounted) return r == RequestReadSmsResult.granted;

  void toast(String msg, {int seconds = 2}) {
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          duration: Duration(seconds: seconds),
        ),
      );
  }

  switch (r) {
    case RequestReadSmsResult.timeout:
      toast(l10n.systemNoResult, seconds: 3);
      await onRefresh?.call();
      return false;
    case RequestReadSmsResult.denied:
      toast(l10n.stillNoPermission);
      await onRefresh?.call();
      return false;
    case RequestReadSmsResult.granted:
      break;
  }

  toast(l10n.smsReadable);

  // MIUI：私有权限无法自动授权，用引导弹层一键跳转。
  if (context.mounted && await repo.isMiui()) {
    final state = await repo.miuiNotificationSmsState();
    // allow=已开通；deny/ignore=未开通；unknown=探测不到也提示路径
    if (context.mounted && state != MiuiNotifState.allow) {
      final action = await showMiuiNotificationSmsSheet(context);
      if (action == MiuiGuideAction.openMiui && context.mounted) {
        await repo.openMiuiPermissionEditor();
      }
    }
  }

  await onRefresh?.call();
  return true;
}
