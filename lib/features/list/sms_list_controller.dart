import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../generated/app_localizations.dart';
import '../../models/sms_item.dart';
import '../../services/hidden_store.dart';
import '../../services/sms_data_service.dart' as data_service;
import '../../services/sms_repository.dart';
import '../../utils/app_log.dart';
import '../delete/confirm_sheet.dart';
import '../filter/filter_sheet.dart';
import 'list_rows.dart';

/// 列表控制器：数据加载、分页、筛选、多选、删除编排。
///
/// 与 UI 解耦：不持有 BuildContext，所有 UI 反馈通过回调通知 HomePage。
/// 支持构造注入 [repo] 和 [hiddenStore] 以便测试；未提供时使用真实实例。
class SmsListController extends ChangeNotifier {
  final SmsRepository repo;
  final HiddenStore hiddenStore;

  SmsListController({SmsRepository? repo, HiddenStore? hiddenStore})
    : repo = repo ?? SmsRepository(),
      hiddenStore = hiddenStore ?? HiddenStore();

  // ---- 数据状态 ----
  List<SmsItem> items = const [];
  SmsFilter _filter = const SmsFilter();
  SmsFilter get filter => _filter;
  set filter(SmsFilter f) {
    _filter = f;
    notifyListeners();
  }

  final Set<int> selected = {};
  final Set<int> hiddenIds = {};
  bool selectMode = false;
  bool loading = true;
  bool needPermission = false;
  bool exporting = false;
  bool importing = false;
  bool miuiNotifHint = false;
  bool miuiHintDismissed = false;
  bool partial = false;
  bool partialHintDismissed = false;

  // ---- 分页 ----
  static const int pageSize = 200;
  bool loadingMore = false;
  bool hasMore = false;
  int? total;

  // ---- 代际：刷新/重载后丢弃仍在途的下一页结果 ----
  int _loadGen = 0;

  // ---- 今日零点缓存：一次渲染内 today/yesterday 判定一致 ----
  DateTime _todayStart = DateTime.now();
  DateTime get todayStart => _todayStart;

  void refreshTodayStartIfNeeded() {
    final now = DateTime.now();
    final newToday = DateTime(now.year, now.month, now.day);
    if (newToday != _todayStart) {
      _todayStart = newToday;
      notifyListeners();
    }
  }

  // ---- MIUI 探测 ----
  bool? _isMiui;

  // ---- 回调（由 HomePage 提供）----
  void Function(String)? onToast;
  void Function()? onShowMiuiGuide;
  Future<void> Function()? onRequestPermission;
  Future<void> Function()? onOpenSettings;

  Future<void> init() async {
    hiddenIds.addAll(await hiddenStore.load());
    notifyListeners();
    await load();
  }

  // ---- 筛选条件判断 ----
  bool get hasServerSideFilter =>
      filter.keyword.isNotEmpty ||
      filter.start != null ||
      filter.end != null ||
      filter.type != 0;

  bool get hasClientSideOnlyFilter =>
      (filter.sameSim != null || filter.sameAddress != null) &&
      !hasServerSideFilter;

  Map<String, Object?> _filterToQueryParams() {
    final params = <String, Object?>{};
    if (filter.keyword.isNotEmpty) {
      params['keyword'] = filter.keyword;
    }
    if (filter.start != null) {
      params['startDateMs'] = filter.start!.millisecondsSinceEpoch;
    }
    if (filter.end != null) {
      final endOfDay = DateTime(
        filter.end!.year,
        filter.end!.month,
        filter.end!.day,
        23,
        59,
        59,
        999,
      );
      params['endDateMs'] = endOfDay.millisecondsSinceEpoch;
    }
    if (filter.type != 0) {
      params['type'] = filter.type;
    }
    return params;
  }

