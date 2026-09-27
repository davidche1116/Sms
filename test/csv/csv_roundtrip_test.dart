import 'package:flutter_test/flutter_test.dart';
import 'package:sms/models/sms_item.dart';
import 'package:sms/services/csv_exporter.dart';
import 'package:sms/services/csv_importer.dart';

/// CSV 导出转义 / 导入解析 / 往返（RFC 4180）。
void main() {
  group('CsvExporter.escapeField（RFC 4180）', () {
    test('普通字段不加引号', () {
      expect(CsvExporter.escapeField('10086'), '10086');
      expect(CsvExporter.escapeField('你好'), '你好');
    });

    test('逗号 / 引号 / 换行需转义，内部引号翻倍', () {
      expect(CsvExporter.escapeField('a,b'), '"a,b"');
      expect(CsvExporter.escapeField('say "hi"'), '"say ""hi"""');
      expect(CsvExporter.escapeField('line1\nline2'), '"line1\nline2"');
      expect(CsvExporter.escapeField('a\r\nb'), '"a\r\nb"');
    });
  });

  group('CsvImporter 解析（与导出格式互逆）', () {
    test('表头 + 普通行 + BOM', () {
      final rows = CsvImporter.parse(
        '\u{FEFF}address,body,date,kind,sub_id\r\n'
        '10086,流量提醒,2026-09-26 11:02:00,received,1\r\n',
      );
      expect(rows, hasLength(1));
      expect(rows.first.address, '10086');
      expect(rows.first.body, '流量提醒');
      expect(rows.first.kind, SmsKind.received);
      expect(rows.first.sim, 1);
      expect(
        rows.first.dateMs,
        DateTime(2026, 9, 26, 11, 2).millisecondsSinceEpoch,
      );
    });

    test('RFC 4180 引号字段（逗号/换行/转义引号）', () {
      final rows = CsvImporter.parse(
        'address,body,date,kind,sub_id\n'
        '"10086","含,逗号与""引号""\n换行",2026-01-01 00:00:00,sent,2\n',
      );
      expect(rows, hasLength(1));
      expect(rows.first.body, '含,逗号与"引号"\n换行');
      expect(rows.first.kind, SmsKind.sent);
      expect(rows.first.sim, 2);
    });
  });

  group('导出 → 导入往返', () {
    test('含逗号/引号/换行的正文往返无损', () {
      final items = [
        const SmsItem(
          id: 1,
          address: '10086',
          body: 'a,b"c\nd',
          dateMs: 0,
          type: 1,
          sim: 1,
        ),
        const SmsItem(
          id: 2,
          address: '138',
          body: '已发送',
          dateMs: 0,
          type: 2,
          sim: 2,
        ),
      ];
      // 直接测 parse(escape 后的行)
      final buf = StringBuffer('address,body,date,kind,sub_id\n');
      for (final e in items) {
        buf
          ..write(CsvExporter.escapeField(e.address))
          ..write(',')
          ..write(CsvExporter.escapeField(e.body))
          ..write(',')
          ..write(CsvExporter.escapeField('2000-01-01 00:00:00'))
          ..write(',')
          ..write(e.kind.name)
          ..write(',')
          ..write(e.sim)
          ..write('\n');
      }
      final rows = CsvImporter.parse(buf.toString());
      expect(rows, hasLength(2));
      expect(rows[0].body, 'a,b"c\nd');
      expect(rows[0].kind, SmsKind.received);
      expect(rows[1].kind, SmsKind.sent);
      expect(rows[1].sim, 2);
    });
  });
}
