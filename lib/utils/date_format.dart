/// 短信时间戳的展示格式化。
///
/// 纯函数，不依赖 intl 的 locale 数据加载（在 widget 测试与部分 locale 下
/// `DateFormat` 可能因未调用 `initializeDateFormatting` 而回退英文），
/// 因此这里统一输出与语言无关的 `YYYY-MM-DD HH:mm` 形式，保证各语言下一致。
String formatSmsDate(DateTime? date) {
  if (date == null) {
    return '';
  }
  final String year = date.year.toString().padLeft(4, '0');
  final String month = date.month.toString().padLeft(2, '0');
  final String day = date.day.toString().padLeft(2, '0');
  final String hour = date.hour.toString().padLeft(2, '0');
  final String minute = date.minute.toString().padLeft(2, '0');
  return '$year-$month-$day $hour:$minute';
}

/// 复制到剪贴板的短信文本；可空字段写空串，避免出现 "null" 字面量。
String buildSmsClipboardText({String? address, DateTime? date, String? body}) {
  return '${address ?? ''}\r\n${formatSmsDate(date)}\r\n${body ?? ''}';
}
