import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sms/generated/app_localizations.dart';
import 'package:sms/services/csv_importer.dart';
import 'package:sms/services/sms_data_service.dart';
import 'package:sms/services/sms_repository.dart';

import 'helpers/app_channel.dart';

/// CSV 导入端到端：mock 通道新线协议 → CsvImportResult 字段与 toast 文案。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(clearAppChannelHandler);

  final zh = lookupAppLocalizations(const Locale('zh'));
  final en = lookupAppLocalizations(const Locale('en'));

  void mockInsert(Object? Function() respond) {
    setAppChannelHandler((call) async {
      if (call.method != 'insertSmsBatch') return null;
      return respond();
    });
  }

  /// 3 行可导入 CSV（表头 + 3 数据行）。
  const csv3 =
      'address,body,date,kind,sub_id\n'
      '10086,流量提醒,2026-09-26 11:02:00,received,1\n'
      '13800000000,已发送,2026-09-25 09:00:00,sent,1\n'
      '10010,草稿,2026-08-01 08:00:00,draft,2\n';

  group('CsvImporter.importText + importMessage', () {
    test('全成：已导入 3 / 3 条', () async {
      mockInsert(() {
        return {
          ChannelCodes.keyOk: true,
          ChannelCodes.keyInserted: 3,
          ChannelCodes.keyFailed: 0,
          ChannelCodes.keyErrors: <Map<String, Object?>>[],
        };
      });
      final r = await CsvImporter.importText(SmsRepository(), csv3);
      expect(r.ok, isTrue);
      expect(r.parsed, 3);
      expect(r.inserted, 3);
      expect(r.failed, 0);
      expect(r.rowErrors, isEmpty);
      expect(r.errorSummaryOf(zh), isEmpty);
      expect(importMessage(r, zh), '已导入 3 / 3 条');
    });

    test('部分成功：已导入 1 / 3 条（2 条失败）+ 错误摘要', () async {
      mockInsert(() {
        return {
          ChannelCodes.keyOk: true,
          ChannelCodes.keyInserted: 1,
          ChannelCodes.keyFailed: 2,
          ChannelCodes.keyErrors: [
            {
              ChannelCodes.keyIndex: 1,
              ChannelCodes.keyCode: ChannelCodes.insertErrorFailed,
              ChannelCodes.keyMessage: 'insert returned null',
            },
            {
              ChannelCodes.keyIndex: 2,
              ChannelCodes.keyCode: ChannelCodes.insertErrorUnknown,
              ChannelCodes.keyMessage: 'batch failed',
            },
          ],
        };
      });
      final r = await CsvImporter.importText(SmsRepository(), csv3);
      expect(r.ok, isTrue);
      expect(r.parsed, 3);
      expect(r.inserted, 1);
      expect(r.failed, 2);
      expect(r.rowErrors, hasLength(2));
      expect(r.rowErrors[0].index, 1);
      expect(r.rowErrors[1].code, ChannelCodes.insertErrorUnknown);
      expect(importMessage(r, zh), '已导入 1 / 3 条（2 条失败）');
      expect(r.errorSummaryOf(zh), contains('写入失败'));
      expect(r.errorSummaryOf(zh), contains('未知错误'));
    });

    test('非默认：toast 引导设默认，errorSummary 带 not_default', () async {
      mockInsert(() {
        return {
          ChannelCodes.keyOk: false,
          ChannelCodes.keyInserted: 0,
          ChannelCodes.keyFailed: 3,
          ChannelCodes.keyErrors: [
            {
              ChannelCodes.keyIndex: -1,
              ChannelCodes.keyCode: ChannelCodes.insertErrorNotDefault,
              ChannelCodes.keyMessage: 'not default sms app',
            },
          ],
        };
      });
      final r = await CsvImporter.importText(SmsRepository(), csv3);
      expect(r.ok, isFalse);
      expect(r.notDefault, isTrue);
      expect(r.error, isNull);
      expect(r.inserted, 0);
      expect(r.failed, 3);
      expect(importMessage(r, zh), '导入需先设为默认短信应用');
    });

    test('原生整批失败（非 not_default）：可重试文案', () async {
      mockInsert(() {
        return {
          ChannelCodes.keyOk: false,
          ChannelCodes.keyInserted: 0,
          ChannelCodes.keyFailed: 3,
          ChannelCodes.keyErrors: [
            {
              ChannelCodes.keyIndex: -1,
              ChannelCodes.keyCode: ChannelCodes.insertErrorUnknown,
              ChannelCodes.keyMessage: 'boom',
            },
          ],
        };
      });
      final r = await CsvImporter.importText(SmsRepository(), csv3);
      expect(r.ok, isFalse);
      expect(r.notDefault, isFalse);
      expect(r.error, CsvImportError.unknown);
      expect(importMessage(r, zh), '导入失败，请重试');
    });

    test('空 CSV → empty；错误摘要超 3 条截断', () async {
      final empty = await CsvImporter.importText(
        SmsRepository(),
        'address,body,date,kind,sub_id\n',
      );
      expect(empty.error, CsvImportError.empty);
      expect(importMessage(empty, zh), '导入失败：文件中没有可导入的短信');

      final many = CsvImportResult(
        parsed: 5,
        inserted: 0,
        failed: 5,
        rowErrors: [
          for (var i = 0; i < 5; i++)
            InsertRowError(index: i, code: 'failed', message: 'm$i'),
        ],
      );
      // 文案按 code 本地化，不再透出原生 message
      expect(many.errorSummaryOf(zh), contains('写入失败'));
      expect(many.errorSummaryOf(zh), isNot(contains('m0')));
      expect(many.errorSummaryOf(zh), contains('等 5 条'));
    });

    test('英文 locale 关键 toast 文案', () {
      expect(
        importMessage(const CsvImportResult(parsed: 3, inserted: 3), en),
        'Imported 3 / 3',
      );
      expect(
        importMessage(
          const CsvImportResult(
            parsed: 0,
            inserted: 0,
            error: CsvImportError.empty,
          ),
          en,
        ),
        'Import failed: No messages to import in this file',
      );
    });
  });
}
