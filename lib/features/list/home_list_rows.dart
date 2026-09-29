import 'package:flutter/material.dart';

import '../../models/sms_item.dart';
import 'list_rows.dart';
import 'sms_card.dart';
import 'sms_list_controller.dart';

/// 列表行构建：日分组头 + 短信卡片。
class HomeListRows extends StatelessWidget {
  const HomeListRows({
    super.key,
    required this.controller,
    required this.visible,
    required this.rows,
    required this.onItemTap,
    required this.onItemLongPress,
    required this.onDelete,
  });

  final SmsListController controller;
  final List<SmsItem> visible;
  final List<ListRow> rows;
  final void Function(SmsItem) onItemTap;
  final void Function(SmsItem) onItemLongPress;
  final Future<bool> Function(SmsItem) onDelete;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
      sliver: SliverList.builder(
        itemCount: rows.length,
        itemBuilder: (context, index) {
          final row = rows[index];
          return switch (row) {
            DayRow(:final dayLabel) => Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
              child: Text(
                dayLabel,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            SmsRow(:final item) => SmsCard(
              item: item,
              todayStart: controller.todayStart,
              selectMode: controller.selectMode,
              selected:
                  item.uid != null && controller.selected.contains(item.uid),
              onDelete: () => onDelete(item),
              onTap: () => onItemTap(item),
              onLongPress: () => onItemLongPress(item),
            ),
          };
        },
      ),
    );
  }
}
