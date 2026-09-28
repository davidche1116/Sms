import 'package:flutter/material.dart';

import '../../generated/app_localizations.dart';
import '../../models/sms_item.dart';
import '../../services/hidden_store.dart';
import '../../services/sms_data_service.dart';
import '../../services/sms_repository.dart';
import '../delete/confirm_sheet.dart';
import '../filter/filter_sheet.dart';
import '../settings/miui_notif_guide.dart';
import '../settings/settings_page.dart';
import '../widgets/empty_view.dart';
import 'action_sheet.dart';
import 'home_banners.dart';
import 'list_rows.dart';
import 'more_menu_sheet.dart';
import 'sms_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.seed,
    required this.mode,
    required this.onThemeChanged,
    this.locale,
    this.onLocaleChanged,
  });

  final Color seed;
  final ThemeMode mode;
  final void Function(Color? seed, ThemeMode? mode) onThemeChanged;

  /// 当前界面语言；null = 跟随系统。
  final Locale? locale;
  final void Function(Locale? locale)? onLocaleChanged;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<SmsItem> items = const [];
  final _filter = SmsFilter();

  /// 多选：只存跨 SMS/MMS 唯一的 `uid`（MMS 加偏移），避免同号 `_id` 互撞。
  final _selected = <int>{};
  bool _selectMode = false;
  bool _loading = true;
  bool _needPermission = false;
  bool _exporting = false;
  bool _miuiNotifHint = false;
  bool _miuiHintDismissed = false;

  /// 查询部分失败（partial=true）：顶栏轻提示，可重试，不阻断使用。
  bool _partial = false;
  bool _partialHintDismissed = false;

  /// 分页：启动/刷新先拉一页，滚动触底再追加（见 QUERY_DELETE_DESIGN §5.1）。
  static const _pageSize = 200;
  static const _loadMoreThreshold = 400.0;
  final _scrollController = ScrollController();
  bool _loadingMore = false;
  bool _hasMore = false;
  int? _total;

  /// 递增代际：刷新/重载后丢弃仍在途的下一页结果，避免旧页污染新列表。
  int _loadGen = 0;

  /// 本地移出列表的 uid：不再展示，且 FAB 批量删除不会带上它们。
  final _hiddenIds = <int>{};
  final _repo = SmsRepository();
  final _hiddenStore = HiddenStore();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _init();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    _hiddenIds.addAll(await _hiddenStore.load());
    if (!mounted) return;
    await _load();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < _loadMoreThreshold) {
      _loadMore();
    }
  }

  /// 首屏/追加后主动检查一次：内容不足一屏时不会产生滚动事件。
  void _scheduleLoadMoreCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _onScroll();
    });
  }

  Future<void> _load() async {
    final gen = ++_loadGen;
    setState(() {
      _loading = true;
      _needPermission = false;
      _loadingMore = false;
    });
    try {
      // 筛选是客户端过滤：激活时必须全量，否则结果只覆盖已加载页。
      final page = _filter.active
          ? await _allAsPage()
          : await _repo.queryPage(limit: _pageSize, offset: 0);
      if (!mounted || gen != _loadGen) return;
      // MIUI 通知类短信未开通时的软提示（申请流程里也会弹，这里是兜底）
      var hint = false;
      if (await _repo.isMiui()) {
        final st = await _repo.miuiNotificationSmsState();
        hint = switch (st) {
          MiuiNotifState.likelyOff ||
          MiuiNotifState.ignore ||
          MiuiNotifState.deny => true,
          _ => false,
        };
      }
      if (!mounted || gen != _loadGen) return;
      setState(() {
        items = _dedupByUid(page.items);
        _total = page.total;
        _hasMore = !_filter.active && page.hasMore(items.length, _pageSize);
        _loading = false;
        _miuiNotifHint = hint;
        _partial = page.partial;
        // 新一轮查询若已完整，之前的手动关闭自动复位，下次再 partial 仍会提示。
        if (!page.partial) _partialHintDismissed = false;
        _pruneSelection();
      });
      _scheduleLoadMoreCheck();
    } on SmsQueryPermissionException {
      if (!mounted || gen != _loadGen) return;
      setState(() {
        items = const [];
        _total = null;
        _hasMore = false;
        _needPermission = true;
        _loading = false;
        _partial = false;
      });
    } catch (_) {
      if (!mounted || gen != _loadGen) return;
      setState(() {
        items = const [];
        _total = null;
        _hasMore = false;
        _loading = false;
        _partial = false;
      });
      _toast(AppLocalizations.of(context).queryFailedRetry);
    }
  }

  /// 触底加载下一页，按 `_id` 去重后追加。
  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    final gen = _loadGen;
    setState(() => _loadingMore = true);
    try {
      final page = await _repo.queryPage(limit: _pageSize, offset: items.length);
      if (!mounted || gen != _loadGen) return;
      setState(() {
        final before = items.length;
        items = _dedupByUid([...items, ...page.items]);
        _total = page.total ?? _total;
        // 追加页也可能 partial（如彩信富化失败）：任一页不完整即整体标记。
        if (page.partial) _partial = true;
        // 没有新条目时强制停止，避免异常通道下反复空转
        _hasMore =
            items.length > before && page.hasMore(items.length, _pageSize);
      });
      _scheduleLoadMoreCheck();
    } catch (_) {
      // 加载更多失败保持现状，下次触底再试
    } finally {
      _loadingMore = false;
      if (mounted && gen == _loadGen) setState(() {});
    }
  }

  /// 按 `uid` 去重，保留首次出现的顺序（分页追加时防重复行；SMS/MMS 同号不互吞）。
  static List<SmsItem> _dedupByUid(List<SmsItem> source) {
    final seen = <int>{};
    return [
      for (final e in source)
        if (e.uid == null || seen.add(e.uid!)) e,
    ];
  }

  Future<SmsQueryPage> _allAsPage() async {
    // 直接走 queryPage：保留 partial/warnings（queryAll 会丢掉部分失败标记）。
    final page = await _repo.queryPage();
    final list = _dedupByUid(page.items);
    return SmsQueryPage(
      items: list,
      total: list.length,
      partial: page.partial,
      warnings: page.warnings,
    );
  }

  /// 筛选激活后补齐全量，保证客户端过滤结果完整；失败则退化为「基于已加载数据」。
  Future<void> _ensureFullForFilter() async {
    if (!_filter.active || !_hasMore) return;
    final gen = _loadGen;
    try {
      final page = await _allAsPage();
      if (!mounted || gen != _loadGen) return;
      setState(() {
        items = page.items;
        _total = page.total;
        _hasMore = false;
        if (page.partial) _partial = true;
        _pruneSelection();
      });
    } catch (_) {
      // 保留已加载数据，筛选只作用于已加载部分
    }
  }

  /// 筛选条件变化后的统一入口（弹层 / 同号 / 同卡 / Chips）。
  Future<void> _onFilterChangedWith(void Function() apply) async {
    if (!mounted) return;
    setState(apply);
    await _ensureFullForFilter();
  }

  /// 刷新后把选中集裁剪到仍存在的 uid，避免残留失效项。
  void _pruneSelection() {
    final uids = {for (final e in items) if (e.uid != null) e.uid!};
    _selected.removeWhere((id) => !uids.contains(id));
  }

  /// 删除并同步本地列表；返回「至少删掉一条」（供滑删决定是否划走）。
  ///
  /// 分块删除：某块失败即停，已删的从列表移除；取消同理（已发出的不撤回）。
  Future<bool> _deleteIds(List<SmsItem> targets, DeleteProgress progress) async {
    final l10n = AppLocalizations.of(context);
    final deletable = [for (final e in targets) if (e.id != null) e];
    if (deletable.isEmpty) return false;
    final r = await _repo.deleteSmsBatchChunked(
      deletable,
      onProgress: (done, total) => progress.report(done),
      shouldCancel: () => progress.cancelRequested,
    );
    if (!mounted) return r.deleted > 0;
    if (r.deleted > 0) {
      // 块按原序发出，前 r.deleted 项即已删（含失败块之前的完整前缀）。
      final uids = {
        for (final e in deletable.take(r.deleted))
          if (e.uid != null) e.uid!,
      };
      setState(() {
        items.removeWhere((e) => e.uid != null && uids.contains(e.uid));
        _selected.removeAll(uids);
        // 已删除的不再占用隐藏名额
        _hiddenIds.removeAll(uids);
        _pruneSelection();
        if (r.complete) _selectMode = false;
      });
      _hiddenStore.save(_hiddenIds);
    }
    if (r.complete) {
      _toast(l10n.deletedCount(r.deleted));
    } else if (r.reason == DeleteStopReason.failed) {
      if (r.deleted > 0) {
        // 部分成功：已删前缀保留，精确报数
        _toast(l10n.deletePartialFailed(r.deleted, r.total));
      } else if (r.failure == BatchFailure.notDefault ||
          r.failure == BatchFailure.notDefaultOrError) {
        // 明确非默认（或旧协议不可区分）：引导设默认
        _toast(l10n.deleteFailedNeedDefault);
      } else {
        // 原生异常等：不再误报「请先设为默认」
        _toast(l10n.deleteFailedRetry);
      }
    } else if (r.deleted > 0) {
      // 取消：已删的保留移除结果，明确报告条数
      _toast(l10n.deleteCancelled(r.deleted));
    }
    if (r.deleted > 0) _load();
    return r.deleted > 0;
  }

  /// 客户端过滤：关键词 / 日期范围 / 类型 / 同号 / 同卡（不重复打库）。
  List<SmsItem> get _visible {
    return items.where((e) {
      if (e.uid != null && _hiddenIds.contains(e.uid)) return false;
      return _filter.matches(e);
    }).toList();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final visible = _visible;
    final rows = buildListRows(visible, l10n);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: _selectMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  _selectMode = false;
                  _selected.clear();
                }),
              )
            : null,
        title: _selectMode
            ? Text(l10n.selectedCount(_selected.length))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.homeTitle),
                  Text(
                    _hasMore
                        ? (_total != null
                              ? l10n.loadedPartial(visible.length, _total!)
                              : l10n.loadedCount(visible.length))
                        : l10n.messageCount(visible.length),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
        actions: [
          if (_selectMode)
            TextButton(
              onPressed: () {
                // 全选针对当前筛选后的可见列表（INTERACTION §4.2）
                final uids = {
                  for (final e in visible)
                    if (e.uid != null) e.uid!,
                };
                setState(() {
                  if (uids.isNotEmpty && _selected.containsAll(uids)) {
                    _selected.clear();
                  } else {
                    _selected
                      ..clear()
                      ..addAll(uids);
                  }
                });
              },
              child: Text(l10n.selectAll, style: const TextStyle(color: Colors.white)),
            )
          else ...[
            IconButton(
              tooltip: l10n.searchFilter,
              icon: const Icon(Icons.search),
              onPressed: _openFilter,
            ),
            IconButton(
              tooltip: l10n.settings,
              icon: const Icon(Icons.settings_outlined),
              onPressed: _openSettings,
            ),
            IconButton(
              tooltip: l10n.more,
              icon: const Icon(Icons.more_vert),
              onPressed: _openMenu,
            ),
          ],
        ],
      ),
      floatingActionButton: _selectMode || visible.isEmpty
          ? null
          : FloatingActionButton(
              onPressed: () => _confirmAndDelete(visible),
              child: const Icon(Icons.delete_forever_outlined),
            ),
      bottomNavigationBar: _selectMode
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _selected.isEmpty || _exporting
                            ? null
                            : _exportSelected,
                        child: Text(l10n.exportSelected),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: scheme.error,
                        ),
                        onPressed: _selected.isEmpty
                            ? null
                            : () => _confirmAndDelete(_selectedItems()),
                        child: Text(l10n.deleteSelected),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                controller: _scrollController,
                slivers: [
                  if (_showMiuiHint || _showPartialHint || _filter.active)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_showMiuiHint)
                              MiuiNotifBanner(
                                onOpenGuide: () async {
                                  await showMiuiNotificationSmsSheet(context);
                                  await _load();
                                },
                                onDismiss: () =>
                                    setState(() => _miuiHintDismissed = true),
                              ),
                            if (_showPartialHint)
                              PartialQueryBanner(
                                onRetry: _load,
                                onDismiss: () => setState(
                                  () => _partialHintDismissed = true,
                                ),
                              ),
                            if (_filter.active)
                              FilterChipsBar(
                                filter: _filter,
                                onChanged: () => setState(() {}),
                              ),
                          ],
                        ),
                      ),
                    ),
                  if (visible.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          12,
                          (_showMiuiHint ||
                                  _showPartialHint ||
                                  _filter.active)
                              ? 0
                              : 8,
                          12,
                          88,
                        ),
                        child: SizedBox(
                          height: MediaQuery.sizeOf(context).height * 0.55,
                          child: _buildEmptyView(),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        12,
                        (_showMiuiHint || _showPartialHint || _filter.active)
                            ? 0
                            : 8,
                        12,
                        88,
                      ),
                      sliver: SliverList.builder(
                        itemCount: rows.length,
                        itemBuilder: (context, index) {
                          final row = rows[index];
                          return switch (row) {
                            DayRow(:final dayLabel) => Padding(
                              padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                              child: Text(
                                dayLabel,
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                            ),
                            SmsRow(:final item) => SmsCard(
                              item: item,
                              selectMode: _selectMode,
                              selected:
                                  item.uid != null &&
                                  _selected.contains(item.uid),
                              onDelete: () => _confirmAndDelete([item]),
                              onTap: () => _onItemTap(item),
                              onLongPress: () => _onItemLongPress(item),
                            ),
                          };
                        },
                      ),
                    ),
                  if (_loadingMore)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(12, 8, 12, 88),
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  bool get _showMiuiHint =>
      _miuiNotifHint && !_miuiHintDismissed && !_needPermission;

  /// 部分失败提示：不阻断列表，可关闭；权限态不显示（已有更强提示）。
  bool get _showPartialHint =>
      _partial && !_partialHintDismissed && !_needPermission;

  Widget _buildEmptyView() {
    return EmptyView(
      filterActive: _filter.active,
      needPermission: _needPermission,
      onAction: () async {
        if (_filter.active) {
          setState(_filter.reset);
        } else if (_needPermission) {
          await _requestPermission();
        } else {
          await _load();
        }
      },
      onSecondary: () async {
        // 引导设为默认，便于删除
        final l10n = AppLocalizations.of(context);
        final r = await _repo.setDefaultSms();
        if (!mounted) return;
        switch (r) {
          case DefaultSmsResult.alreadyDefault:
            _toast(l10n.alreadyDefaultSms);
          case DefaultSmsResult.requested:
            _toast(l10n.confirmInSystemDialog);
          case DefaultSmsResult.timeout:
            _toast(l10n.systemNoResult);
          case DefaultSmsResult.error:
            await _repo.openDefaultSmsSettings();
        }
        await _load();
      },
    );
  }

  void _onItemTap(SmsItem e) {
    if (_selectMode) {
      final uid = e.uid;
      if (uid == null) return; // 无 id 不允许选中（防御）
      setState(() {
        if (!_selected.remove(uid)) _selected.add(uid);
      });
      return;
    }
    showSmsActionSheet(
      context,
      e,
      onSameAddress: (addr) => _onFilterChangedWith(() {
        _filter.sameAddress = addr;
      }),
      onSameSim: (sim) => _onFilterChangedWith(() {
        _filter.sameSim = sim;
      }),
      onDelete: () => _confirmAndDelete([e]),
      onHide: () => _hideItem(e),
    );
  }

  void _onItemLongPress(SmsItem e) {
    if (!_selectMode) {
      final uid = e.uid;
      if (uid == null) return;
      setState(() {
        _selectMode = true;
        _selected.add(uid);
      });
    }
  }

  void _hideItem(SmsItem e) {
    final uid = e.uid;
    if (uid == null) return;
    setState(() => _hiddenIds.add(uid));
    _hiddenStore.save(_hiddenIds);
    _toast(AppLocalizations.of(context).removedFromList);
  }

  /// 当前选中项（按 `uid` 匹配，不依赖下标）。
  List<SmsItem> _selectedItems() => [
    for (final e in items)
      if (e.uid != null && _selected.contains(e.uid)) e,
  ];

  Future<void> _exportSelected() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _exporting = true);
    try {
      final msg = await exportItems(_selectedItems(), l10n, tag: 'selected');
      if (mounted && msg != null) _toast(msg);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _openMenu() {
    showMoreMenuSheet(
      context,
      onExportAll: _exportAll,
      onImportCsv: _importCsv,
      onSelectMode: () => setState(() => _selectMode = true),
      onRequestPermission: _requestPermission,
    );
  }

  Future<void> _exportAll() async {
    if (_exporting) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _exporting = true);
    try {
      final msg = await exportAll(_repo, l10n);
      if (mounted && msg != null) _toast(msg);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// 导入 CSV：只新增写入系统短信库，不覆盖、不删除。
  Future<void> _importCsv() async {
    if (_exporting) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _exporting = true);
    try {
      final r = await importCsv(_repo);
      if (!mounted) return;
      _toast(importMessage(r, l10n));
      if (r.ok) await _load();
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _openFilter() async {
    final f = await showFilterSheet(context, _filter);
    if (f != null && mounted) {
      // 完整应用返回值：弹层「重置」会清掉 sameAddress/sameSim，必须一并同步。
      await _onFilterChangedWith(() => _filter.applyFrom(f));
    }
  }

  /// 统一删除入口：确认弹层 → 分块删除。返回「确认且至少删掉一条」，滑删据此决定回弹。
  Future<bool> _confirmAndDelete(List<SmsItem> targets) async {
    // 无 id 行不可删：文案与进度分母只计真正会走通道的条目。
    final deletable = [for (final e in targets) if (e.id != null) e];
    if (deletable.isEmpty) {
      _toast(AppLocalizations.of(context).nothingToDelete);
      return false;
    }
    return showConfirmDeleteSheet(
      context,
      deletable.length,
      (progress) => _deleteIds(deletable, progress),
    );
  }

  /// 申请读取短信权限（菜单 / 空态共用）；MIUI 上成功后自动跟上通知类短信引导。
  Future<void> _requestPermission() async {
    await requestReadSmsWithMiuiGuide(context, _repo, onRefresh: _load);
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SettingsPage(
          seed: widget.seed,
          mode: widget.mode,
          onThemeChanged: widget.onThemeChanged,
          locale: widget.locale,
          onLocaleChanged: widget.onLocaleChanged,
          repo: _repo,
          hiddenStore: _hiddenStore,
          onDataChanged: _load,
        ),
      ),
    );
    if (mounted) {
      // 设置页可能重置了隐藏列表，重新读取
      _hiddenIds
        ..clear()
        ..addAll(await _hiddenStore.load());
      await _load();
    }
  }
}
