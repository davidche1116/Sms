import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sms_advanced/sms_advanced.dart';

import 'controllers/sms_list_controller.dart';
import 'l10n/generated/app_localizations.dart';
import 'services/csv_exporter.dart';
import 'services/sms_filter.dart';
import 'services/sms_repository.dart';
import 'widgets/message_item.dart';

void main() {
  runApp(const SmsApp());
}

class SmsApp extends StatelessWidget {
  const SmsApp({super.key});

  static const Color themeColor = Color(0xFF2BAE67);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (BuildContext context) {
        return AppLocalizations.of(context)!.title;
      },
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: themeColor,
          dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: themeColor,
          brightness: Brightness.dark,
          dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
        ),
        brightness: Brightness.dark,
      ),
      home: const SmsHomePage(),
      navigatorObservers: [FlutterSmartDialog.observer],
      builder: FlutterSmartDialog.init(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}

class SmsHomePage extends StatefulWidget {
  const SmsHomePage({super.key});

  @override
  State<SmsHomePage> createState() => _SmsHomePageState();
}

/// 列表页只负责渲染与交互呈现：业务状态与规则都在 SmsListController 里，
/// 这里不保存短信数据、不重复实现过滤与删除逻辑。
class _SmsHomePageState extends State<SmsHomePage> with WidgetsBindingObserver {
  late SmsListController _controller;
  final FocusNode _focusNode = FocusNode();
  late AppLocalizations appLocalizations;

  /// 是否已完成首次查询。didChangeDependencies 会被多次触发（locale 变化、
  /// MediaQuery 变化等），首次查询只能发起一次。
  bool _didInitQuery = false;

  /// 批量删除是否被用户取消。
  bool _deleteCancelled = false;