  // ---- 数据加载 ----
  Future<void> load() async {
    final gen = ++_loadGen;
    loading = true;
    needPermission = false;
    loadingMore = false;
    notifyListeners();
    try {
      SmsQueryPage page;
      if (hasServerSideFilter) {
        final params = _filterToQueryParams();
        params['limit'] = pageSize;
        params['offset'] = 0;
        page = await repo.queryPage(
          address: params['address'] as String?,
          keyword: params['keyword'] as String?,
          startDateMs: params['startDateMs'] as int?,
          endDateMs: params['endDateMs'] as int?,
          type: params['type'] as int?,
          limit: params['limit'] as int?,
          offset: params['offset'] as int?,
        );
      } else if (hasClientSideOnlyFilter) {
        page = await _allAsPage();
      } else {
        page = await repo.queryPage(limit: pageSize, offset: 0);
      }
      if (gen != _loadGen) return;

      // MIUI 通知类短信探测
      var hint = false;
      _isMiui ??= await repo.isMiui();
      if (_isMiui == true) {
        final st = await repo.miuiNotificationSmsState();
        hint = switch (st) {
          MiuiNotifState.likelyOff ||
          MiuiNotifState.ignore ||
          MiuiNotifState.deny => true,
          _ => false,
        };
      }
      if (gen != _loadGen) return;

      items = _dedupByUid(page.items);
      total = page.total;
      hasMore = page.hasMore(items.length, pageSize);
      loading = false;
      miuiNotifHint = hint;
      partial = page.partial;
      if (!page.partial) partialHintDismissed = false;
      pruneSelection();
      notifyListeners();
    } on SmsQueryPermissionException {
      if (gen != _loadGen) return;
      items = const [];
      total = null;
      hasMore = false;
      needPermission = true;
      loading = false;
      partial = false;
      notifyListeners();
    } catch (_) {
      if (gen != _loadGen) return;
      items = const [];
      total = null;
      hasMore = false;
      loading = false;
      partial = false;
      notifyListeners();
      onToast?.call(''); // HomePage 负责取本地化文案
    }
  }

  Future<void> loadMore() async {
    if (loading || loadingMore || !hasMore) return;
    final gen = _loadGen;
    loadingMore = true;
    notifyListeners();
    try {
      SmsQueryPage page;
      if (hasServerSideFilter) {
        final params = _filterToQueryParams();
        params['limit'] = pageSize;
        params['offset'] = items.length;
        page = await repo.queryPage(
          address: params['address'] as String?,
          keyword: params['keyword'] as String?,
          startDateMs: params['startDateMs'] as int?,
          endDateMs: params['endDateMs'] as int?,
          type: params['type'] as int?,
          limit: params['limit'] as int?,
          offset: params['offset'] as int?,
        );
      } else {
        page = await repo.queryPage(limit: pageSize, offset: items.length);
      }
      if (gen != _loadGen) return;

      final before = items.length;
      items = _dedupByUid([...items, ...page.items]);
      total = page.total ?? total;
      if (page.partial) partial = true;
      hasMore = items.length > before && page.hasMore(items.length, pageSize);
      notifyListeners();
    } catch (e) {
      AppLog.e('loadMore failed', e);
      onToast?.call(''); // HomePage 负责取本地化文案（加载失败）
    } finally {
      loadingMore = false;
      if (gen == _loadGen) notifyListeners();
    }
  }

  static List<SmsItem> _dedupByUid(List<SmsItem> source) {
    final seen = <int>{};
    return [
      for (final e in source)
        if (e.uid == null || seen.add(e.uid!)) e,
    ];
  }

  Future<SmsQueryPage> _allAsPage() async {
    final page = await repo.queryPage();
    final list = _dedupByUid(page.items);
    return SmsQueryPage(
      items: list,
      total: list.length,
      partial: page.partial,
      warnings: page.warnings,
    );
  }

  Future<void> ensureFullForFilter() async {
    if (!hasClientSideOnlyFilter || !hasMore) return;
    final gen = _loadGen;
    try {
      final page = await _allAsPage();
      if (gen != _loadGen) return;
      items = page.items;
      total = page.total;
      hasMore = false;
      if (page.partial) partial = true;
      pruneSelection();
      notifyListeners();
    } catch (_) {
      // 保留已加载数据，筛选只作用于已加载部分
    }
  }

  Future<void> onFilterChangedWith(void Function() apply) async {
    // 变更前若是服务端过滤，items 只含匹配子集；即使变更后不再是服务端过滤
    // （如清空关键词 chip），也必须整库重载，否则列表残留旧子集。
    final wasServerSide = hasServerSideFilter;
    apply();
    notifyListeners();
    if (hasServerSideFilter || wasServerSide) {
      await load();
    } else {
      await ensureFullForFilter();
    }
  }

  void pruneSelection() {
    final uids = {
      for (final e in items)
        if (e.uid != null) e.uid!,
    };
    selected.removeWhere((id) => !uids.contains(id));
  }

