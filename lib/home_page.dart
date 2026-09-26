import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'main.dart';
import 'services/sms_repository.dart';

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

class _Filter {
  String keyword = '';
  DateTime? start;
  DateTime? end;
  int type = 0;
  String? sameAddress;
  int? sameSim;

  bool get active =>
      keyword.isNotEmpty ||
      start != null ||
      end != null ||
      type != 0 ||
      sameAddress != null ||
      sameSim != null;

  void reset() {
    keyword = '';
    start = null;
    end = null;
    type = 0;
    sameAddress = null;
    sameSim = null;
  }
}

class _HomePageState extends State<HomePage> {
  late List<SmsItem> items;
  final _filter = _Filter();
  final _selected = <int>{};
  bool _selectMode = false;
  bool _loading = true;
  bool _needPermission = false;

  /// 本地移出列表的 id：不再展示，且 FAB 批量删除不会带上它们。
  final _hiddenIds = <int>{};
  final _repo = SmsRepository();

  @override
  void initState() {
    super.initState();
    items = const [];
    _load();
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
      });
    } on SmsQueryPermissionException {
      if (!mounted) return;
      setState(() {
        items = const [];
        _needPermission = true;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        items = const [];
        _loading = false;
      });
      _toast('查询失败，下拉或点重试');
    }
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
      items.removeWhere((e) => targets.contains(e));
      _selected.clear();
    });
    _toast('已删除 $n 条');
    _load();
  }

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
                setState(() {
                  if (_selected.length == items.length) {
                    _selected.clear();
                  } else {
                    _selected
                      ..clear()
                      ..addAll(List.generate(items.length, (i) => i));
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
      floatingActionButton: _selectMode
          ? null
          : FloatingActionButton(
              onPressed: () =>
                  _confirmDelete(visible, () => _deleteIds(visible)),
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
                        onPressed: () => _toast('已导出选中 CSV'),
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
                            : () {
                                final targets = [
                                  for (final i in _selected)
                                    if (i < items.length) items[i],
                                ];
                                _confirmDelete(targets, () async {
                                  await _deleteIds(targets);
                                  if (mounted) {
                                    setState(() => _selectMode = false);
                                  }
                                });
                              },
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
                                '${_fmtDate(_filter.start)} – ${_fmtDate(_filter.end)}',
                              ),
                              onDeleted: () => setState(() {
                                _filter.start = null;
                                _filter.end = null;
                              }),
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
                      child: _EmptyView(
                        filter: _filter,
                        needPermission: _needPermission,
                        onAction: () async {
                          if (_filter.active) {
                            setState(_filter.reset);
                          } else if (_needPermission) {
                            final ok = await _repo.requestReadSms();
                            if (!mounted) return;
                            if (ok) {
                              await _load();
                              _toast('已可读取短信');
                            } else {
                              _toast('仍未获得权限，可到系统设置开启');
                              await _load();
                            }
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
                    for (var index = 0; index < visible.length; index++)
                      Builder(
                        builder: (context) {
                          final e = visible[index];
                          final realIndex = items.indexOf(e);
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
                              _card(e, realIndex),
                            ],
                          );
                        },
                      ),
                ],
              ),
      ),
    );
  }

  String _fmtDate(DateTime? d) => d == null
      ? ''
      : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Widget _card(SmsItem e, int index) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _selected.contains(index);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: ValueKey('${e.address}_${e.time}_$index'),
        direction: DismissDirection.endToStart,
        onDismissed: (_) {
          // 快速删除：无撤销，直接删系统短信
          _deleteIds([e]);
        },
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 22),
          decoration: BoxDecoration(
            color: scheme.error,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.delete_outline, color: Colors.white),
        ),
        child: Card(
          margin: EdgeInsets.zero,
          shape: selected
              ? RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: scheme.primary, width: 1.5),
                )
              : null,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _onItemTap(e, index),
            onLongPress: () {
              if (!_selectMode) {
                setState(() {
                  _selectMode = true;
                  _selected.add(index);
                });
              }
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_selectMode)
                    Padding(
                      padding: const EdgeInsets.only(right: 12, top: 2),
                      child: Icon(
                        selected
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: selected ? scheme.primary : scheme.outline,
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.body,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.primary.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '卡${e.sim}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: scheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                e.address,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                            Text(
                              e.time,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onItemTap(SmsItem e, int index) {
    if (_selectMode) {
      setState(() {
        if (!_selected.remove(index)) _selected.add(index);
      });
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final pad = MediaQuery.paddingOf(ctx).bottom;
        return SizedBox(
          height: MediaQuery.sizeOf(ctx).height * 0.75,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 10, bottom: 4),
                child: SizedBox(
                  width: 36,
                  height: 4,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0xFFB0B8B3),
                      borderRadius: BorderRadius.all(Radius.circular(2)),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(0, 4, 0, pad + 12),
                  children: [
                    ListTile(
                      dense: true,
                      title: Text(
                        e.address,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text('卡${e.sim} · ${e.time}'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.tag),
                      title: const Text('同号短信'),
                      subtitle: const Text('只看这个号码的全部短信'),
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() => _filter.sameAddress = e.address);
                      },
                    ),
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.sim_card_outlined),
                      title: const Text('同卡短信'),
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() => _filter.sameSim = e.sim);
                      },
                    ),
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.copy_outlined),
                      title: const Text('复制号码'),
                      onTap: () {
                        Navigator.pop(ctx);
                        Clipboard.setData(ClipboardData(text: e.address));
                        _toast('已复制号码');
                      },
                    ),
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.copy_all_outlined),
                      title: const Text('复制正文'),
                      onTap: () {
                        Navigator.pop(ctx);
                        Clipboard.setData(ClipboardData(text: e.body));
                        _toast('已复制正文');
                      },
                    ),
                    ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.delete_outline,
                        color: Theme.of(ctx).colorScheme.error,
                      ),
                      title: Text(
                        '快速删除',
                        style: TextStyle(
                          color: Theme.of(ctx).colorScheme.error,
                        ),
                      ),
                      subtitle: const Text('删除这一条，不弹确认'),
                      onTap: () {
                        Navigator.pop(ctx);
                        _deleteIds([e]);
                      },
                    ),
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.visibility_off_outlined),
                      title: const Text('移出列表'),
                      subtitle: const Text('仅本地隐藏；悬浮球删除不会带上它们'),
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          if (e.id != null) _hiddenIds.add(e.id!);
                        });
                        _toast('已移出列表');
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
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
                _toast('已导出全部 CSV');
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
                _toast('已发起系统授权（演示）');
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _openFilter() async {
    final f = _Filter()
      ..keyword = _filter.keyword
      ..start = _filter.start
      ..end = _filter.end
      ..type = _filter.type;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.viewInsetsOf(ctx).bottom + 16,
        ),
        child: StatefulBuilder(
          builder: (ctx, setLocal) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('搜索 / 筛选', style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    labelText: '关键词',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setLocal(() => f.keyword = v),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.date_range_outlined),
                        label: Text(
                          f.start == null ? '开始日期' : _fmtDate(f.start),
                        ),
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: ctx,
                            initialDate: f.start ?? DateTime(2026, 9, 1),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (d != null) setLocal(() => f.start = d);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.date_range_outlined),
                        label: Text(f.end == null ? '结束日期' : _fmtDate(f.end)),
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: ctx,
                            initialDate: f.end ?? DateTime(2026, 9, 26),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (d != null) setLocal(() => f.end = d);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: f.type,
                  decoration: const InputDecoration(labelText: '类型'),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('全部')),
                    DropdownMenuItem(value: 1, child: Text('仅收件箱')),
                    DropdownMenuItem(value: 2, child: Text('仅已发送')),
                  ],
                  onChanged: (v) => setLocal(() => f.type = v ?? 0),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setLocal(f.reset),
                        child: const Text('重置'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          setState(() {
                            _filter
                              ..keyword = f.keyword
                              ..start = f.start
                              ..end = f.end
                              ..type = f.type;
                          });
                          Navigator.pop(ctx);
                          _toast('已应用筛选');
                        },
                        child: const Text('完成'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    List<SmsItem> targets,
    Future<void> Function() onDone,
  ) async {
    final count = targets.length;
    if (count == 0) {
      _toast('没有可删除的短信');
      return;
    }
    var progress = 0;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('删除短信？', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('将删除 $count 条短信。删除后不可恢复。'),
              if (count > 3000) ...[
                const SizedBox(height: 8),
                Text(
                  '数量较大（>3000），删除可能需要更久。',
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              if (progress > 0 && progress < count)
                Column(
                  children: [
                    LinearProgressIndicator(value: progress / count),
                    const SizedBox(height: 8),
                    Text('已完成 $progress / $count'),
                  ],
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: progress > 0 && progress < count
                          ? null
                          : () => Navigator.pop(ctx),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(ctx).colorScheme.error,
                      ),
                      onPressed: progress > 0
                          ? null
                          : () async {
                              // 进度仅作提示；实际删除一次批量调用
                              setLocal(() => progress = 1);
                              await onDone();
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                      child: Text(
                        progress > 0 && progress < count ? '删除中…' : '确认删除',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SettingsPage(
          seed: widget.seed,
          mode: widget.mode,
          onThemeChanged: widget.onThemeChanged,
          repo: _repo,
          onRepaired: _load,
        ),
      ),
    );
    if (mounted) await _load();
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({
    required this.filter,
    required this.onAction,
    this.needPermission = false,
    this.onSecondary,
  });

  final _Filter filter;
  final VoidCallback onAction;
  final bool needPermission;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Icon(
                needPermission
                    ? Icons.lock_outline
                    : filter.active
                    ? Icons.search_off_outlined
                    : Icons.inbox_outlined,
                size: 36,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              needPermission
                  ? '需要短信权限'
                  : filter.active
                  ? '没有匹配的短信'
                  : '没有短信',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              needPermission
                  ? '授予读取短信权限后可浏览、搜索与导出；删除还需设为默认短信应用。'
                  : filter.active
                  ? '可以清除筛选后重试。'
                  : '下拉可重新加载。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onAction,
              child: Text(
                needPermission
                    ? '申请短信权限'
                    : filter.active
                    ? '清除筛选条件'
                    : '重新加载',
              ),
            ),
            if (needPermission && onSecondary != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onSecondary,
                child: const Text('设为默认短信应用（删除需要）'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.seed,
    required this.mode,
    required this.onThemeChanged,
    required this.repo,
    this.onRepaired,
  });

  final Color seed;
  final ThemeMode mode;
  final void Function(Color? seed, ThemeMode? mode) onThemeChanged;
  final SmsRepository repo;
  final Future<void> Function()? onRepaired;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool? _hasRead;
  bool? _isDefault;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    final r = await widget.repo.hasReadSmsPermission();
    final d = await widget.repo.isDefaultSms();
    if (!mounted) return;
    setState(() {
      _hasRead = r;
      _isDefault = d;
    });
  }

  /// 已是默认时：明确提供「去系统设置换回系统短信」。
  Future<void> _onDefaultSmsRow() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_isDefault == true) {
      final go = await showModalBottomSheet<bool>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('已是默认短信应用'),
                subtitle: const Text('删除短信功能可用'),
              ),
              ListTile(
                leading: const Icon(Icons.settings_backup_restore),
                title: const Text('还原为系统短信'),
                subtitle: const Text('打开系统「默认应用」设置，手动选择「信息」'),
                onTap: () => Navigator.pop(ctx, true),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('保持现状'),
              ),
            ],
          ),
        ),
      );
      if (go != true) return;
      final r = await widget.repo.restoreDefaultSms();
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              r == 'settings'
                  ? '已打开系统默认应用设置，请选择其他短信应用'
                  : r == 'not_default'
                  ? '当前不是默认短信应用'
                  : '打开设置失败',
            ),
          ),
        );
    } else {
      final r = await widget.repo.setDefaultSms();
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              r == 'had'
                  ? '已是默认短信应用'
                  : r == 'no'
                  ? '请在系统弹窗中点「设为默认应用」'
                  : '已打开系统默认应用设置',
            ),
          ),
        );
      if (r == 'error') await widget.repo.openDefaultSmsSettings();
    }
    await _refreshStatus();
    await widget.onRepaired?.call();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _section(context, '外观'),
          _group([
            _row(
              icon: Icons.palette_outlined,
              iconBg: scheme.primary,
              title: '主题色',
              value: _seedName(widget.seed),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ThemePage(
                    seed: widget.seed,
                    onPick: (c) => widget.onThemeChanged(c, null),
                  ),
                ),
              ),
            ),
            _row(
              icon: Icons.dark_mode_outlined,
              iconBg: const Color(0xFF546E7A),
              title: '深色模式',
              value: switch (widget.mode) {
                ThemeMode.system => '跟随系统',
                ThemeMode.light => '浅色',
                ThemeMode.dark => '深色',
              },
              onTap: () => _pickMode(context),
            ),
          ]),
          _section(context, '权限'),
          _group([
            _row(
              icon: Icons.lock_outline,
              iconBg: const Color(0xFFE6A23C),
              title: '短信权限',
              subtitle: _hasRead == true
                  ? '已授予 · 用于读取与导出'
                  : _hasRead == false
                  ? '未授予 · 点击重新申请'
                  : '检查中…',
              trailing: Icon(
                _hasRead == true
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: _hasRead == true ? scheme.primary : scheme.outline,
                size: 20,
              ),
              onTap: () async {
                if (_hasRead != true) await widget.repo.requestReadSms();
                await _refreshStatus();
              },
            ),
            _row(
              icon: Icons.sms_outlined,
              iconBg: scheme.primary,
              title: '默认短信应用',
              subtitle: _isDefault == true
                  ? '本应用 · 点击可还原系统短信'
                  : _isDefault == false
                  ? '非本应用 · 点击设为默认（删除需要）'
                  : '检查中…',
              trailing: Icon(
                _isDefault == true
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: _isDefault == true ? scheme.primary : scheme.outline,
                size: 20,
              ),
              onTap: _onDefaultSmsRow,
            ),
          ]),
          _section(context, '数据'),
          _group([
            _row(
              icon: Icons.ios_share,
              iconBg: const Color(0xFF42A5F5),
              title: '导出短信 CSV',
              subtitle: '导出当前列表到文件并分享',
              onTap: () => _toast(context, '已导出全部短信 CSV'),
            ),
          ]),
          _section(context, '关于'),
          _group([
            _row(
              icon: Icons.info_outline,
              iconBg: const Color(0xFF8D6E63),
              title: '版本',
              value: '2.0.0',
            ),
            _row(
              icon: Icons.privacy_tip_outlined,
              iconBg: const Color(0xFF7E57C2),
              title: '隐私说明',
              subtitle: '数据仅在本机处理',
              onTap: () => _toast(context, '数据仅在本机处理，不上传、不收集'),
            ),
          ]),
          const SizedBox(height: 24),
          Center(
            child: Text(
              '短信清理 · 本地工具',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  String _seedName(Color c) {
    final argb = c.toARGB32();
    for (final p in kSeedPresets) {
      if (p.$2.toARGB32() == argb) return p.$1;
    }
    return '#${argb.toRadixString(16).substring(2).toUpperCase()}';
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickMode(BuildContext context) async {
    final m = await showModalBottomSheet<ThemeMode>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (label, value) in [
              ('跟随系统', ThemeMode.system),
              ('浅色', ThemeMode.light),
              ('深色', ThemeMode.dark),
            ])
              ListTile(
                title: Text(label),
                trailing: widget.mode == value ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(ctx, value),
              ),
          ],
        ),
      ),
    );
    if (m != null) widget.onThemeChanged(null, m);
  }

  Widget _section(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
    child: Text(
      title,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _group(List<Widget> children) => Card(
    margin: EdgeInsets.zero,
    child: Column(children: children),
  );

  Widget _row({
    required IconData icon,
    required Color iconBg,
    required String title,
    String? subtitle,
    String? value,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: iconBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing:
          trailing ??
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (value != null) Text(value),
              const Icon(Icons.chevron_right),
            ],
          ),
      onTap: onTap,
    );
  }
}