  void _showToast(String msg) {
    // 所有提示都可能在 await 之后触发：页面已销毁时 context 失效，
    // 统一在这里拦截，调用方不必逐个加 mounted 判断。
    if (!mounted) return;
    SmartDialog.showToast(
      msg,
      animationType: SmartAnimationType.centerScale_otherSlide,
      builder: (_) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 100),
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.light
                ? Colors.black
                : Colors.grey,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Text(
            msg,
            style: TextStyle(
              color: Colors.white,
              fontSize: Theme.of(context).textTheme.titleLarge?.fontSize,
            ),
          ),
        );
      },
    );
  }

  Widget _buildItem(
    SmsMessage item,
    Animation<double> animation, {
    bool interactive = true,
  }) {
    // 列表项需随选择态变化重建（复选框勾选、选中背景）。控制器是
    // ChangeNotifier，仅监听 messages 无法感知 selectionMode/_selected 的
    // 变化，必须显式监听 _controller 才能在勾选/全选/退出时刷新。
    // 离场动画用的静态快照不监听，避免动画过程中被选择态刷新打断。
    MessageItem buildItem() => MessageItem(
      item: item,
      animation: animation,
      interactive: interactive,
      selectionMode: _controller.selectionMode,
      selected: _controller.isSelected(item),
      appLocalizations: appLocalizations,
      onDelete: _deleteMessage,
      onRemove: _removeMessage,
      onSameAddress: _controller.querySameAddress,
      onSameSim: _controller.querySameSim,
      onShowToast: _showToast,
      onToggleSelection: _controller.toggleSelection,
    );
    if (!interactive) return buildItem();
    return ListenableBuilder(
      listenable: _controller,
      builder: (BuildContext context, Widget? _) => buildItem(),
    );
  }

  /// 只从列表移除（不删系统短信），用于"从列表移除"。
  void _removeMessage(SmsMessage message) {
    final int index = _controller.removeFromList(message);
    if (index < 0) return;
    _controller.listKey.currentState?.removeItem(index, (
      BuildContext context,
      Animation<double> animation,
    ) {
      // 离场动画用的静态快照：不可交互。
      return _buildItem(message, animation, interactive: false);
    });
  }

  Future<void> _deleteMessage(SmsMessage message) async {
    if (!await _controller.ensureDefaultSmsApp()) return;
    if (!mounted) return;
    if (await _controller.deleteMessage(message)) {
      _removeMessage(message);
    }
  }

  void _filterDate() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: DateTime(2999),
      initialDateRange: DateTimeRange(
        start:
            _controller.startDate ??
            DateTime.now().subtract(const Duration(days: 7)),
        end: _controller.endDate ?? DateTime.now(),
      ),
    );

    if (!mounted) return;
    if (picked != null) {
      // 区间语义 [起始日零点, 结束日次日零点)：左闭右开。旧实现给 end 加
      // 23:59:59 后又按开区间比较，结束日 23:59:59.001 之后的短信会被漏掉。
      await _controller.applyDateRange(
        startOfDay(picked.start),
        startOfNextDay(picked.end),
      );
    }
  }

  void _filterMsg() {
    final double top = MediaQuery.of(context).padding.top;
    final double width = MediaQuery.of(context).size.width / 2;
    _focusNode.requestFocus();
    SmartDialog.show(
      alignment: Alignment.topCenter,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: top),
              TextField(
                autofocus: true,
                controller: _controller.keywordController,
                focusNode: _focusNode,
                decoration: InputDecoration(
                  labelText: appLocalizations.keyword,
                  prefixIcon: const Icon(Icons.search_outlined),
                  suffixIcon: GestureDetector(
                    onTap: () {
                      if (_controller.keywordController.text.isNotEmpty) {
                        _controller.keywordController.clear();
                      } else {
                        SmartDialog.dismiss(status: SmartStatus.custom);
                      }
                    },
                    child: const Icon(Icons.clear_outlined),
                  ),
                ),
                onSubmitted: (_) {
                  _filterSubmit();
                },
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _filterSubmit,
                child: SizedBox(
                  width: width,
                  child: Center(child: Text(appLocalizations.b_confirm)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _filterSubmit() {
    SmartDialog.dismiss(status: SmartStatus.custom);
    _controller.queryAll();
  }

  void _deleteMsg() {
    // 多选模式下删除"已选"而非"当前列表全部"，确认弹窗文案与数量随之切换。
    final bool selecting = _controller.selectionMode;
    final int total = selecting ? _controller.selectedCount : _controller.count;
    if (selecting && total == 0) {
      _showToast(appLocalizations.toast_no_selection);
      return;
    }
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return CupertinoActionSheet(
          title: Text(appLocalizations.t_confirm_delete),
          message: Text(appLocalizations.delete_num(total.toString())),
          actions: <Widget>[
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(context).pop('delete');
                _deleteSubmit();
              },
              isDestructiveAction: true,
              isDefaultAction: true,
              child: Text(appLocalizations.b_confirm),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            child: Text(appLocalizations.b_cancel),
            onPressed: () {
              Navigator.of(context).pop('cancel');
            },
          ),
        );
      },
    );
  }

  Future<void> _deleteSubmit() async {
    // 多选模式：删除已选；否则删除当前列表全部。数量口径与弹窗一致。
    final bool selecting = _controller.selectionMode;
    final int total = selecting ? _controller.selectedCount : _controller.count;
    if (selecting && total == 0) {
      _showToast(appLocalizations.toast_no_selection);
      return;
    }
    if (!selecting && _controller.isEmpty) {
      _showToast(appLocalizations.toast_no);
      return;
    }
    if (!await _controller.ensureDefaultSmsApp()) return;
    if (!mounted) return;
    if (total > 3000) {
      _showToast(appLocalizations.t_list_too_long);
    }

    final ValueNotifier<int?> progress = ValueNotifier<int?>(null);
    _deleteCancelled = false;
    SmartDialog.show(
      clickMaskDismiss: false,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              ValueListenableBuilder<int?>(
                valueListenable: progress,
                builder: (BuildContext context, int? value, Widget? _) {
                  // value 为 null 表示原生批量删除中，没有逐条进度。
                  return Text(
                    value == null
                        ? appLocalizations.t_deleting
                        : appLocalizations.delete_progress(
                            value.toString(),
                            total.toString(),
                          ),
                  );
                },
              ),
              TextButton(
                onPressed: () => _deleteCancelled = true,
                child: Text(appLocalizations.b_cancel),
              ),
            ],
          ),
        );
      },
    );

    final int failed = selecting
        ? await _controller.deleteSelected(
            onProgress: (int? done, int total) {
              progress.value = done;
            },
            shouldCancel: () => _deleteCancelled || !mounted,
          )
        : await _controller.deleteAll(
            onProgress: (int? done, int total) {
              progress.value = done;
            },
            shouldCancel: () => _deleteCancelled || !mounted,
          );
    SmartDialog.dismiss();
    progress.dispose();
    if (!mounted) return;
    if (failed > 0) {
      _showToast(appLocalizations.delete_failed(failed.toString()));
    }
    if (selecting) {
      // 删除完成后退出多选模式，避免残留的选中态指向已删除条目。
      _controller.exitSelectionMode();
    }
    _controller.queryAll();
  }

  Future<void> _requestPermission() async {
    // 勿用 Permission.sms.isGranted 短路：掉默认短信角色并被系统强停后，
    // 该状态可能仍缓存为 true，导致「申请成功」假象，实际 READ_SMS 已被收回。
    // 一律走 request() 让系统重新裁定；再以原生 checkSelfPermission 复核。
    final PermissionStatus status = await Permission.sms.request();
    final bool reallyGranted = await _controller.repository
        .hasReadSmsPermission();
    final bool? isDefault = await _controller.repository.isDefaultSmsApp();

    if (reallyGranted || isDefault == true) {
      // 系统侧确实可读（有 READ_SMS，或本应用仍是默认短信）。
      // 强制重查，去掉空列表残留。
      await _controller.queryAll();
      _showToast(appLocalizations.operation_completed);
      return;
    }

    // permission_handler 报成功但原生 check 为否：状态不一致，去设置页手动开。
    if (status.isGranted || status.isLimited) {
      _showToast(appLocalizations.toast_permission);
      await _setAppPermission();
      return;
    }
    if (status.isPermanentlyDenied) {
      // 第二次拒绝后系统不再弹窗，引导用户去设置页手动开启。
      // 不持久化该结论：从设置返回后下次用户操作会再次 request()。
      _showToast(appLocalizations.toast_permission);
      await _setAppPermission();
      return;
    }
    // 本次刚拒绝：不立即重弹，等下次用户操作再试。
    _showToast(appLocalizations.operation_failed);
  }

  Future<void> _setAppPermission() async {
    final bool ok = await openAppSettings();
    if (!ok) {
      _showToast(appLocalizations.operation_failed);
    }
  }

  Future<void> _setDefaultApp() async {
    try {
      final String? set = await _controller.repository.setDefaultSmsApp();
      final String? get = await _controller.repository.getDefaultSmsApp();
      if (set == 'had' || get == SmsRepository.defaultPackageId) {
        _showToast(appLocalizations.operation_completed);
      } else {
        // 'no'：已发起系统角色申请流程，尚未生效，需用户在系统弹窗确认。
        _showToast(appLocalizations.toast_default_confirm);
      }
    } on PlatformException catch (e) {
      _showToast(e.message ?? appLocalizations.operation_failed);
    }
  }

  Future<void> _resetDefaultSmsApp() async {
    try {
      final String? result = await _controller.repository.resetDefaultSmsApp();
      if (result == 'settings') {
        // Android 10+ 无法由应用代用户释放默认短信角色，只能引导到系统
        // 设置页；如实告知，不谎报"已完成"。
        _showToast(appLocalizations.toast_default_settings);
      } else if (result == 'ok') {
        // Android 10 以下：已发起系统切换弹窗，需用户确认。
        _showToast(appLocalizations.toast_default_confirm);
      } else if (result == 'no') {
        _showToast(appLocalizations.operation_failed);
      }
    } on PlatformException catch (e) {
      _showToast(e.message ?? appLocalizations.operation_failed);
    }
  }

  Future<void> _export() async {
    if (_controller.isEmpty) {
      _showToast(appLocalizations.toast_no);
      return;
    }

    // 阶段 1：生成 CSV 并落盘。这里失败多为 IO/权限/平台（存储满、临时目录不可用、
    // 缺少存储权限），单独提示"保存失败"，与后面调起系统分享的失败区分开。
    // 阶段 1 成功后 outFile 必已赋值；阶段 1 失败即 return，不会触碰它。
    late File outFile;
    try {
      // CSV 编码逻辑见 services/csv_exporter.dart（纯函数，已单测覆盖）。
      final Directory tempDir = await getTemporaryDirectory();
      final String path = '${tempDir.path}/${appLocalizations.sms_list}.csv';
      outFile = File(path);
      // 直接 writeAsBytes 落盘，省掉 String→Uint8List.fromList 这层冗余全量
      // 拷贝，以及 XFile.fromData 额外驻留的一份 data。内存峰值从多份全量降到
      // csvString + bytes 两份。flush 确保 CSV 完整落盘后再分享，否则可能分享
      // 到空或半截文件。这里刻意不改 CSV 的逐行编码路径（仍用 buildSmsCsv
      // 整体编码）：流式/分批编码需逐字节一致性验证，改动风险大于收益。
      await outFile.writeAsBytes(
        encodeSmsCsvBytes(_controller.messages.value),
        flush: true,
      );
    } catch (e) {
      // IO/平台类失败：提示保存失败，而不是笼统的"操作失败"。
      debugPrint('export save failed: $e');
      _showToast(appLocalizations.toast_save_failed);
      return;
    }

    // 阶段 2：调起系统分享。文件已落盘，这里失败只关乎分享面板/目标应用。
    try {
      final ShareParams params = ShareParams(
        text: appLocalizations.sms_list,
        files: <XFile>[XFile(outFile.path)],
      );
      final ShareResult res = await SharePlus.instance.share(params);
      if (res.status == ShareResultStatus.success) {
        _showToast(appLocalizations.toast_share);
      }
    } catch (e) {
      // 调起分享失败时提示，而不是未捕获异常直接崩溃。
      debugPrint('export share failed: $e');
      _showToast(appLocalizations.operation_failed);
    } finally {
      // 只清理本次导出的 CSV 文件；递归删整个临时目录会连缓存目录里
      // 其他数据一起清掉，风险过大。
      try {
        await outFile.delete();
      } catch (_) {
        // 清理失败可以忽略，临时目录系统会回收。
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 系统 UI 一次性配置：原先放在 build 里，每次重建都会触发
    // platform channel 调用。透明导航栏 + edge-to-edge 由系统自动
    // 处理图标对比度，无需按主题逐帧更新。
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(systemNavigationBarColor: Colors.transparent),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 从系统设置（改默认短信/权限）返回后自动重查。掉默认短信角色时系统可能
    // 杀进程，冷启动会走 didChangeDependencies；进程仍在时靠这里刷新。
    if (state == AppLifecycleState.resumed && _didInitQuery) {
      _controller.queryAll();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 在 didChangeDependencies 里取国际化对象：它早于首帧执行，且 locale
    // 变化时会重新触发。旧实现在 build() 里给 late 字段赋值，导致任何早于
    // 首帧触发的异步回调都是 LateInitializationError，只能靠把首次查询推迟
    // 到 postFrameCallback 来绕开——治标不治本。
    appLocalizations = AppLocalizations.of(context)!;
    if (!_didInitQuery) {
      _didInitQuery = true;
      _controller = SmsListController(
        l10n: appLocalizations,
        onMessage: _showToast,
      );
      _controller.queryAll();
    } else {
      _controller.l10n = appLocalizations;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  PopupMenuItem<String> _selectView(IconData icon, String text, String id) {
    return PopupMenuItem<String>(
      value: id,
      // 文案用 Expanded 约束：菜单宽度有限，长文案（如英文标签）
      // 不加约束会横向溢出报 RenderFlex 异常。
      child: Row(
        children: <Widget>[
          Icon(icon),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.message_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 10),
          Text(
            appLocalizations.t_no_sms,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 80),
          FilledButton(
            onPressed: () {
              _controller.clearFilters();
              _controller.queryAll();
            },
            child: Text(appLocalizations.b_remove_filter),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: _setDefaultApp,
            child: Text(appLocalizations.set_default),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: _requestPermission,
            child: Text(appLocalizations.set_permission),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: ListenableBuilder(
          // 标题既要随列表条数变化，也要随多选状态/选中数变化：合并两个
          // 监听源，任一变化都重建标题。
          listenable: Listenable.merge([_controller, _controller.messages]),
          builder: (BuildContext context, Widget? child) {
            if (_controller.selectionMode) {
              return Text(
                appLocalizations.selected_num(
                  _controller.selectedCount.toString(),
                ),
              );
            }
            return _controller.isEmpty
                ? Text(appLocalizations.sms)
                : Text(appLocalizations.num_sms(_controller.count.toString()));
          },
        ),
        actions: <Widget>[
          // 选择态相关的按钮必须监听 _controller：控制器是 ChangeNotifier，
          // 仅在外层 build 不会在 selectionMode 变化时重建，导致"多选"点了
          // 没反应。这里用 ListenableBuilder 显式监听，进入/退出多选时切换
          // 按钮组（全选/退出 ↔ 全部/日期/搜索/多选/菜单）。
          ListenableBuilder(
            listenable: _controller,
            builder: (BuildContext context, Widget? _) {
              if (_controller.selectionMode) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextButton(
                      onPressed: _controller.selectAll,
                      child: Text(appLocalizations.select_all),
                    ),
                    TextButton(
                      onPressed: _controller.exitSelectionMode,
                      child: Text(appLocalizations.exit_select),
                    ),
                  ],
                );
              }
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  IconButton(
                    tooltip: appLocalizations.t_all_sms,
                    onPressed: () {
                      _controller.clearFilters();
                      _controller.queryAll();
                    },
                    icon: const Icon(Icons.format_list_bulleted_outlined),
                  ),
                  IconButton(
                    tooltip: appLocalizations.t_date_filter,
                    onPressed: _filterDate,
                    icon: const Icon(Icons.date_range_outlined),
                  ),
                  IconButton(
                    tooltip: appLocalizations.t_keyword_filter,
                    onPressed: _filterMsg,
                    icon: const Icon(Icons.search_outlined),
                  ),
                  IconButton(
                    tooltip: appLocalizations.set_select,
                    onPressed: () => _controller.enterSelectionMode(),
                    icon: const Icon(Icons.checklist_outlined),
                  ),
                  PopupMenuButton<String>(
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuItem<String>>[
                          _selectView(
                            Icons.message_outlined,
                            appLocalizations.set_permission,
                            'A',
                          ),
                          _selectView(
                            Icons.settings_outlined,
                            appLocalizations.set_settings,
                            'B',
                          ),
                          _selectView(
                            Icons.admin_panel_settings_outlined,
                            appLocalizations.set_default,
                            'C',
                          ),
                          _selectView(
                            Icons.refresh_rounded,
                            appLocalizations.set_restore,
                            'D',
                          ),
                          _selectView(
                            Icons.share_outlined,
                            appLocalizations.set_export,
                            'E',
                          ),
                        ],
                    onSelected: (String action) {
                      switch (action) {
                        case 'A':
                          _requestPermission();
                          break;
                        case 'B':
                          _setAppPermission();
                          break;
                        case 'C':
                          _setDefaultApp();
                          break;
                        case 'D':
                          _resetDefaultSmsApp();
                          break;
                        case 'E':
                          _export();
                          break;
                      }
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: _controller.loading,
        builder: (BuildContext context, bool loading, Widget? child) {
          if (loading) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const CircularProgressIndicator(),
                  Container(
                    margin: const EdgeInsets.only(top: 20),
                    child: Text(
                      appLocalizations.t_wait,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
            );
          }
          return ValueListenableBuilder<List<SmsMessage>>(
            valueListenable: _controller.messages,
            builder:
                (BuildContext context, List<SmsMessage> value, Widget? child) {
                  if (value.isEmpty) {
                    return _buildEmptyState();
                  }
                  return AnimatedList(
                    key: _controller.listKey,
                    initialItemCount: value.length,
                    itemBuilder:
                        (
                          BuildContext context,
                          int index,
                          Animation<double> animation,
                        ) {
                          return _buildItem(value[index], animation);
                        },
                  );
                },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        tooltip: appLocalizations.t_delete_all,
        shape: const CircleBorder(),
        onPressed: _deleteMsg,
        child: const Icon(Icons.delete_forever_outlined),
      ),
    );
  }
}
