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
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final ValueNotifier<List<SmsMessage>> _showList =
      ValueNotifier<List<SmsMessage>>([]);
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ValueNotifier<bool> _showLoading = ValueNotifier<bool>(true);
  late AppLocalizations appLocalizations;

  Future<void> _showToast(String msg) async {
    SmartDialog.showToast(
      msg,
      animationType: SmartAnimationType.centerScale_otherSlide,
      builder: (_) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 100),
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
          decoration: BoxDecoration(
            color:
                Theme.of(context).brightness == Brightness.light
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
    return true;
  }

  Future<void> _querySms() async {
    bool ok = await Permission.sms.isGranted;
    List<SmsMessage> showMessageList = [];
    if (ok) {
      _showLoading.value = true;
      List<SmsMessage> allMessageList = [];
      SmsQuery query = SmsQuery();
      allMessageList = await query.getAllSms;
      if (_textController.text.isNotEmpty) {
        for (int i = 0; i < allMessageList.length; ++i) {
          if (allMessageList[i].body!.contains(_textController.text)) {
            showMessageList.add(allMessageList[i]);
          }
        }
      } else {
        showMessageList = allMessageList;
      }

      showMessageList.sort((a, b) => b.date!.compareTo(a.date!));

      _showLoading.value = false;
    } else {
      showMessageList = [];
      _showToast(appLocalizations.toast_permission);
      _showLoading.value = false;
    }
    _showList.value = showMessageList;
  }

  void _removeIndex(int index) {
    final removedItem = _showList.value.removeAt(index);
    _showList.value = [..._showList.value];
    _listKey.currentState!.removeItem(index, (
      BuildContext context,
      Animation<double> animation,
    ) {
      return _buildItem(index, removedItem, context, animation);
    });
    // return removedItem;
  }

  Future<void> _deleteIndex(int index) async {
    bool check = await _checkDefaultSmsApp();
    if (check) {
      SmsRemover smsRemover = SmsRemover();
      bool? ok = await smsRemover.removeSmsById(
        _showList.value[index].id!,
        _showList.value[index].threadId!,
      );
      if (ok != null) {
        if (ok) {
          _removeIndex(index);
        } else {
          _showToast(appLocalizations.operation_failed);
        }
      }
    }
  }

  Future<void> _sameAddress(int index) async {
    _textController.text = '';
    List<SmsMessage> showMessageList = [];
    bool ok = await Permission.sms.isGranted;
    if (ok) {
      _showLoading.value = true;

      SmsQuery query = SmsQuery();
      showMessageList = await query.querySms(
        address: _showList.value[index].address,
      );
      showMessageList.sort((a, b) => b.date!.compareTo(a.date!));

      _showLoading.value = false;
    } else {
      showMessageList = [];
    }

    _showList.value = showMessageList;
  }

  Future<void> _sameSim(int index) async {
    _textController.text = '';
    List<SmsMessage> showMessageList = [];
    bool ok = await Permission.sms.isGranted;
    if (ok) {
      _showLoading.value = true;

      List<SmsMessage> allMessageList = [];
      SmsQuery query = SmsQuery();
      allMessageList = await query.getAllSms;

      int? sim = _showList.value[index].sim;

      if (sim != null) {
        for (int i = 0; i < allMessageList.length; ++i) {
          if (sim == allMessageList[i].sim) {
            showMessageList.add(allMessageList[i]);
          }
        }
      } else {
        showMessageList = allMessageList;
      }

      showMessageList.sort((a, b) => b.date!.compareTo(a.date!));

      _showLoading.value = false;
    } else {
      showMessageList = [];
    }

    _showList.value = showMessageList;
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
    if (check) {
      if (_showList.value.length > 3000) {
        _showToast(appLocalizations.t_list_too_long);
      }
      _showLoading.value = true;
      SmsRemover smsRemover = SmsRemover();
      for (int i = 0; i < _showList.value.length; ++i) {
        await smsRemover.removeSmsById(
          _showList.value[i].id!,
          _showList.value[i].threadId!,
        );
      }
      _querySms();
    }
  }

  Future<void> _requestPermission() async {
    PermissionStatus status = await Permission.sms.request();
    bool ok = (status == PermissionStatus.granted);
    if (ok && _showList.value.isEmpty) {
      _querySms();
    }
    _showToast(
      ok
          ? appLocalizations.operation_completed
          : appLocalizations.operation_failed,
    );
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

    String csvData = const ListToCsvConverter().convert(headerAndDataList);
    final bytes = utf8.encode(csvData);
    Uint8List data = Uint8List.fromList(bytes);
    XFile xFile = XFile.fromData(data, mimeType: 'text/csv');
    Directory tempDir = await getTemporaryDirectory();
    String path = '${tempDir.path}/${appLocalizations.sms_list}.csv';
    xFile.saveTo(path);
    ShareResult res = await SharePlus.instance.share(
      ShareParams(files: [XFile(path)], text: appLocalizations.sms_list),
    );
    _delDir(tempDir);
    if (res.status == ShareResultStatus.success) {
      _showToast(appLocalizations.toast_share);
    }
  }

  @override
  void initState() {
    _querySms();
    super.initState();
  }

  Widget _buildItem(
    int index,
    SmsMessage item,
    BuildContext context,
    Animation<double> animation,
  ) {
    return SlideTransition(
      position: Tween<Offset>(
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
            onTap: () {
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
                              text:
                                  '${_showList.value[index].address}\r\n${_showList.value[index].date}\r\n${_showList.value[index].body}',
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
            },
            onLongPress: () {
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
                            ClipboardData(
                              text: '${_showList.value[index].address}',
                            ),
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
            },
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
          builder: (
            BuildContext context,
            List<SmsMessage> value,
            Widget? child,
          ) {
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
              _querySms();
            },
            icon: const Icon(Icons.format_list_bulleted_outlined),
          ),
          IconButton(
            tooltip: appLocalizations.t_keyword_filter,
            onPressed: _filterMsg,
            icon: const Icon(Icons.search_outlined),
          ),
          PopupMenuButton(
            itemBuilder:
                (BuildContext context) => <PopupMenuItem<String>>[
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
                builder: (
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
                                _textController.text = '';
                                _querySms();
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
                      )
                      : AnimatedList(
                        key: _listKey,
                        initialItemCount: value.length,
                        itemBuilder: (
                          BuildContext context,
                          int index,
                          Animation<double> animation,
                        ) {
                          SmsMessage item = value[index];
                          return _buildItem(index, item, context, animation);
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
