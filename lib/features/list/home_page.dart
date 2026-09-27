import 'package:flutter/material.dart';

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
  });

  final Color seed;
  final ThemeMode mode;
  final void Function(Color? seed, ThemeMode? mode) onThemeChanged;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<SmsItem> items = const [];
  final _filter = SmsFilter();

  /// 多选：只存 `_id`，不存下标（设计 §4.3：id 一律用 _id）。
  final _selected = <int>{};
  bool _selectMode = false;
  bool _loading = true;
  bool _needPermission = false;
  bool _exporting = false;
  bool _miuiNotifHint = false;
  bool _miuiHintDismissed = false;

  /// 分页：启动/刷新先拉一页，滚动触底再追加（见 QUERY_DELETE_DESIGN §5.1）。
  static const _pageSize = 200;
  static const _loadMoreThreshold = 400.0;
  final _scrollController = ScrollController();
  bool _loadingMore = false;
  bool _hasMore = false;
  int? _total;

  /// 递增代际：刷新/重载后丢弃仍在途的下一页结果，避免旧页污染新列表。
  int _loadGen = 0;

  /// 本地移出列表的 id：不再展示，且 FAB 批量删除不会带上它们。
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
        items = _dedupById(page.items);
        _total = page.total;
        _hasMore = !_filter.active && page.hasMore(items.length, _pageSize);
        _loading = false;
        _miuiNotifHint = hint;
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
      });
    } catch (_) {
      if (!mounted || gen != _loadGen) return;
      setState(() {
        items = const [];
        _total = null;
        _hasMore = false;
        _loading = false;
      });
      _toast('查询失败，下拉或点重试');
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
        items = _dedupById([...items, ...page.items]);
        _total = page.total ?? _total;
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

  /// 按 `_id` 去重，保留首次出现的顺序（分页追加时防重复行）。
  static List<SmsItem> _dedupById(List<SmsItem> source) {
    final seen = <int>{};
    return [
      for (final e in source)
        if (e.id == null || seen.add(e.id!)) e,
    ];
  }

  Future<SmsQueryPage> _allAsPage() async {
    final list = _dedupById(await _repo.queryAll());
    return SmsQueryPage(items: list, total: list.length);
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

  /// 刷新后把选中集裁剪到仍存在的 id，避免残留失效项。
  void _pruneSelection() {
    final ids = {for (final e in items) if (e.id != null) e.id!};
    _selected.removeWhere((id) => !ids.contains(id));
  }

  /// 删除并同步本地列表；返回是否真正删掉（失败不改 UI）。
  Future<bool> _deleteIds(List<SmsItem> targets) async {
    final ids = [
      for (final e in targets)
        if (e.id != null) e.id!,
    ];
    if (ids.isEmpty) return false;
    final r = await _repo.deleteSmsBatch(ids);
    if (!mounted) return false;
    if (!r.ok) {
      // 失败不改 UI，列表保持原样
      _toast('删除失败：请先设为默认短信应用');
      return false;
    }
    setState(() {
      items.removeWhere((e) => e.id != null && ids.contains(e.id));
      _selected.removeAll(ids);
      // 已删除的不再占用隐藏名额
      _hiddenIds.removeAll(ids);
      _pruneSelection();
      _selectMode = false;
    });
    _hiddenStore.save(_hiddenIds);
    _toast('已删除 ${r.deleted} 条');
    _load();
    return true;
  }

  /// 客户端过滤：关键词 / 日期范围 / 类型 / 同号 / 同卡（不重复打库）。
  List<SmsItem> get _visible {
    return items.where((e) {
      if (e.id != null && _hiddenIds.contains(e.id)) return false;
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
    final visible = _visible;
    final rows = buildListRows(visible);
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
            ? Text('已选 ${_selected.length}')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('短信'),
                  Text(
                    _hasMore
                        ? (_total != null
                              ? '已加载 ${visible.length} / $_total 条'
                              : '已加载 ${visible.length} 条')
                        : '${visible.length} 条',
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
                final ids = {
                  for (final e in visible)
                    if (e.id != null) e.id!,
                };
                setState(() {
                  if (ids.isNotEmpty && _selected.containsAll(ids)) {
                    _selected.clear();
                  } else {
                    _selected
                      ..clear()
                      ..addAll(ids);
                  }
                });
              },
              child: const Text('全选', style: TextStyle(color: Colors.white)),
            )
          else ...[
            IconButton(
              tooltip: '搜索 / 筛选',
              icon: const Icon(Icons.search),
              onPressed: _openFilter,
            ),
            IconButton(
              tooltip: '设置',
              icon: const Icon(Icons.settings_outlined),
              onPressed: _openSettings,
            ),
            IconButton(
              tooltip: '更多',
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
                        child: const Text('导出选中'),
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
                        child: const Text('删除选中'),
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
                  if (_showMiuiHint || _filter.active)
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
                          (_showMiuiHint || _filter.active) ? 0 : 8,
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
                        (_showMiuiHint || _filter.active) ? 0 : 8,
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
                                  item.id != null &&
                                  _selected.contains(item.id),
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
        final r = await _repo.setDefaultSms();
        if (!mounted) return;
        switch (r) {
          case DefaultSmsResult.alreadyDefault:
            _toast('已是默认短信应用');
          case DefaultSmsResult.requested:
            _toast('请在系统弹窗中确认');
          case DefaultSmsResult.timeout:
            _toast('系统未返回结果，可在设置中手动开启');
          case DefaultSmsResult.error:
            await _repo.openDefaultSmsSettings();
        }
        await _load();
      },
    );
  }

  void _onItemTap(SmsItem e) {
    if (_selectMode) {
      final id = e.id;
      if (id == null) return; // 无 id 不允许选中（防御）
      setState(() {
        if (!_selected.remove(id)) _selected.add(id);
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
      final id = e.id;
      if (id == null) return;
      setState(() {
        _selectMode = true;
        _selected.add(id);
      });
    }
  }

  void _hideItem(SmsItem e) {
    final id = e.id;
    if (id == null) return;
    setState(() => _hiddenIds.add(id));
    _hiddenStore.save(_hiddenIds);
    _toast('已移出列表');
  }

  /// 当前选中项（按 `_id` 匹配，不依赖下标）。
  List<SmsItem> _selectedItems() => [
    for (final e in items)
      if (e.id != null && _selected.contains(e.id)) e,
  ];

  Future<void> _exportSelected() async {
    setState(() => _exporting = true);
    try {
      final msg = await exportItems(_selectedItems(), tag: 'selected');
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
    setState(() => _exporting = true);
    try {
      final msg = await exportAll(_repo);
      if (mounted && msg != null) _toast(msg);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// 导入 CSV：只新增写入系统短信库，不覆盖、不删除。
  Future<void> _importCsv() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final r = await importCsv(_repo);
      if (!mounted) return;
      _toast(importMessage(r));
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

  /// 统一删除入口：确认弹层 → 删除。返回「确认且删除成功」，滑删据此决定回弹。
  Future<bool> _confirmAndDelete(List<SmsItem> targets) async {
    if (targets.isEmpty) {
      _toast('没有可删除的短信');
      return false;
    }
    return showConfirmDeleteSheet(
      context,
      targets.length,
      () => _deleteIds(targets),
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
