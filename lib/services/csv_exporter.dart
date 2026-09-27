import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/sms_item.dart';

/// 导出结果：文件与条数。
class CsvExportResult {
  const CsvExportResult({required this.file, required this.count});

  final File file;
  final int count;
}

/// CSV 导出 + 系统分享。写入应用文档目录（无需存储权限）。
class CsvExporter {
  /// [items] 要导出的短信；[tag] 文件名标记（all / selected）。
  static Future<CsvExportResult> export(
    List<SmsItem> items, {
    String tag = 'all',
  }) async {
    final buf = StringBuffer('\uFEFFaddress,body,date,kind,sub_id\r\n');
    for (final e in items) {
      final d = e.date;
      final dateStr = d == null
          ? ''
          : '${d.year.toString().padLeft(4, '0')}-'
                '${d.month.toString().padLeft(2, '0')}-'
                '${d.day.toString().padLeft(2, '0')} '
                '${d.hour.toString().padLeft(2, '0')}:'
                '${d.minute.toString().padLeft(2, '0')}:'
                '${d.second.toString().padLeft(2, '0')}';
      buf
        ..write(_esc(e.address))
        ..write(',')
        ..write(_esc(e.body))
        ..write(',')
        ..write(_esc(dateStr))
        ..write(',')
        ..write(e.kind.name)
        ..write(',')
        ..write(e.sim)
        ..write('\r\n');
    }
    final dir = await getApplicationDocumentsDirectory();
    final now = DateTime.now();
    final stamp = '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
    final file = File('${dir.path}/sms_${tag}_$stamp.csv');
    await file.writeAsString(buf.toString());
    return CsvExportResult(file: file, count: items.length);
  }

  /// 拉起系统分享面板。
  static Future<void> share(CsvExportResult r) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(r.file.path)], text: '已导出 ${r.count} 条短信'),
    );
  }

  /// RFC 4180：含逗号/引号/换行的字段加引号，内部引号翻倍。
  static String _esc(String v) {
    final needs = v.contains(',') ||
        v.contains('"') ||
        v.contains('\n') ||
        v.contains('\r');
    if (!needs) return v;
    return '"${v.replaceAll('"', '""')}"';
  }
}
