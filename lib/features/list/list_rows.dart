import '../../models/sms_item.dart';

/// 列表扁平行：日分组头或短信卡片（`SliverList.builder` 懒加载）。
sealed class ListRow {
  const ListRow();
}

final class DayRow extends ListRow {
  const DayRow(this.dayLabel);
  final String dayLabel;
}

final class SmsRow extends ListRow {
  const SmsRow(this.item);
  final SmsItem item;
}

/// 扁平行：日头 + 卡片。构建前一次扫完，避免 builder 内 indexOf 的 O(n²)。
List<ListRow> buildListRows(List<SmsItem> visible) {
  final rows = <ListRow>[];
  String? prevDay;
  for (final e in visible) {
    if (prevDay != e.dayLabel) {
      rows.add(DayRow(e.dayLabel));
      prevDay = e.dayLabel;
    }
    rows.add(SmsRow(e));
  }
  return rows;
}
