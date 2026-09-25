import 'package:sms_advanced/sms_advanced.dart';

/// 短信列表过滤/排序的纯函数集合：不依赖平台通道与 Flutter 上下文，
/// 可直接做单元测试，UI 层负责调用与展示。

/// 按关键词过滤短信正文；关键词为空时原样返回。
/// body 可能为 null（部分彩信/草稿无正文），null 一律视为不匹配。
List<SmsMessage> filterByKeyword(List<SmsMessage> messages, String keyword) {
  if (keyword.isEmpty) {
    return messages;
  }
  return messages
      .where((message) => message.body?.contains(keyword) ?? false)
      .toList();
}

/// 取当天零点。
DateTime startOfDay(DateTime date) => DateTime(date.year, date.month, date.day);

/// 取次日零点（用于构造左闭右开的日期区间上界，可越过月末/年末）。
DateTime startOfNextDay(DateTime date) =>
    DateTime(date.year, date.month, date.day + 1);

/// 按日期区间过滤（左闭右开语义：start <= date < end），
/// start/end 任一为空时原样返回。
///
/// 左闭是为了把起始日 00:00:00 的短信算进来；上界由调用方传
/// [startOfNextDay]，这样结束日 23:59:59.999 的短信也不会漏。
List<SmsMessage> filterByDateRange(
  List<SmsMessage> messages,
  DateTime? start,
  DateTime? end,
) {
  if (start == null || end == null) {
    return messages;
  }
  return messages.where((message) {
    final DateTime? date = message.date;
    if (date == null) {
      return false;
    }
    return !date.isBefore(start) && date.isBefore(end);
  }).toList();
}

/// 按同一 SIM 卡序号过滤；sim 为 null 时原样返回。
List<SmsMessage> filterBySim(List<SmsMessage> messages, int? sim) {
  if (sim == null) {
    return messages;
  }
  return messages.where((message) => message.sim == sim).toList();
}

/// date 为 null 时使用的哨兵时间（视为最早）。
///
/// 比较器会被调用 O(n log n) 次，不能在里面反复新建 DateTime。
final DateTime _nullDateSentinel = DateTime.fromMillisecondsSinceEpoch(0);

/// 按日期降序原地排序；date 为 null 的条目视为最早，排在末尾。
List<SmsMessage> sortByDateDesc(List<SmsMessage> messages) {
  messages.sort((a, b) {
    final DateTime aDate = a.date ?? _nullDateSentinel;
    final DateTime bDate = b.date ?? _nullDateSentinel;
    return bDate.compareTo(aDate);
  });
  return messages;
}
