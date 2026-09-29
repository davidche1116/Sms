import 'package:flutter/material.dart';

import '../filter/filter_sheet.dart';
import 'home_banners.dart';
import 'sms_list_controller.dart';

/// 顶部横幅区：MIUI 提示 / 部分失败提示 / 筛选 Chips。
class HomeBannerList extends StatelessWidget {
  const HomeBannerList({
    super.key,
    required this.controller,
    required this.onOpenMiuiGuide,
    required this.onDismissMiui,
    required this.onRetryPartial,
    required this.onDismissPartial,
    required this.onFilterChanged,
  });

  final SmsListController controller;
  final VoidCallback onOpenMiuiGuide;
  final VoidCallback onDismissMiui;
  final VoidCallback onRetryPartial;
  final VoidCallback onDismissPartial;
  final ValueChanged<SmsFilter> onFilterChanged;

  bool get showMiuiHint =>
      controller.miuiNotifHint &&
      !controller.miuiHintDismissed &&
      !controller.needPermission;

  bool get showPartialHint =>
      controller.partial &&
      !controller.partialHintDismissed &&
      !controller.needPermission;

  bool get showFilterChips => controller.filter.active;

  bool get hasAny => showMiuiHint || showPartialHint || showFilterChips;

  @override
  Widget build(BuildContext context) {
    if (!hasAny) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showMiuiHint)
            MiuiNotifBanner(
              onOpenGuide: onOpenMiuiGuide,
              onDismiss: onDismissMiui,
            ),
          if (showPartialHint)
            PartialQueryBanner(
              onRetry: onRetryPartial,
              onDismiss: onDismissPartial,
            ),
          if (showFilterChips)
            FilterChipsBar(
              filter: controller.filter,
              onChanged: onFilterChanged,
            ),
        ],
      ),
    );
  }
}
