import 'package:flutter/material.dart';

import '../../services/sms_repository.dart';

/// MIUI「通知类短信」引导弹层。返回 `'open_miui'` 或 null（稍后）。
///
/// 该权限是 MIUI 私有项，**无法**用系统 API 代为授权，只能跳转
/// 应用信息 → 权限管理 → 其他权限。申请 READ_SMS 成功后自动跟上这一步。
Future<String?> showMiuiNotificationSmsSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
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
                    color: Theme.of(
                      ctx,
                    ).colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.sms_failed_outlined, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '还要开启「通知类短信」',
                    style: Theme.of(ctx).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'MIUI 将 10086、银行等通知短信单独管控。'
              '请在下一页打开：权限管理 → 其他权限 → 通知类短信。',
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'open_miui'),
              child: const Text('去开启通知类短信'),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('稍后再说'),
            ),
          ],
        ),
      ),
    ),
  );
}

/// 申请读权限，成功后在 MIUI 上自动跟上「通知类短信」引导。
///
/// 返回是否拿到 READ_SMS。MIUI 引导不阻塞返回值。
Future<bool> requestReadSmsWithMiuiGuide(
  BuildContext context,
  SmsRepository repo, {
  Future<void> Function()? onRefresh,
}) async {
  final ok = await repo.requestReadSms();
  if (!context.mounted) return ok;

  if (!ok) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(
          content: Text('仍未获得权限，可到系统设置开启'),
          duration: Duration(seconds: 2),
        ),
      );
    await onRefresh?.call();
    return ok;
  }

  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      const SnackBar(
        content: Text('已可读取短信'),
        duration: Duration(seconds: 2),
      ),
    );

  // MIUI：私有权限无法自动授权，用引导弹层一键跳转。
  if (context.mounted && await repo.isMiui()) {
    final state = await repo.miuiNotificationSmsState();
    // allow=已开通；deny/ignore=未开通；unknown=探测不到也提示路径
    if (context.mounted && state != 'allow') {
      final action = await showMiuiNotificationSmsSheet(context);
      if (action == 'open_miui' && context.mounted) {
        await repo.openMiuiPermissionEditor();
      }
    }
  }

  await onRefresh?.call();
  return ok;
}
