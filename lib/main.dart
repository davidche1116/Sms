import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sms_advanced/sms_advanced.dart';

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

class _SmsHomePageState extends State<SmsHomePage> {
  // 数据访问与过滤逻辑已下沉到 services 层，UI 只负责调用与展示。
  final SmsRepository _repository = SmsRepository();
  // AnimatedList 的条目计数由内部状态维护（只认 insertItem/removeItem，
  // 会忽略重建时传的新 initialItemCount）。整表刷新（查询/过滤/切回全部）
  // 必须换一个新 Key 让旧状态丢弃，否则内部计数与新列表长度错位，
  // 标题显示 n 条但列表灰屏无内容，且多轮操作后越差越多。
  GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final ValueNotifier<List<SmsMessage>> _showList =
      ValueNotifier<List<SmsMessage>>([]);
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ValueNotifier<bool> _showLoading = ValueNotifier<bool>(true);
  late AppLocalizations appLocalizations;
  DateTime? _startDate;
  DateTime? _endDate;

  /// 整表替换：丢弃旧 AnimatedList 状态，用正确长度重建。
  void _setFullList(List<SmsMessage> newList) {
    _listKey = GlobalKey<AnimatedListState>();
    _showList.value = newList;
  }

  Future<void> _showToast(String msg) async {
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

  Future<bool> _checkDefaultSmsApp() async {
    // isDefaultSmsApp 返回三态：true=是默认 / false=明确不是 / null=无法判定。
    final bool? same = await _repository.isDefaultSmsApp();
    if (same == true) return true;
    if (same == false) {
      // 明确不是默认短信应用：提示用户去系统设置。
      _showToast(appLocalizations.toast_default);
      return false;
    }
    // 无法判定（默认应用不可知或平台调用缺失/异常）：如实提示"操作失败"，
    // 而不是误报"不是默认"。删除依赖默认应用身份，无法确认时宁可拦截。
    _showToast(appLocalizations.operation_failed);
    return false;
  }

  Future<void> _querySms() async {
    bool ok = await Permission.sms.isGranted;
    List<SmsMessage> showMessageList = [];
    if (ok) {
      _showLoading.value = true;
      try {
        // body 可能为 null（部分彩信/草稿无正文），过滤逻辑见
        // services/sms_filter.dart，null 一律视为不匹配。
        final List<SmsMessage> allMessageList = await _repository.getAllSms();
        showMessageList = _applyFilters(allMessageList);
      } catch (e) {
        // 平台查询失败（如底层插件异常）时兜底：提示失败、清空列表，
        // 保证 loading 一定复位、界面不挂死。
        debugPrint('querySms failed: $e');
        showMessageList = [];
        _showToast(appLocalizations.operation_failed);
      } finally {
        _showLoading.value = false;
      }
    } else {
      showMessageList = [];
      _showToast(appLocalizations.toast_permission);
      _showLoading.value = false;
    }
    _setFullList(showMessageList);
  }

  void _removeIndex(int index) {
    if (index < 0 || index >= _showList.value.length) return;
    final AnimatedListState? listState = _listKey.currentState;
    if (listState == null) return;
    final removedItem = _showList.value.removeAt(index);
    _showList.value = [..._showList.value];
    listState.removeItem(index, (
      BuildContext context,
      Animation<double> animation,
    ) {
      // 离场动画用的静态快照：不可交互，不再按 index 回查实时列表
      //（旧代码把 stale index 传给 _buildItem，动画期间点选会读写错位）。
      return MessageItem(
        index: index,
        item: removedItem,
        animation: animation,
        interactive: false,
        appLocalizations: appLocalizations,
        onDelete: _deleteIndex,
        onRemove: _removeIndex,
        onSameAddress: _sameAddress,
        onSameSim: _sameSim,
        onShowToast: _showToast,
      );
    });
    // return removedItem;
  }

  Future<void> _deleteIndex(int index) async {
    if (index < 0 || index >= _showList.value.length) return;
    final int? id = _showList.value[index].id;
    final int? threadId = _showList.value[index].threadId;
    if (id == null || threadId == null) return;
    bool check = await _checkDefaultSmsApp();
    if (!check) return;
    try {
      bool? ok = await _repository.removeSmsById(id, threadId);
      if (ok == true) {
        _removeIndex(index);
      } else {
        _showToast(appLocalizations.operation_failed);
      }
    } catch (e) {
      // 平台删除调用异常（如系统拒绝）时提示失败，而不是静默崩溃。
      debugPrint('removeSmsById failed: $e');
      _showToast(appLocalizations.operation_failed);
    }
  }

  /// 统一的过滤链：关键词 + 日期区间 + 日期降序。
  ///
  /// 所有查询路径（全部 / 同号 / 同卡）都走它，保证"当前列表 = 数据源 +
  /// 过滤条件"的语义一致——下钻换的是数据源，过滤条件不应被悄悄丢掉。
  List<SmsMessage> _applyFilters(List<SmsMessage> messages) {
    List<SmsMessage> result = filterByKeyword(messages, _textController.text);
    result = filterByDateRange(result, _startDate, _endDate);
    return sortByDateDesc(result);
  }

  Future<void> _sameAddress(int index) async {
    // 同步快照查询条件：await 间隙列表可能已被刷新，不能再用 index 回查。
    if (index < 0 || index >= _showList.value.length) return;
    final String? address = _showList.value[index].address;
    List<SmsMessage> showMessageList = [];
    bool ok = await Permission.sms.isGranted;
    if (ok) {
      _showLoading.value = true;

      try {
        showMessageList = _applyFilters(
          await _repository.queryByAddress(address),
        );
      } catch (e) {
        debugPrint('querySms(address) failed: $e');
        showMessageList = [];
        _showToast(appLocalizations.operation_failed);
      } finally {
        _showLoading.value = false;
      }
    } else {
      showMessageList = [];
    }

    _setFullList(showMessageList);
  }

  Future<void> _sameSim(int index) async {
    // 同上：先同步快照 sim，避免异步间隙 index 失效。
    if (index < 0 || index >= _showList.value.length) return;
    final int? sim = _showList.value[index].sim;
    List<SmsMessage> showMessageList = [];
    bool ok = await Permission.sms.isGranted;
    if (ok) {
      _showLoading.value = true;

      try {
        List<SmsMessage> allMessageList = [];
        allMessageList = await _repository.getAllSms();
        showMessageList = _applyFilters(filterBySim(allMessageList, sim));
      } catch (e) {
        debugPrint('querySms(sim) failed: $e');
        showMessageList = [];
        _showToast(appLocalizations.operation_failed);
      } finally {
        _showLoading.value = false;
      }
    } else {
      showMessageList = [];
    }

    _setFullList(showMessageList);
  }

  void _filterDate() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: DateTime(2999),
      initialDateRange: DateTimeRange(
        start: _startDate ?? DateTime.now().subtract(Duration(days: 7)),
        end: _endDate ?? DateTime.now(),
      ),
    );

