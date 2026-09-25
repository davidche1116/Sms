import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:sms_advanced/sms_advanced.dart';

/// UTF-8 字节顺序标记。
///
/// Excel / 记事本等工具不会默认按 UTF-8 解析无 BOM 的 CSV，中文正文会显示
/// 成乱码（旧版只能靠提示"请用 UTF-8 编码打开"来规避）。带 BOM 前缀即可
/// 让这些工具直接正确识别编码。
const String csvBom = '\uFEFF';

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
      m.isRead?.toString() ?? '',
      m.date?.toString() ?? '',
      m.dateSent?.toString() ?? '',
      // kind 可为 null（草稿等场景），state 非空有默认值。
      m.kind?.toString() ?? '',
      m.state.toString(),
    ]);
  }
  return csv.encode(headerAndDataList);
}

/// 落盘用的字节流：带 UTF-8 BOM 前缀，接收方无需手动选择编码。
List<int> encodeSmsCsvBytes(List<SmsMessage> messages) =>
    utf8.encode('$csvBom${buildSmsCsv(messages)}');
