import '../models/sms_item.dart';
import 'csv_exporter.dart';
import 'csv_importer.dart';
import 'sms_repository.dart';

/// 导出失败 / 空列表的统一 toast 文案。
const kExportFailedMessage = '导出失败，请重试';
const kExportEmptyMessage = '没有可导出的短信';

/// 导出全量短信 CSV 并拉起系统分享。
///
/// 必须覆盖全库，不能只用已加载分页。返回 null=成功（分享面板即反馈）；
/// 否则为统一 toast 文案。不外抛。
Future<String?> exportAll(SmsRepository repo) async {
  try {
    return await exportItems(await repo.queryAll());
  } catch (_) {
    return kExportFailedMessage;
  }
}

/// 导出指定条目并分享（多选导出用）。返回值语义同 [exportAll]。
Future<String?> exportItems(List<SmsItem> items, {String tag = 'all'}) async {
  try {
    if (items.isEmpty) return kExportEmptyMessage;
    final r = await CsvExporter.export(items, tag: tag);
    await CsvExporter.share(r);
    return null;
  } catch (_) {
    return kExportFailedMessage;
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
String importMessage(CsvImportResult r) {
  if (r.error == CsvImportError.cancelled) return '已取消导入';
  if (r.notDefault) return '导入需先设为默认短信应用';
  if (!r.ok) {
    // 未知/意外失败给可重试提示，其余用枚举自带文案。
    return r.error == null || r.error == CsvImportError.unknown
        ? '导入失败，请重试'
        : '导入失败：${r.error!.message}';
  }
  return '已导入 ${r.inserted} / ${r.parsed} 条';
}
