import 'package:flutter/material.dart';

import '../widgets/empty_view.dart';
import 'sms_list_controller.dart';

/// 空态视图：筛选中 / 无权限 / 无数据。
class HomeEmptyBody extends StatelessWidget {
  const HomeEmptyBody({
    super.key,
    required this.controller,
    required this.onAction,
    required this.onSecondary,
  });

  final SmsListController controller;
  final VoidCallback onAction;
  final VoidCallback onSecondary;

  @override
  Widget build(BuildContext context) {
    return EmptyView(
      filterActive: controller.filter.active,
      needPermission: controller.needPermission,
      onAction: onAction,
      onSecondary: onSecondary,
    );
  }
}
