import 'dart:convert';

import 'package:file_picker/file_picker.dart';

import '../models/sms_item.dart';
import 'sms_repository.dart';

/// 一行待导入短信（与导出列一致：address,body,date,kind,sub_id）。
class SmsImportRow {
  const SmsImportRow({
    required this.address,
    required this.body,
    this.dateMs,
    required this.kind,
    this.sim = 1,
  });

  final String address;
  final String body;
  final int? dateMs;
  final SmsKind kind;
  final int sim;

  Map<String, Object?> toChannel() => {
    'address': address,
    'body': body,
    'date': dateMs,
    'type': switch (kind) {
      SmsKind.received => 1,
      SmsKind.draft => 3,
      SmsKind.sent => 2,
    },
    'sub_id': sim,
  };
}

class CsvImportResult {
  const CsvImportResult({
    required this.parsed,
    required this.inserted,
    this.error,
    this.notDefault = false,
  });

  final int parsed;
  final int inserted;
  final String? error;
  final bool notDefault;

  bool get ok => error == null && !notDefault;
}

/// CSV 导入：与 `CsvExporter` 同一格式（BOM + RFC 4180）。
class CsvImporter {
  /// 解析导出格式文本为行。忽略表头；`kind` 支持 received/sent/draft。
  static List<SmsImportRow> parse(String text) {
    var t = text;
    if (t.startsWith('﻿')) t = t.substring(1);
    final rows = <SmsImportRow>[];
    for (final fields in _parseCsv(t)) {
      if (fields.isEmpty) continue;
      // 表头
      if (fields.first.trim().toLowerCase() == 'address') continue;
      if (fields.length < 4) continue;
      final address = fields[0];
      final body = fields[1];
      final dateMs = _parseDateMs(fields[2]);
      final kind = _parseKind(fields[3]);
      final sim = fields.length > 4 ? (int.tryParse(fields[4].trim()) ?? 1) : 1;
      rows.add(
        SmsImportRow(
          address: address,
          body: body,
          dateMs: dateMs,
          kind: kind,
          sim: sim,
        ),
      );
    }
    return rows;
  }

  /// 选文件 → 解析 → 仅插入（绝不删除）。需本应用为默认短信应用。
  static Future<CsvImportResult> importViaPicker(SmsRepository repo) async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (file == null) {
      return const CsvImportResult(parsed: 0, inserted: 0, error: 'cancelled');
    }
    String text;
    try {
      final bytes = await file.readAsBytes();
      text = utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return const CsvImportResult(parsed: 0, inserted: 0, error: 'read_failed');
    }
    return importText(repo, text);
  }

  static Future<CsvImportResult> importText(
    SmsRepository repo,
    String text,
  ) async {
    final rows = parse(text);
    if (rows.isEmpty) {
      return const CsvImportResult(parsed: 0, inserted: 0, error: 'empty');
    }
    final r = await repo.insertSmsBatch([
      for (final e in rows) e.toChannel(),
    ]);
    if (r == null) {
      return CsvImportResult(
        parsed: rows.length,
        inserted: 0,
        notDefault: true,
      );
    }
    return CsvImportResult(parsed: rows.length, inserted: r);
  }

  static SmsKind _parseKind(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'sent':
        return SmsKind.sent;
      case 'draft':
        return SmsKind.draft;
      default:
        return SmsKind.received;
    }
  }

  static int? _parseDateMs(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    final d = DateTime.tryParse(s.replaceFirst(' ', 'T'));
    return d?.millisecondsSinceEpoch;
  }

  /// RFC 4180 解析（支持引号字段内的逗号/换行/转义引号）。
  static List<List<String>> _parseCsv(String text) {
    final rows = <List<String>>[];
    var row = <String>[];
    final buf = StringBuffer();
    var inQuotes = false;
    var i = 0;
    void endField() {
      row.add(buf.toString());
      buf.clear();
    }

    void endRow() {
      endField();
      rows.add(row);
      row = [];
    }

    while (i < text.length) {
      final c = text[i];
      if (inQuotes) {
        if (c == '"') {
          if (i + 1 < text.length && text[i + 1] == '"') {
            buf.write('"');
            i += 2;
            continue;
          }
          inQuotes = false;
          i++;
          continue;
        }
        buf.write(c);
        i++;
        continue;
      }
      if (c == '"') {
        inQuotes = true;
        i++;
        continue;
      }
      if (c == ',') {
        endField();
        i++;
        continue;
      }
      if (c == '\r') {
        i++;
        continue;
      }
      if (c == '\n') {
        endRow();
        i++;
        continue;
      }
      buf.write(c);
      i++;
    }
    if (buf.isNotEmpty || row.isNotEmpty) endRow();
    return rows;
  }
}