    if (picked != null) {
      // 区间语义 [起始日零点, 结束日次日零点)：左闭右开。旧实现给 end 加
      // 23:59:59 后又按开区间比较，结束日 23:59:59.001 之后的短信会被漏掉。
      _startDate = startOfDay(picked.start);
      _endDate = startOfNextDay(picked.end);
      _querySms();
    }
  }

  void _filterMsg() {
    double top = MediaQuery.of(context).padding.top;
    double width = MediaQuery.of(context).size.width / 2;
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
                controller: _textController,
                focusNode: _focusNode,
                decoration: InputDecoration(
                  labelText: appLocalizations.keyword,
                  prefixIcon: const Icon(Icons.search_outlined),
                  suffixIcon: GestureDetector(
                    onTap: () {
                      if (_textController.text.isNotEmpty) {
                        _textController.text = '';
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
    _querySms();
  }

  void _deleteMsg() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) {
        return CupertinoActionSheet(
          title: Text(appLocalizations.t_confirm_delete),
          message: Text(
            appLocalizations.delete_num(_showList.value.length.toString()),
          ),
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
    bool check = await _checkDefaultSmsApp();
    if (!check) return;
    if (_showList.value.length > 3000) {
      _showToast(appLocalizations.t_list_too_long);
    }
    // 快照：批量删除耗时较长，期间列表可能被其他操作刷新，
    // 按开始时的快照逐条删除，避免 index 漂移或读写错位。
    final List<SmsMessage> items = List.of(_showList.value);
    _showLoading.value = true;
    int failed = 0;
    for (final SmsMessage message in items) {
      final int? id = message.id;
      final int? threadId = message.threadId;
      // id/threadId 缺失的条目无法删除，计入失败而不是 ! 强解包崩溃。
      if (id == null || threadId == null) {
        failed++;
        continue;
      }
      try {
        final bool? ok = await _repository.removeSmsById(id, threadId);
        if (ok != true) {
          failed++;
        }
      } catch (e) {
        debugPrint('removeSmsById failed: $e');
        failed++;
      }
    }
    if (failed > 0) {
      _showToast(appLocalizations.delete_failed(failed.toString()));
    }
    _querySms();
  }

  Future<void> _requestPermission() async {
    // v13 迁移指南：Android 上 status 永不返回 permanentlyDenied，
    // 只能以 request() 结果为准。已授权时直接跳过请求。
    if (await Permission.sms.isGranted) {
      if (_showList.value.isEmpty) {
        _querySms();
      }
      _showToast(appLocalizations.operation_completed);
      return;
    }
    final PermissionStatus status = await Permission.sms.request();
    if (status.isGranted || status.isLimited) {
      if (_showList.value.isEmpty) {
        _querySms();
      }
      _showToast(appLocalizations.operation_completed);
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
    bool ok = await openAppSettings();
    if (!ok) {
      _showToast(appLocalizations.operation_failed);
    }
  }

  Future<void> _setDefaultApp() async {
    try {
      final set = await _repository.setDefaultSmsApp();
      final get = await _repository.getDefaultSmsApp();
      if (set == 'had' || get == SmsRepository.defaultPackageId) {
        _showToast(appLocalizations.operation_completed);
      } else {
        // 'no'：已发起系统角色申请流程，尚未生效，需用户在系统弹窗确认。
        // 旧实现在这里什么都不提示，用户点了按钮却得不到任何反馈。
        _showToast(appLocalizations.toast_default_confirm);
      }
    } on PlatformException catch (e) {
      _showToast(e.message ?? appLocalizations.operation_failed);
    }
  }

  Future<void> _resetDefaultSmsApp() async {
    try {
      final result = await _repository.resetDefaultSmsApp();
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
    if (_showList.value.isEmpty) {
      _showToast(appLocalizations.toast_no);
      return;
    }

    // 阶段 1：生成 CSV 并落盘。这里失败多为 IO/权限/平台（存储满、临时目录不可用、
    // 缺少存储权限），单独提示"保存失败"，与后面调起系统分享的失败区分开。
    // 阶段 1 成功后 outFile 必已赋值；阶段 1 失败即 return，不会触碰它。
    late File outFile;
    try {
      // CSV 编码逻辑见 services/csv_exporter.dart（纯函数，已单测覆盖）。
      Directory tempDir = await getTemporaryDirectory();
      String path = '${tempDir.path}/${appLocalizations.sms_list}.csv';
      outFile = File(path);
      // 直接 writeAsBytes 落盘，省掉 String→Uint8List.fromList 这层冗余全量
      // 拷贝，以及 XFile.fromData 额外驻留的一份 data。内存峰值从多份全量降到
      // csvString + bytes 两份。flush 确保 CSV 完整落盘后再分享，否则可能分享
      // 到空或半截文件。这里刻意不改 CSV 的逐行编码路径（仍用 buildSmsCsv
      // 整体编码）：流式/分批编码需逐字节一致性验证，改动风险大于收益。
      await outFile.writeAsBytes(
        encodeSmsCsvBytes(_showList.value),
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
        files: [XFile(outFile.path)],
      );
      ShareResult res = await SharePlus.instance.share(params);
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
    // 系统 UI 一次性配置：原先放在 build 里，每次重建都会触发
    // platform channel 调用。透明导航栏 + edge-to-edge 由系统自动
    // 处理图标对比度，无需按主题逐帧更新。
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(systemNavigationBarColor: Colors.transparent),
    );
    // 首次查询推迟到首帧之后：appLocalizations 在 build 中才赋值，
    // _querySms 的 await 间隙若早于首帧触发提示，会触发
    // LateInitializationError。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _querySms();
    });
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

  @override
  Widget build(BuildContext context) {
    appLocalizations = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: ValueListenableBuilder(
          valueListenable: _showList,
          builder:
              (BuildContext context, List<SmsMessage> value, Widget? child) {
                return value.isEmpty
                    ? Text(appLocalizations.sms)
                    : Text(appLocalizations.num_sms(value.length.toString()));
              },
        ),
        actions: [
          IconButton(
            tooltip: appLocalizations.t_all_sms,
            onPressed: () {
              _textController.text = '';
              _startDate = null;
              _endDate = null;
              _querySms();
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
          PopupMenuButton(
            itemBuilder: (BuildContext context) => <PopupMenuItem<String>>[
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
      ),
      body: ValueListenableBuilder(
        valueListenable: _showLoading,
        builder: (BuildContext context, bool value, Widget? child) {
          return value
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                )
              : ValueListenableBuilder(
                  valueListenable: _showList,
                  builder:
                      (
                        BuildContext context,
                        List<SmsMessage> value,
                        Widget? child,
                      ) {
                        return value.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.message_outlined,
                                      size: 80,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      appLocalizations.t_no_sms,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge,
                                    ),
                                    const SizedBox(height: 80),
                                    FilledButton(
                                      onPressed: () {
                                        _textController.text = '';
                                        _startDate = null;
                                        _endDate = null;
                                        _querySms();
                                      },
                                      child: Text(
                                        appLocalizations.b_remove_filter,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    FilledButton(
                                      onPressed: _setDefaultApp,
                                      child: Text(appLocalizations.set_default),
                                    ),
                                    const SizedBox(height: 10),
                                    FilledButton(
                                      onPressed: _requestPermission,
                                      child: Text(
                                        appLocalizations.set_permission,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : AnimatedList(
                                key: _listKey,
                                initialItemCount: value.length,
                                itemBuilder:
                                    (
                                      BuildContext context,
                                      int index,
                                      Animation<double> animation,
                                    ) {
                                      SmsMessage item = value[index];
                                      return MessageItem(
                                        index: index,
                                        item: item,
                                        animation: animation,
                                        appLocalizations: appLocalizations,
                                        onDelete: _deleteIndex,
                                        onRemove: _removeIndex,
                                        onSameAddress: _sameAddress,
                                        onSameSim: _sameSim,
                                        onShowToast: _showToast,
                                      );
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
