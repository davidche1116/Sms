import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
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
  static const _platform = MethodChannel('com.dc16.sms/smsApp');
  static const String _packageId = 'com.dc16.sms';
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
    try {
      final smsApp = await _platform.invokeMethod<String>('getDefaultSmsApp');
      bool same = (smsApp == _packageId);
      if (!same) {
        _showToast(appLocalizations.toast_default);
      }
      return same;
    } on PlatformException catch (e) {
      debugPrint(e.message);
    }
    // 查询失败时按"非默认短信应用"处理：删除操作依赖默认应用身份，
    // 失败时继续删除只会静默失败甚至误删状态，宁可拦截。
    _showToast(appLocalizations.operation_failed);
    return false;
  }

  Future<void> _querySms() async {
    bool ok = await Permission.sms.isGranted;
    List<SmsMessage> showMessageList = [];
    if (ok) {
      _showLoading.value = true;
      try {
        List<SmsMessage> allMessageList = [];
        SmsQuery query = SmsQuery();
        allMessageList = await query.getAllSms;
        if (_textController.text.isNotEmpty) {
          // body 可能为 null（部分彩信/草稿无正文），用 null-safe 匹配
          // 替代 body! 强解包，避免崩溃。
          showMessageList = allMessageList.where((message) {
            return message.body?.contains(_textController.text) ?? false;
          }).toList();
        } else {
          showMessageList = allMessageList;
        }

        if (_startDate != null && _endDate != null) {
          showMessageList = showMessageList.where((element) {
            return element.date!.isAfter(_startDate!) &&
                element.date!.isBefore(_endDate!);
          }).toList();
        }

        showMessageList.sort((a, b) => b.date!.compareTo(a.date!));
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
      return _buildItem(index, removedItem, context, animation, false);
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
      SmsRemover smsRemover = SmsRemover();
      bool? ok = await smsRemover.removeSmsById(id, threadId);
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

  Future<void> _sameAddress(int index) async {
    // 同步快照查询条件：await 间隙列表可能已被刷新，不能再用 index 回查。
    if (index < 0 || index >= _showList.value.length) return;
    final String? address = _showList.value[index].address;
    _textController.text = '';
    List<SmsMessage> showMessageList = [];
    bool ok = await Permission.sms.isGranted;
    if (ok) {
      _showLoading.value = true;

      try {
        SmsQuery query = SmsQuery();
        showMessageList = await query.querySms(address: address);
        showMessageList.sort((a, b) => b.date!.compareTo(a.date!));
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
    _textController.text = '';
    List<SmsMessage> showMessageList = [];
    bool ok = await Permission.sms.isGranted;
    if (ok) {
      _showLoading.value = true;

      try {
        List<SmsMessage> allMessageList = [];
        SmsQuery query = SmsQuery();
        allMessageList = await query.getAllSms;

        if (sim != null) {
          showMessageList = allMessageList
              .where((message) => message.sim == sim)
              .toList();
        } else {
          showMessageList = allMessageList;
        }

        showMessageList.sort((a, b) => b.date!.compareTo(a.date!));
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
      _startDate = picked.start;
      _endDate = picked.end.add(Duration(hours: 23, minutes: 59, seconds: 59));
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
    SmsRemover smsRemover = SmsRemover();
    for (final SmsMessage message in items) {
      final int? id = message.id;
      final int? threadId = message.threadId;
      // id/threadId 缺失的条目无法删除，计入失败而不是 ! 强解包崩溃。
      if (id == null || threadId == null) {
        failed++;
        continue;
      }
      try {
        final bool? ok = await smsRemover.removeSmsById(id, threadId);
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
      final set = await _platform.invokeMethod<String>('setDefaultSmsApp');
      final get = await _platform.invokeMethod<String>('getDefaultSmsApp');
      if (set == 'had' || get == _packageId) {
        _showToast(appLocalizations.operation_completed);
      }
    } on PlatformException catch (e) {
      _showToast(e.message ?? appLocalizations.operation_failed);
    }
  }

  Future<void> _resetDefaultSmsApp() async {
    try {
      final result = await _platform.invokeMethod<String>('resetDefaultSmsApp');
      if (result == 'no') {
        _showToast(appLocalizations.operation_failed);
      }
    } on PlatformException catch (e) {
      _showToast(e.message ?? appLocalizations.operation_failed);
    }
  }

  Future<void> _delDir(FileSystemEntity file) async {
    if (file is Directory) {
      final List<FileSystemEntity> children = file.listSync();
      for (final FileSystemEntity child in children) {
        await _delDir(child);
      }
    }
    await file.delete();
  }

  Future<void> _export() async {
    if (_showList.value.isEmpty) {
      _showToast(appLocalizations.toast_no);
      return;
    }

    List<String> headerRow = [
      'id',
      'threadId',
      'sim',
      'address',
      'body',
      'read',
      'date',
      'dateSent',
      'kind',
      'state',
    ];
    List<List<String>> headerAndDataList = [];
    headerAndDataList.add(headerRow);
    for (SmsMessage m in _showList.value) {
      List<String> dataRow = [
        m.id.toString(),
        m.threadId.toString(),
        m.sim.toString(),
        m.address.toString(),
        m.body.toString(),
        m.isRead.toString(),
        m.date.toString(),
        m.dateSent.toString(),
        m.kind.toString(),
        m.state.toString(),
      ];
      headerAndDataList.add(dataRow);
    }

    String csvData = csv.encode(headerAndDataList);
    final bytes = utf8.encode(csvData);
    Uint8List data = Uint8List.fromList(bytes);
    XFile xFile = XFile.fromData(data, mimeType: 'text/csv');
    Directory tempDir = await getTemporaryDirectory();
    String path = '${tempDir.path}/${appLocalizations.sms_list}.csv';
    xFile.saveTo(path);
    final ShareParams params = ShareParams(
      text: appLocalizations.sms_list,
      files: [XFile(path)],
    );
    ShareResult res = await SharePlus.instance.share(params);
    if (res.status == ShareResultStatus.success) {
      _showToast(appLocalizations.toast_share);
    }

    await _delDir(tempDir);
  }

  @override
  void initState() {
    super.initState();
    // 首次查询推迟到首帧之后：appLocalizations 在 build 中才赋值，
    // _querySms 的 await 间隙若早于首帧触发提示，会触发
    // LateInitializationError。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _querySms();
    });
  }

  Widget _buildItem(
    int index,
    SmsMessage item,
    BuildContext context,
    Animation<double> animation, [
    bool interactive = true,
  ]) {
    return SlideTransition(
      position:
          Tween<Offset>(
            begin: const Offset(1, 0),
            end: const Offset(0, 0),
          ).animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeInBack,
              reverseCurve: Curves.easeInOutBack,
            ),
          ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            minVerticalPadding: 8,
            minLeadingWidth: 4,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Text(item.body ?? ''), const SizedBox(height: 5)],
            ),
            subtitle: Row(
              spacing: 10,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${appLocalizations.sim}${item.sim}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    item.sender ?? '',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  item.date.toString().substring(0, 19),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primaryContainer,
                  ),
                ),
              ],
            ),
            onTap: interactive
                ? () {
                    showCupertinoModalPopup(
                      context: context,
                      builder: (context) {
                        return CupertinoActionSheet(
                          title: Text(appLocalizations.tips),
                          message: Text(appLocalizations.delete_or_move),
                          actions: <Widget>[
                            CupertinoActionSheetAction(
                              onPressed: () {
                                Navigator.of(context).pop('remove');
                                _removeIndex(index);
                              },
                              child: Text(appLocalizations.b_remove),
                            ),
                            CupertinoActionSheetAction(
                              onPressed: () {
                                Navigator.of(context).pop('delete');
                                _deleteIndex(index);
                              },
                              isDestructiveAction: true,
                              isDefaultAction: true,
                              child: Text(appLocalizations.b_delete),
                            ),
                            CupertinoActionSheetAction(
                              onPressed: () {
                                Navigator.of(context).pop('same');
                                _sameAddress(index);
                              },
                              child: Text(appLocalizations.b_same_number),
                            ),
                            CupertinoActionSheetAction(
                              onPressed: () {
                                Navigator.of(context).pop('sim');
                                _sameSim(index);
                              },
                              child: Text(appLocalizations.b_same_sim),
                            ),
                            CupertinoActionSheetAction(
                              onPressed: () {
                                Navigator.of(context).pop('copy');
                                Clipboard.setData(
                                  ClipboardData(
                                    // 用创建弹窗时捕获的 item，不按 index 回查实时列表
                                    //（列表刷新/移除后 index 可能指向别条甚至越界）。
                                    text:
                                        '${item.address}\r\n${item.date}\r\n${item.body}',
                                  ),
                                );
                                _showToast(appLocalizations.toast_clipboard);
                              },
                              child: Text(appLocalizations.b_copy),
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
                : null,
            onLongPress: interactive
                ? () {
                    showCupertinoModalPopup(
                      context: context,
                      builder: (context) {
                        return CupertinoActionSheet(
                          title: Padding(
                            padding: const EdgeInsets.all(20),
                            child: SelectableText(
                              item.body ?? '',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          actions: [
                            CupertinoActionSheetAction(
                              onPressed: () {
                                Navigator.of(context).pop('copy');
                                Clipboard.setData(
                                  ClipboardData(text: '${item.address}'),
                                );
                                _showToast(appLocalizations.toast_clipboard);
                              },
                              child: Text(item.address ?? ''),
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
                : null,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Divider(),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _selectView(IconData icon, String text, String id) {
    return PopupMenuItem<String>(
      value: id,
      child: Row(
        children: <Widget>[Icon(icon), const SizedBox(width: 10), Text(text)],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    SystemUiOverlayStyle systemUiOverlayStyle = SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Theme.of(context).brightness,
    );
    SystemChrome.setSystemUIOverlayStyle(systemUiOverlayStyle);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

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
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      appLocalizations.t_no_sms,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge,
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
                                      return _buildItem(
                                        index,
                                        item,
                                        context,
                                        animation,
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