class ThemePage extends StatefulWidget {
  const ThemePage({super.key, required this.seed, required this.onPick});

  final Color seed;
  final ValueChanged<Color> onPick;

  @override
  State<ThemePage> createState() => _ThemePageState();
}

class _ThemePageState extends State<ThemePage> {
  late Color _color;
  late final TextEditingController _hex;

  @override
  void initState() {
    super.initState();
    _color = widget.seed;
    _hex = TextEditingController(text: _toHex(_color));
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  String _toHex(Color c) =>
      '#${c.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

  void _set(Color c) {
    setState(() {
      _color = c;
      _hex.text = _toHex(c);
    });
    widget.onPick(c);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('主题色')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            '选择强调色，立即作用于主按钮、选中项与图标。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Text('预设', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              for (final (name, color) in kSeedPresets)
                _swatch(name, color, color.toARGB32() == _color.toARGB32()),
            ],
          ),
          const SizedBox(height: 24),
          Text('自定义', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _color,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: scheme.outlineVariant),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _hex,
                          decoration: const InputDecoration(
                            labelText: '颜色值',
                            hintText: '#2BAE67',
                          ),
                          onChanged: (v) {
                            final c = _parseHex(v);
                            if (c != null) {
                              setState(() => _color = c);
                              widget.onPick(c);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () {
                      final c = _parseHex(_hex.text);
                      if (c == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('请输入合法颜色值，如 #2BAE67')),
                        );
                        return;
                      }
                      _set(c);
                    },
                    child: const Text('应用自定义颜色'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('预览', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(onPressed: () {}, child: const Text('主按钮示例')),
                  const SizedBox(height: 12),
                  const Wrap(
                    spacing: 8,
                    children: [
                      Chip(label: Text('筛选 Chip')),
                      Chip(label: Text('同号 10086')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _swatch(String name, Color color, bool selected) {
    return Tooltip(
      message: name,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => _set(color),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.onSurface
                  : Colors.transparent,
              width: 2.5,
            ),
          ),
          child: selected
              ? const Icon(Icons.check, color: Colors.white, size: 20)
              : null,
        ),
      ),
    );
  }

  Color? _parseHex(String v) {
    var s = v.trim();
    if (s.isEmpty) return null;
    if (s.startsWith('#')) s = s.substring(1);
    if (s.length == 3) {
      s = s.split('').map((c) => '$c$c').join();
    }
    if (s.length != 6) return null;
    final n = int.tryParse(s, radix: 16);
    if (n == null) return null;
    return Color(0xFF000000 | n);
  }
}

class PermissionPage extends StatelessWidget {
  const PermissionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('短信权限')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.check_circle, color: scheme.primary),
                  title: const Text('读取短信'),
                  subtitle: const Text('已授予'),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(
                    Icons.warning_amber_outlined,
                    color: Color(0xFFE6A23C),
                  ),
                  title: Text('默认短信'),
                  subtitle: Text('用于删除短信（可选）'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '未授予时无法读取短信列表。若系统曾收回权限，可重新申请。',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () {
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('已发起系统授权（演示）')));
            },
            child: const Text('申请短信权限'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('打开应用设置（演示）')));
            },
            child: const Text('打开应用设置'),
          ),
        ],
      ),
    );
  }
}
