import 'package:flutter/material.dart';

import '../../models/sms_item.dart';
import '../../services/csv_exporter.dart';
import '../../services/hidden_store.dart';
import '../../services/sms_repository.dart';
import '../delete/confirm_sheet.dart';
import '../filter/filter_sheet.dart';
import '../settings/settings_page.dart';
import '../widgets/empty_view.dart';
import 'action_sheet.dart';
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

  /// 本地移出列表的 id：不再展示，且 FAB 批量删除不会带上它们。
  final _hiddenIds = <int>{};
  final _repo = SmsRepository();
  final _hiddenStore = HiddenStore();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _hiddenIds.addAll(await _hiddenStore.load());
    if (!mounted) return;
    await _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _needPermission = false;
    });
    try {
      final list = await _repo.queryAll();
      if (!mounted) return;
      setState(() {
        items = list;
        _loading = false;
        _pruneSelection();
      });
    } on SmsQueryPermissionException {
      if (!mounted) return;
      setState(() {
        items = const [];
        _needPermission = true;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        items = const [];
        _loading = false;
      });
      _toast('查询失败，下拉或点重试');
    }
  }

  /// 刷新后把选中集裁剪到仍存在的 id，避免残留失效项。
  void _pruneSelection() {
    final ids = {for (final e in items) if (e.id != null) e.id!};
    _selected.removeWhere((id) => !ids.contains(id));
  }

  Future<void> _deleteIds(List<SmsItem> targets) async {
    final ids = [
      for (final e in targets)
        if (e.id != null) e.id!,
    ];
    if (ids.isEmpty) return;
    final n = await _repo.deleteSmsBatch(ids);
    if (!mounted) return;
    if (n == null) {
      // 失败不改 UI，列表保持原样
      _toast('删除失败：请先设为默认短信应用');
      return;
    }
    setState(() {
      items.removeWhere((e) => e.id != null && ids.contains(e.id));
      _selected.removeAll(ids);
      // 已删除的不再占用隐藏名额
      _hiddenIds.removeAll(ids);
      _pruneSelection();
    });
    _hiddenStore.save(_hiddenIds);
    _toast('已删除 $n 条');
    _load();
  }

  /// 客户端过滤：关键词 / 日期范围 / 类型 / 同号 / 同卡（不重复打库）。
  List<SmsItem> get _visible {
    final q = _filter.keyword.trim();
    return items.where((e) {
      if (e.id != null && _hiddenIds.contains(e.id)) return false;
      if (_filter.sameAddress != null && e.address != _filter.sameAddress) {
        return false;
      }
      if (_filter.sameSim != null && e.sim != _filter.sameSim) return false;
      if (q.isNotEmpty && !e.body.contains(q) && !e.address.contains(q)) {
        return false;
      }
      if (_filter.start != null || _filter.end != null) {
        final d = e.date;
        if (d == null) return false;
        if (_filter.start != null && d.isBefore(_filter.start!)) return false;
        if (_filter.end != null) {
          // 结束日期按当天 23:59:59.999 闭区间
          final end = DateTime(
            _filter.end!.year,
            _filter.end!.month,
            _filter.end!.day,
            23,
            59,
            59,
            999,
          );
          if (d.isAfter(end)) return false;
        }
      }
      switch (_filter.type) {
        case 1:
          if (e.kind != SmsKind.received) return false;
        case 2:
          if (e.kind == SmsKind.received) return false;
        default:
          break;
      }
      return true;
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
                    '${visible.length} 条',
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
              onPressed: () => _confirmDelete(visible),
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
                            : () => _confirmDelete(_selectedItems()),
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
            : ListView(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
                children: [
                  if (_filter.active)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (_filter.sameAddress != null)
                            Chip(
                              label: Text('同号 ${_filter.sameAddress}'),
                              onDeleted: () =>
                                  setState(() => _filter.sameAddress = null),
                              deleteIcon: const Icon(Icons.close, size: 18),
                            ),
                          if (_filter.sameSim != null)
                            Chip(
                              label: Text('同卡 ${_filter.sameSim}'),
                              onDeleted: () =>
                                  setState(() => _filter.sameSim = null),
                              deleteIcon: const Icon(Icons.close, size: 18),
                            ),
                          if (_filter.keyword.isNotEmpty)
                            Chip(
                              label: Text('“${_filter.keyword}”'),
                              onDeleted: () =>
                                  setState(() => _filter.keyword = ''),
                              deleteIcon: const Icon(Icons.close, size: 18),
                            ),
                          if (_filter.start != null || _filter.end != null)
                            Chip(
                              label: Text(
                                '${SmsFilter.fmtDate(_filter.start)} – ${SmsFilter.fmtDate(_filter.end)}',
                              ),
                              onDeleted: () => setState(() {
                                _filter.start = null;
                                _filter.end = null;
                              }),
                              deleteIcon: const Icon(Icons.close, size: 18),
                            ),
                          if (_filter.type != 0)
                            Chip(
                              label: Text(
                                _filter.type == 1 ? '仅收件箱' : '仅已发送',
                              ),
                              onDeleted: () => setState(() => _filter.type = 0),
                              deleteIcon: const Icon(Icons.close, size: 18),
                            ),
                          ActionChip(
                            label: const Text('清除全部'),
                            onPressed: () => setState(_filter.reset),
                          ),
                        ],
                      ),
                    ),
                  if (visible.isEmpty)
                    SizedBox(
                      height: MediaQuery.sizeOf(context).height * 0.55,
                      child: EmptyView(
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
                          if (r == 'had') {
                            _toast('已是默认短信应用');
                          } else if (r == 'no') {
                            _toast('请在系统弹窗中确认');
                          } else {
                            await _repo.openDefaultSmsSettings();
                          }
                          await _load();
                        },
                      ),
                    )
                  else
                    for (final e in visible)
                      Builder(
                        builder: (context) {
                          final index = visible.indexOf(e);
                          final showDay =
                              index == 0 ||
                              visible[index - 1].dayLabel != e.dayLabel;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (showDay)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    4,
                                    12,
                                    4,
                                    8,
                                  ),
                                  child: Text(
                                    e.dayLabel,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge,
                                  ),
                                ),
                              SmsCard(
                                item: e,
                                selectMode: _selectMode,
                                selected:
                                    e.id != null && _selected.contains(e.id),
                                onDelete: () => _deleteIds([e]),
                                onTap: () => _onItemTap(e),
                                onLongPress: () => _onItemLongPress(e),
                              ),
                            ],
                          );
                        },
                      ),
                ],
              ),
      ),
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
      onSameAddress: (addr) => setState(() => _filter.sameAddress = addr),
      onSameSim: (sim) => setState(() => _filter.sameSim = sim),
      onDelete: () => _deleteIds([e]),
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
      final targets = _selectedItems();
      if (targets.isEmpty) {
        _toast('没有可导出的短信');
        return;
      }
      final r = await CsvExporter.export(targets, tag: 'selected');
      await CsvExporter.share(r);
    } catch (_) {
      _toast('导出失败，请重试');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _openMenu() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.ios_share),
              title: const Text('导出全部 CSV'),
              onTap: () {
                Navigator.pop(ctx);
                _exportAll();
              },
            ),
            ListTile(
              leading: const Icon(Icons.checklist_outlined),
              title: const Text('多选'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _selectMode = true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('申请短信权限'),
              onTap: () {
                Navigator.pop(ctx);
                _requestPermission();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _exportAll() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      if (items.isEmpty) {
        _toast('没有可导出的短信');
        return;
      }
      final r = await CsvExporter.export(items);
      await CsvExporter.share(r);
    } catch (_) {
      _toast('导出失败，请重试');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _openFilter() async {
    final f = await showFilterSheet(context, _filter);
    if (f != null && mounted) {
      setState(() {
        _filter
          ..keyword = f.keyword
          ..start = f.start
          ..end = f.end
          ..type = f.type;
      });
    }
  }

  void _confirmDelete(List<SmsItem> targets) {
    if (targets.isEmpty) {
      _toast('没有可删除的短信');
      return;
    }
    showConfirmDeleteSheet(context, targets.length, () async {
      await _deleteIds(targets);
      if (mounted) setState(() => _selectMode = false);
    });
  }

  /// 申请读取短信权限（菜单 / 空态共用），结束后按结果刷新。
  Future<void> _requestPermission() async {
    final ok = await _repo.requestReadSms();
    if (!mounted) return;
    _toast(ok ? '已可读取短信' : '仍未获得权限，可到系统设置开启');
    await _load();
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
