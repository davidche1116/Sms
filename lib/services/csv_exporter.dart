import 'package:csv/csv.dart';
import 'package:sms_advanced/sms_advanced.dart';

/// 将短信列表编码为含表头的 CSV 文本。
///
/// 纯函数，不接触文件系统与平台通道，可直接做单元测试；
/// 可空字段写空串而不是 "null" 字符串，保证导出数据干净。
String buildSmsCsv(List<SmsMessage> messages) {
  final List<List<String>> headerAndDataList = [
    const [
      'id',
      'threadId',
      'sim',
      'address',
      'body',
      'read',
      'date',
      'dateSent',
      'kind',
      'state',
    ],
  ];
  for (final SmsMessage m in messages) {
    headerAndDataList.add([
      m.id?.toString() ?? '',
      m.threadId?.toString() ?? '',
      m.sim?.toString() ?? '',
      m.address ?? '',
      m.body ?? '',
      m.isRead.toString(),
      m.date?.toString() ?? '',
      m.dateSent?.toString() ?? '',
      // kind 可为 null（草稿等场景），state 非空有默认值。
      m.kind?.toString() ?? '',
      m.state.toString(),
    ]);
  }
  return csv.encode(headerAndDataList);
}
