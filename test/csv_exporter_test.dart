import 'package:flutter_test/flutter_test.dart';
import 'package:sms/services/csv_exporter.dart';
import 'package:sms_advanced/sms_advanced.dart';

void main() {
  group('buildSmsCsv', () {
    test('首行为固定表头', () {
      final csv = buildSmsCsv([]);
      final lines = csv.split('\r\n');
      expect(
        lines.first,
        'id,threadId,sim,address,body,read,date,dateSent,kind,state',
      );
    });

    test('字段按列输出，kind/state 使用枚举文本', () {
      final message = SmsMessage(
        '10086',
        'hello world',
        id: 1,
        threadId: 2,
        sim: 0,
        read: true,
        date: DateTime(2026, 9, 1, 12, 30),
        dateSent: DateTime(2026, 9, 1, 12, 29),
        kind: SmsMessageKind.Received,
      );
      final csv = buildSmsCsv([message]);
      final lines = csv.split('\r\n');
      expect(lines.length, greaterThanOrEqualTo(2));
      expect(lines[1], startsWith('1,2,0,10086,hello world,true,'));
      expect(lines[1], contains('SmsMessageKind.Received'));
      expect(lines[1], contains('SmsMessageState.None'));
    });

    test('null 字段写空串而不是 "null"', () {
      final message = SmsMessage('10086', 'body', sim: 0);
      final csv = buildSmsCsv([message]);
      final lines = csv.split('\r\n');
      expect(lines[1], ',,0,10086,body,,,,,SmsMessageState.None');
      expect(csv, isNot(contains('null')));
    });

    test('落盘字节流带 UTF-8 BOM，Excel 可直接识别编码', () {
      final bytes = encodeSmsCsvBytes([SmsMessage('10086', '中文正文')]);
      expect(bytes.take(3), <int>[0xEF, 0xBB, 0xBF]);
    });

    test('正文含逗号/引号时正确转义', () {
      final message = SmsMessage('10086', 'say "hi", ok', id: 1);
      final csv = buildSmsCsv([message]);
      expect(csv, contains('"say ""hi"", ok"'));
    });
  });
}