  // ---- 删除 ----
  Future<bool> deleteIds(
    List<SmsItem> targets,
    DeleteProgress progress,
    AppLocalizations l10n,
  ) async {
    final deletable = [
      for (final e in targets)
        if (e.id != null) e,
    ];
    if (deletable.isEmpty) return false;
    final r = await repo.deleteSmsBatchChunked(
      deletable,
      onProgress: (done, total) => progress.report(done),
      shouldCancel: () => progress.cancelRequested,
    );
    if (r.deleted > 0) {
      final uids = {
        for (final e in deletable.take(r.deleted))
          if (e.uid != null) e.uid!,
      };
      items.removeWhere((e) => e.uid != null && uids.contains(e.uid));
      selected.removeAll(uids);
      hiddenIds.removeAll(uids);
      pruneSelection();
      if (r.complete) selectMode = false;
      notifyListeners();
      unawaited(hiddenStore.save(hiddenIds));
    }
    if (r.complete) {
      onToast?.call(l10n.deletedCount(r.deleted));
    } else if (r.reason == DeleteStopReason.failed) {
      if (r.deleted > 0) {
        onToast?.call(l10n.deletePartialFailed(r.deleted, r.total));
      } else if (r.failure == BatchFailure.notDefault ||
          r.failure == BatchFailure.notDefaultOrError) {
        onToast?.call(l10n.deleteFailedNeedDefault);
      } else {
        onToast?.call(l10n.deleteFailedRetry);
      }
    } else if (r.deleted > 0) {
      onToast?.call(l10n.deleteCancelled(r.deleted));
    }
    if (r.deleted > 0) unawaited(load());
    return r.deleted > 0;
  }

  // ---- 可见列表（过滤 + 行构建合并为一次遍历）----
  List<ListRow> computeRows(AppLocalizations l10n) {
    final rows = <ListRow>[];
    String? prevDay;
    for (final e in items) {
      if (e.uid != null && hiddenIds.contains(e.uid)) continue;
      if (!filter.matches(e)) continue;
      if (prevDay != e.dayKey) {
        rows.add(DayRow(e.dayLabelOf(l10n, todayStart: _todayStart)));
        prevDay = e.dayKey;
      }
      rows.add(SmsRow(e));
    }
    return rows;
  }

  List<SmsItem> selectedItems() => [
    for (final e in items)
      if (e.uid != null && selected.contains(e.uid)) e,
  ];

  // ---- 多选 ----
  void toggleSelectMode() {
    selectMode = !selectMode;
    if (!selectMode) selected.clear();
    notifyListeners();
  }

  void clearSelectMode() {
    selectMode = false;
    selected.clear();
    notifyListeners();
  }

  void toggleSelect(SmsItem e) {
    final uid = e.uid;
    if (uid == null) return;
    if (!selected.remove(uid)) selected.add(uid);
    notifyListeners();
  }

  void toggleSelectAll(List<SmsItem> visible) {
    final uids = {
      for (final e in visible)
        if (e.uid != null) e.uid!,
    };
    if (uids.isNotEmpty && selected.containsAll(uids)) {
      selected.clear();
    } else {
      selected
        ..clear()
        ..addAll(uids);
    }
    notifyListeners();
  }

  // ---- 隐藏 ----
  Future<void> hideItem(SmsItem e, AppLocalizations l10n) async {
    final uid = e.uid;
    if (uid == null) return;
    hiddenIds.add(uid);
    notifyListeners();
    unawaited(hiddenStore.save(hiddenIds));
    onToast?.call(l10n.removedFromList);
  }

  // ---- 导出/导入 ----
  Future<void> exportSelected(AppLocalizations l10n) async {
    exporting = true;
    notifyListeners();
    try {
      final msg = await data_service.exportItems(
        selectedItems(),
        l10n,
        tag: 'selected',
      );
      if (msg != null) onToast?.call(msg);
    } finally {
      exporting = false;
      notifyListeners();
    }
  }

  Future<void> exportAll(AppLocalizations l10n) async {
    if (exporting || importing) return;
    exporting = true;
    notifyListeners();
    try {
      final msg = await data_service.exportAll(repo, l10n);
      if (msg != null) onToast?.call(msg);
    } finally {
      exporting = false;
      notifyListeners();
    }
  }

  Future<void> importCsv(AppLocalizations l10n) async {
    if (exporting || importing) return;
    importing = true;
    notifyListeners();
    try {
      final r = await data_service.importCsv(repo);
      onToast?.call(data_service.importMessage(r, l10n));
      if (r.ok) await load();
    } finally {
      importing = false;
      notifyListeners();
    }
  }

  // ---- 权限 ----
  Future<void> requestPermission() async {
    await onRequestPermission?.call();
  }

  Future<void> openSettings() async {
    await onOpenSettings?.call();
  }

  void dismissMiuiHint() {
    miuiHintDismissed = true;
    notifyListeners();
  }

  void dismissPartialHint() {
    partialHintDismissed = true;
    notifyListeners();
  }
}
