import '../generated/app_localizations.dart';
import '../models/sms_item.dart';
import 'csv_exporter.dart';
import 'csv_importer.dart';
import 'sms_repository.dart';

/// 导出全量短信 CSV 并拉起系统分享。
///
/// 分页查询逐页写入，避免全量加载到内存。返回 null=成功（分享面板即反馈）；
/// 若导出过程中某页查询部分失败，返回部分失败警告文案；否则为统一 toast 文案。
/// 不外抛。
Future<String?> exportAll(SmsRepository repo, AppLocalizations l10n) async {
  try {
    final r = await CsvExporter.exportPaged(repo, tag: 'all', l10n: l10n);
    await CsvExporter.share(r, l10n);
    if (r.partial) {
      return l10n.exportPartialWarning;
    }
    return null;
  } catch (_) {
    return l10n.exportFailedRetry;
  }
}

/// 导出指定条目并分享（多选导出用）。返回值语义同 [exportAll]。
Future<String?> exportItems(
  List<SmsItem> items,
  AppLocalizations l10n, {
  String tag = 'all',
}) async {
  try {
    if (items.isEmpty) return l10n.exportEmpty;
    final r = await CsvExporter.export(items, tag: tag, l10n: l10n);
    await CsvExporter.share(r, l10n);
    return null;
  } catch (_) {
    return l10n.exportFailedRetry;
  }
}

/// 选文件导入 CSV：只新增写入系统短信库，不覆盖、不删除。
///
/// 意外异常收成 [CsvImportError.unknown]，不外抛；文案见 [importMessage]。
Future<CsvImportResult> importCsv(SmsRepository repo) async {
  try {
    return await CsvImporter.importViaPicker(repo);
  } catch (_) {
    return const CsvImportResult(
      parsed: 0,
      inserted: 0,
      error: CsvImportError.unknown,
    );
  }
}

/// 导入结果 → toast 文案的唯一出口。
///
/// 部分成功：「已导入 16 / 18 条（2 条失败）」；全成：「已导入 18 / 18 条」。
String importMessage(CsvImportResult r, AppLocalizations l10n) {
  if (r.error == CsvImportError.cancelled) return l10n.importCancelled;
  if (r.notDefault) return l10n.importNeedDefault;
  if (!r.ok) {
    // 未知/意外失败给可重试提示，其余用枚举自带文案。
    return r.error == null || r.error == CsvImportError.unknown
        ? l10n.importFailedRetry
        : l10n.importFailedWith(r.error!.messageOf(l10n));
  }
  if (r.failed > 0) {
    return l10n.importedPartial(r.inserted, r.parsed, r.failed);
  }
  return l10n.importedAll(r.inserted, r.parsed);
}
