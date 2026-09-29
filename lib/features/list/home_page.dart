import 'dart:async';

import 'package:flutter/material.dart';

import '../../generated/app_localizations.dart';
import '../../models/sms_item.dart';
import '../../services/hidden_store.dart';
import '../../services/sms_repository.dart';
import '../delete/confirm_sheet.dart';
import '../filter/filter_sheet.dart';
import '../settings/miui_notif_guide.dart';
import '../settings/settings_page.dart';
import '../widgets/app_messenger.dart';
import 'action_sheet.dart';
import 'home_app_bar.dart';
import 'home_banner_list.dart';
import 'home_empty_body.dart';
import 'home_list_rows.dart';
import 'home_selection_bar.dart';
import 'list_rows.dart';
import 'more_menu_sheet.dart';
import 'sms_list_controller.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.seed,
    required this.mode,
    required this.onThemeChanged,
    this.locale,
    this.onLocaleChanged,
    this.repo,
    this.hiddenStore,
  });

  final Color seed;
  final ThemeMode mode;
  final void Function(Color? seed, ThemeMode? mode) onThemeChanged;

  /// 当前界面语言；null = 跟随系统。
  final Locale? locale;
  final void Function(Locale? locale)? onLocaleChanged;

  /// 测试注入；null 时使用真实实例。
  final SmsRepository? repo;
  final HiddenStore? hiddenStore;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final SmsRepository _repo;
  late final HiddenStore _hiddenStore;
  late final SmsListController _controller;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _repo = widget.repo ?? SmsRepository();
    _hiddenStore = widget.hiddenStore ?? HiddenStore();
    _controller = SmsListController(repo: _repo, hiddenStore: _hiddenStore);
    _controller.onToast = _toast;
    _controller.onShowMiuiGuide = () async {
      await showMiuiNotificationSmsSheet(context);
      await _controller.load();
    };
    _controller.onRequestPermission = _requestPermission;
    _controller.onOpenSettings = _openSettings;
    _scrollController.addListener(_onScroll);
    unawaited(_controller.init());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 400.0) {
      unawaited(_controller.loadMore());
    }
  }

  // ---- 视口未填满时的主动补页 ----
  // 已加载项被隐藏/客户端过滤掏空时，可视行填不满视口，不会触发滚动事件，
  // 后续页将永远不可达（此时内容不可滚动，下拉刷新也随之失效）。
  bool _loadMoreCheckScheduled = false;

  /// 上次自动补页尝试时的条目数：数量未变（失败/无新增）就不再自动重试，
  /// 等用户滚动或刷新，避免失败重试风暴；整库重载（loading=true）时复位。
  int _lastFillAttemptCount = -1;

  void _scheduleLoadMoreCheck() {
    if (_loadMoreCheckScheduled) return;
    _loadMoreCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMoreCheckScheduled = false;
      if (!mounted || !_scrollController.hasClients) return;
      if (_controller.loading) {
        _lastFillAttemptCount = -1;
        return;
      }
      if (_scrollController.position.extentAfter >= 400.0) return;
      if (!_controller.hasMore || _controller.loadingMore) return;
      if (_controller.items.length == _lastFillAttemptCount) return;
      _lastFillAttemptCount = _controller.items.length;
      unawaited(_controller.loadMore());
    });
  }

  void _toast(String msg) {
    if (msg.isEmpty) msg = AppLocalizations.of(context).queryFailedRetry;
    AppMessenger.show(context, msg);
  }

  Future<void> _requestPermission() async {
    await requestReadSmsWithMiuiGuide(
      context,
      _repo,
      onRefresh: () => _controller.load(),
    );
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
          onDataChanged: () => _controller.load(),
        ),
      ),
    );
    if (mounted) {
      _controller.hiddenIds
        ..clear()
        ..addAll(await _hiddenStore.load());
      await _controller.load();
    }
  }

  void _openFilter() async {
    final f = await showFilterSheet(context, _controller.filter);
    if (f != null && mounted) {
      await _controller.onFilterChangedWith(() => _controller.filter = f);
    }
  }

  void _openMenu() {
    unawaited(
      showMoreMenuSheet(
        context,
        onExportAll: () => _controller.exportAll(AppLocalizations.of(context)),
        onImportCsv: () => _controller.importCsv(AppLocalizations.of(context)),
        onSelectMode: () => _controller.toggleSelectMode(),
        onRequestPermission: _requestPermission,
      ),
    );
  }

  void _onItemTap(SmsItem e) {
    if (_controller.selectMode) {
      _controller.toggleSelect(e);
      return;
    }
    unawaited(
      showSmsActionSheet(
        context,
        e,
        onSameAddress: (addr) => _controller.onFilterChangedWith(
          () => _controller.filter = _controller.filter.copyWith(
            sameAddress: addr,
          ),
        ),
        onSameSim: (sim) => _controller.onFilterChangedWith(
          () => _controller.filter = _controller.filter.copyWith(sameSim: sim),
        ),
        onDelete: () => _confirmAndDelete([e]),
        onHide: () => _controller.hideItem(e, AppLocalizations.of(context)),
      ),
    );
  }

  void _onItemLongPress(SmsItem e) {
    if (!_controller.selectMode) {
      if (e.uid == null) return;
      _controller.toggleSelectMode();
      _controller.toggleSelect(e);
    }
  }

  Future<bool> _confirmAndDelete(List<SmsItem> targets) async {
    final l10n = AppLocalizations.of(context);
    final deletable = [
      for (final e in targets)
        if (e.id != null) e,
    ];
    if (deletable.isEmpty) {
      _toast(l10n.nothingToDelete);
      return false;
    }
    return showConfirmDeleteSheet(
      context,
      deletable.length,
      (progress) => _controller.deleteIds(deletable, progress, l10n),
    );
  }

  Future<void> _exportSelected() async {
    await _controller.exportSelected(AppLocalizations.of(context));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final rows = _controller.computeRows(l10n);
        final visible = [
          for (final r in rows)
            if (r is SmsRow) r.item,
        ];
        // 每次重建后检查视口是否填满；未填满则链式补页（见 _scheduleLoadMoreCheck）。
        _scheduleLoadMoreCheck();

        return Scaffold(
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(kToolbarHeight),
            child: HomeAppBar(
              controller: _controller,
              visibleCount: visible.length,
              visibleItems: visible,
              onFilter: _openFilter,
              onSettings: _openSettings,
              onMenu: _openMenu,
            ),
          ),
          floatingActionButton: _controller.selectMode || visible.isEmpty
              ? null
              : FloatingActionButton(
                  onPressed: () => _confirmAndDelete(visible),
                  child: const Icon(Icons.delete_forever_outlined),
                ),
          bottomNavigationBar: _controller.selectMode
              ? HomeSelectionBar(
                  controller: _controller,
                  onExport: _exportSelected,
                  onDelete: () =>
                      _confirmAndDelete(_controller.selectedItems()),
                )
              : null,
          body: RefreshIndicator(
            onRefresh: () => _controller.load(),
            child: _controller.loading
                ? const Center(child: CircularProgressIndicator())
                : CustomScrollView(
                    controller: _scrollController,
                    // 内容不足一屏时也保持可滚动，否则 RefreshIndicator 无法触发。
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: HomeBannerList(
                          controller: _controller,
                          onOpenMiuiGuide: () =>
                              _controller.onShowMiuiGuide?.call(),
                          onDismissMiui: _controller.dismissMiuiHint,
                          onRetryPartial: () => _controller.load(),
                          onDismissPartial: _controller.dismissPartialHint,
                          onFilterChanged: (f) {
                            unawaited(
                              _controller.onFilterChangedWith(
                                () => _controller.filter = f,
                              ),
                            );
                          },
                        ),
                      ),
                      if (visible.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              12,
                              _controller.miuiNotifHint ||
                                      _controller.partial ||
                                      _controller.filter.active
                                  ? 0
                                  : 8,
                              12,
                              88,
                            ),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight:
                                    MediaQuery.sizeOf(context).height * 0.55,
                              ),
                              child: HomeEmptyBody(
                                controller: _controller,
                                onAction: () async {
                                  if (_controller.filter.active) {
                                    await _controller.onFilterChangedWith(() {
                                      _controller.filter = const SmsFilter();
                                    });
                                  } else if (_controller.needPermission) {
                                    await _requestPermission();
                                  } else {
                                    await _controller.load();
                                  }
                                },
                                onSecondary: () async {
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
                                  await _controller.load();
                                },
                              ),
                            ),
                          ),
                        )
                      else
                        HomeListRows(
                          controller: _controller,
                          visible: visible,
                          rows: rows,
                          onItemTap: _onItemTap,
                          onItemLongPress: _onItemLongPress,
                          onDelete: (item) => _confirmAndDelete([item]),
                        ),
                      if (_controller.loadingMore)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(12, 8, 12, 88),
                            child: Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}
