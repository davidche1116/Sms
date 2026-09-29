import 'dart:convert';

import 'package:file_picker/file_picker.dart';

import '../generated/app_localizations.dart';
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

/// 导入失败原因（非通道协议，本地状态）。
enum CsvImportError {
  /// 用户取消选文件。
  cancelled,

  /// 文件读取 / 解码失败。
  readFailed,

  /// 解析后无有效行。
  empty,

  /// 其他未知失败。
  unknown;

  String messageOf(AppLocalizations l10n) => switch (this) {
    CsvImportError.cancelled => l10n.importCancelled,
    CsvImportError.readFailed => l10n.importReadFailed,
    CsvImportError.empty => l10n.importEmptyFile,
    CsvImportError.unknown => l10n.importUnknown,
  };
}

class CsvImportResult {
  const CsvImportResult({
    required this.parsed,
    required this.inserted,
    this.failed = 0,
    this.rowErrors = const [],
    this.error,
    this.notDefault = false,
  });

  /// 解析出的可导入行数（=提交给 insertSmsBatch 的行数）。
  final int parsed;

  /// 实际写入条数。
  final int inserted;

  /// 失败条数（部分成功时 >0）。
  final int failed;

  /// 逐行失败明细（index 对应 parse 后行下标）。
  final List<InsertRowError> rowErrors;

  final CsvImportError? error;
  final bool notDefault;

  bool get ok => error == null && !notDefault;

  /// 失败摘要（最多 3 条），供 toast/日志；无失败时为空串。
  /// 文案按 `code` 本地化，不透出原生 `message`（可能是系统异常英文）。
  String errorSummaryOf(AppLocalizations l10n) {
    if (rowErrors.isEmpty) return '';
    final shown = rowErrors
        .take(3)
        .map((e) => e.labelOf(l10n))
        .join(l10n.errorSummarySeparator);
    final more = rowErrors.length > 3
        ? l10n.errorSummaryMore(rowErrors.length)
        : '';
    return shown + more;
  }
}

/// CSV 导入：与 `CsvExporter` 同一格式（BOM + RFC 4180）。
///
/// **只重建短信**：带 `is_mms=1` 的行会被跳过（彩信含 smil/pdu/媒体，无法用
/// insertSmsBatch 还原）。旧 5 列格式无 `is_mms` 时按短信处理。
class CsvImporter {
  /// 解析导出格式文本为行。忽略表头；`kind` 支持 received/sent/draft。
  /// 彩信行（`is_mms=1`）直接丢弃，不进返回列表。
  static List<SmsImportRow> parse(String text) {
    var t = text;
    if (t.startsWith('﻿')) t = t.substring(1);
    final rows = <SmsImportRow>[];
    for (final fields in _parseCsv(t)) {
      if (fields.isEmpty) continue;
      // 表头
      if (fields.first.trim().toLowerCase() == 'address') continue;
      if (fields.length < 4) continue;
      // 可选 is_mms 列（第 6 列）：1 = 彩信，导入不重建
      if (fields.length > 5 && fields[5].trim() == '1') continue;
      final address = _unescapeFormulaPrefix(fields[0]);
      final body = _unescapeFormulaPrefix(fields[1]);
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
      return const CsvImportResult(
        parsed: 0,
        inserted: 0,
        error: CsvImportError.cancelled,
      );
    }
    String text;
    try {
      final bytes = await file.readAsBytes();
      text = utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return const CsvImportResult(
        parsed: 0,
        inserted: 0,
        error: CsvImportError.readFailed,
      );
    }
    return importText(repo, text);
  }

  static Future<CsvImportResult> importText(
    SmsRepository repo,
    String text,
  ) async {
    final rows = parse(text);
    if (rows.isEmpty) {
      return const CsvImportResult(
        parsed: 0,
        inserted: 0,
        error: CsvImportError.empty,
      );
    }
    final r = await repo.insertSmsBatch([for (final e in rows) e.toChannel()]);
    if (!r.ok) {
      // 非默认 → 引导设默认；其余原生整批失败 → 可重试。
      final notDefault =
          r.failure == BatchFailure.notDefault ||
          r.failure == BatchFailure.notDefaultOrError;
      return CsvImportResult(
        parsed: rows.length,
        inserted: r.inserted,
        failed: r.failed,
        rowErrors: r.errors,
        notDefault: notDefault,
        error: notDefault ? null : CsvImportError.unknown,
      );
    }
    return CsvImportResult(
      parsed: rows.length,
      inserted: r.inserted,
      failed: r.failed,
      rowErrors: r.errors,
    );
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

  /// 去除导出时为防止公式注入添加的 `'` 前缀。
  /// 仅当字段以 `'` 开头且下一字符为 `=`/`+`/`-`/`@` 时才去除。
  static String _unescapeFormulaPrefix(String v) {
    if (v.length >= 2 &&
        v.startsWith("'") &&
        (v[1] == '=' || v[1] == '+' || v[1] == '-' || v[1] == '@')) {
      return v.substring(1);
    }
    return v;
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
