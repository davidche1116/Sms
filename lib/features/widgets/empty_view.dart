import 'package:flutter/material.dart';

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
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
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
                  ? '需要短信权限'
                  : filterActive
                  ? '没有匹配的短信'
                  : '没有短信',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              needPermission
                  ? '授予读取短信权限后可浏览、搜索与导出；删除还需设为默认短信应用。'
                  : filterActive
                  ? '可以清除筛选后重试。'
                  : '下拉可重新加载。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onAction,
              child: Text(
                needPermission
                    ? '申请短信权限'
                    : filterActive
                    ? '清除筛选条件'
                    : '重新加载',
              ),
            ),
            if (needPermission && onSecondary != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onSecondary,
                child: const Text('设为默认短信应用（删除需要）'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
