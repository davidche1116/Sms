import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../generated/app_localizations.dart';
import '../models/sms_item.dart';
import 'sms_repository.dart';

/// 导出结果：文件与条数。
class CsvExportResult {
  const CsvExportResult({
    required this.file,
    required this.count,
    this.partial = false,
  });

  final File file;
  final int count;

  /// 导出过程中某页查询部分失败（MMS 富化或子箱查询），数据可能不完整。
  final bool partial;
}

/// 增量 CSV 写入器：打开文件、写表头、逐批追加、最后关闭。
///
/// 用于分页导出场景，避免一次性把所有条目加载到内存。
class CsvExportWriter {
  CsvExportWriter._(this._file, this._sink, this._l10n);

  final File _file;
  final IOSink _sink;
  final AppLocalizations? _l10n;
  int _count = 0;
  bool _closed = false;

  /// 打开文件并写入 BOM + 表头。
  static Future<CsvExportWriter> open({
    String tag = 'all',
    AppLocalizations? l10n,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final now = DateTime.now();
    final stamp =
        '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
    final file = File('${dir.path}/sms_${tag}_$stamp.csv');
    final sink = file.openWrite();
    sink.write('﻿address,body,date,kind,sub_id,is_mms\r\n');
    return CsvExportWriter._(file, sink, l10n);
  }

  /// 追加一批条目。
  void addItems(List<SmsItem> items) {
    if (_closed) throw StateError('writer already closed');
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
      final body = _l10n == null ? e.body : e.bodyOf(_l10n);
      _sink
        ..write(CsvExporter.escapeField(e.address))
        ..write(',')
        ..write(CsvExporter.escapeField(body))
        ..write(',')
        ..write(CsvExporter.escapeField(dateStr))
        ..write(',')
        ..write(e.kind.name)
        ..write(',')
        ..write(e.sim)
        ..write(',')
        ..write(e.isMms ? 1 : 0)
        ..write('\r\n');
      _count++;
    }
  }

  /// 将缓冲区数据刷到磁盘（不关闭文件）。
  Future<void> flush() async {
    if (_closed) throw StateError('writer already closed');
    await _sink.flush();
  }

  /// 关闭文件并返回结果。
  Future<CsvExportResult> finish({bool partial = false}) async {
    if (_closed) throw StateError('writer already closed');
    _closed = true;
    await _sink.flush();
    await _sink.close();
    // 部分失败时在文件头部插入注释行，提醒用户数据可能不完整
    if (partial) {
      try {
        final content = await _file.readAsString();
        const comment =
            '# WARNING: Export may be incomplete (partial query failure)\n';
        // 注释必须插在 BOM 之后：BOM 不在文件开头会让 Excel/WPS 失去 UTF-8
        // 检测（中文乱码），导入侧也只在位置 0 剥 BOM（表头会错成 ﻿address）。
        final hasBom = content.startsWith('﻿');
        await _file.writeAsString(
          hasBom ? '﻿$comment${content.substring(1)}' : comment + content,
        );
      } catch (_) {
        // 写入注释失败不影响导出结果
      }
    }
    // 清理历史导出文件，只保留最近 3 份
    try {
      final dir = _file.parent;
      final exportPattern = RegExp(r'^sms_[a-z]+_\d{14}\.csv$');
      final files = (await dir.list().toList()).whereType<File>().where((f) {
        final fileName = f.path.split(Platform.pathSeparator).last;
        return exportPattern.hasMatch(fileName);
      }).toList();
      files.sort(
        (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
      );
      const keepCount = 3;
      for (var i = keepCount; i < files.length; i++) {
        await files[i].delete();
      }
    } catch (_) {
      // 清理失败不影响导出
    }
    return CsvExportResult(file: _file, count: _count, partial: partial);
  }
}

/// CSV 导出 + 系统分享。写入应用文档目录（无需存储权限）。
///
/// 列：`address,body,date,kind,sub_id,is_mms`。
/// 彩信 `body` 为文本 part 摘要或本地化占位；导入侧**只重建短信**（见 [CsvImporter]）。
class CsvExporter {
  /// [items] 要导出的短信/彩信；[tag] 文件名标记（all / selected）。
  ///
  /// 分批写入（默认每批 500 条），批间 flush 并让出事件循环，
  /// 避免大数据量时阻塞 UI 并降低内存峰值。
  /// [onProgress] 可选进度回调（已写条数，总条数）。
  static Future<CsvExportResult> export(
    List<SmsItem> items, {
    String tag = 'all',
    AppLocalizations? l10n,
    int batchSize = 500,
    void Function(int written, int total)? onProgress,
  }) async {
    final writer = await CsvExportWriter.open(tag: tag, l10n: l10n);
    try {
      var written = 0;
      for (var i = 0; i < items.length; i += batchSize) {
        final end = (i + batchSize).clamp(0, items.length);
        writer.addItems(items.sublist(i, end));
        written = end;
        onProgress?.call(written, items.length);
        if (end < items.length) {
          await writer.flush();
          // 让出事件循环，允许进度 UI 更新
          await Future<void>.delayed(Duration.zero);
        }
      }
      return await writer.finish();
    } catch (_) {
      await writer.finish();
      rethrow;
    }
  }

  /// 分页导出：通过 [repo] 逐页查询并写入，避免全量加载到内存。
  ///
  /// [pageSize] 每页大小，默认 500。
  /// 若某页查询部分失败（MMS 富化或子箱查询），结果标记 [CsvExportResult.partial]
  /// 为 true，并在 CSV 文件头部写入警告注释。
  static Future<CsvExportResult> exportPaged(
    SmsRepository repo, {
    String tag = 'all',
    AppLocalizations? l10n,
    int pageSize = 500,
  }) async {
    final writer = await CsvExportWriter.open(tag: tag, l10n: l10n);
    try {
      var offset = 0;
      var anyPartial = false;
      while (true) {
        final page = await repo.queryPage(limit: pageSize, offset: offset);
        if (page.items.isEmpty) break;
        if (page.partial) anyPartial = true;
        writer.addItems(page.items);
        offset += page.items.length;
        if (!page.hasMore(offset, pageSize)) break;
      }
      return await writer.finish(partial: anyPartial);
    } catch (_) {
      await writer.finish();
      rethrow;
    }
  }

  /// 拉起系统分享面板。
  static Future<void> share(CsvExportResult r, AppLocalizations l10n) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(r.file.path)],
        text: l10n.exportedShareText(r.count),
      ),
    );
  }

  /// RFC 4180：含逗号/引号/换行的字段加引号，内部引号翻倍。
  ///
  /// 防 CSV 公式注入：以 `=`、`+`、`-`、`@` 开头的字段先加 `'` 前缀，
  /// 使 Excel/WPS 将其视为文本而非公式。**先于**加引号判断执行，
  /// 否则同时含逗号/引号/换行的恶意字段（如 `=HYPERLINK("a","b")`）会漏防。
  @visibleForTesting
  static String escapeField(String v) {
    var s = v;
    if (s.isNotEmpty &&
        (s.startsWith('=') ||
            s.startsWith('+') ||
            s.startsWith('-') ||
            s.startsWith('@'))) {
      s = "'$s";
    }
    final needs =
        s.contains(',') ||
        s.contains('"') ||
        s.contains('\n') ||
        s.contains('\r');
    if (needs) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }
}
