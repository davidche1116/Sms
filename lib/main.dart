import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sms_advanced/sms_advanced.dart';

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
      title: '短信清理',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: themeColor),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: themeColor,
          brightness: Brightness.dark,
        ),
        brightness: Brightness.dark,
      ),
      home: const SmsHomePage(),
      navigatorObservers: [FlutterSmartDialog.observer],
      builder: FlutterSmartDialog.init(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'),
      ],
      locale: const Locale('zh', 'CN'),
    );
  }
}

class SmsHomePage extends StatefulWidget {
  const SmsHomePage({super.key});

  @override
  State<SmsHomePage> createState() => _SmsHomePageState();
}

class _SmsHomePageState extends State<SmsHomePage> {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  List<SmsMessage> allMessageList = [];
  List<SmsMessage> showMessageList = [];
  String title = '短信';
  TextEditingController textController = TextEditingController();
  FocusNode focusNode = FocusNode();
  static const platform = MethodChannel('com.dc16.sms/smsApp');
  static const String packageId = 'com.dc16.sms';
  bool showLoading = true;

  _showToast(String msg) async {
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
          child: Text(msg,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: Theme.of(context).textTheme.titleLarge?.fontSize)),
        );
      },
    );
  }

  Future<bool> _checkDefalutSmsApp() async {
    try {
      final smsApp = await platform.invokeMethod<String>('getDefaultSmsApp');
      bool same = (smsApp == packageId);
      if (!same) {
        _showToast('需要在系统设置中将本应用设置为默认短信应用才能删除短信');
      }
      return same;
    } on PlatformException catch (e) {
      debugPrint(e.message);
    }
    return true;
  }

  _querySms() async {
    bool ok = await Permission.sms.isGranted;
    if (ok) {
      setState(() {
        showLoading = true;
      });
      allMessageList = [];
      SmsQuery query = SmsQuery();
      allMessageList = await query.getAllSms;
      if (textController.text.isNotEmpty) {
        showMessageList = [];
        for (int i = 0; i < allMessageList.length; ++i) {
          if (allMessageList[i].body!.contains(textController.text)) {
            showMessageList.add(allMessageList[i]);
          }
        }
      } else {
        showMessageList = allMessageList;
      }

      showMessageList.sort((a, b) => b.date!.compareTo(a.date!));
      title = '${showMessageList.length}条短信';

      setState(() {
        showLoading = false;
      });
    } else {
      showMessageList = [];
      _showToast('需要申请短信权限或设置为短信默认应用');
      setState(() {});
    }
  }

  _removeIndex(int index) {
    final removedItem = showMessageList.removeAt(index);
    title = '${showMessageList.length}条短信';
    _listKey.currentState!.removeItem(
      index,
      (BuildContext context, Animation<double> animation) {
        return _buildItem(index, removedItem, context, animation);
      },
    );
    // return removedItem;

    title = '${showMessageList.length}条短信';
    setState(() {});
  }

  _deleteIndex(int index) async {
    bool check = await _checkDefalutSmsApp();
    if (check) {
      SmsRemover smsRemover = SmsRemover();
      bool? ok = await smsRemover.removeSmsById(
          showMessageList[index].id!, showMessageList[index].threadId!);
      if (ok != null) {
        if (ok) {
          _removeIndex(index);
        } else {
          _showToast('删除失败');
        }
      }
    }
  }

  _sameAddress(int index) async {
    textController.text = '';
    bool ok = await Permission.sms.isGranted;
    if (ok) {
      setState(() {
        showLoading = true;
      });
      allMessageList = [];
      SmsQuery query = SmsQuery();
      showMessageList =
          await query.querySms(address: showMessageList[index].address);
      title = '${showMessageList.length}条短信';
      showMessageList.sort((a, b) => b.date!.compareTo(a.date!));

      setState(() {
        showLoading = false;
      });
    } else {
      showMessageList = [];
    }
    setState(() {});
  }

  _filterMsg() {
    double top = MediaQuery.of(context).padding.top;
    double width = MediaQuery.of(context).size.width / 2;
    focusNode.requestFocus();
    SmartDialog.show(
      alignment: Alignment.topCenter,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).dialogBackgroundColor,
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: top,
              ),
              TextField(
                autofocus: true,
                controller: textController,
                focusNode: focusNode,
                decoration: InputDecoration(
                  labelText: "关键字",
                  prefixIcon: const Icon(Icons.search_outlined),
                  suffixIcon: GestureDetector(
                    onTap: () {
                      if (textController.text.isNotEmpty) {
                        textController.text = '';
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
              const SizedBox(
                height: 20,
              ),
              FilledButton(
                onPressed: _filterSubmit,
                child: SizedBox(
                  width: width,
                  child: const Center(
                    child: Text('确定'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  _filterSubmit() {
    SmartDialog.dismiss(status: SmartStatus.custom);
    _querySms();
  }

  _deleteMsg() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) {
        return CupertinoActionSheet(
          title: const Text('确认删除'),
          message: Text('是否删除这${showMessageList.length}条短信？'),
          actions: <Widget>[
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(context).pop('delete');
                _deleteSubmit();
              },
              isDestructiveAction: true,
              isDefaultAction: true,
              child: const Text('确认'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            child: const Text('取消'),
            onPressed: () {
              Navigator.of(context).pop('cancel');
            },
          ),
        );
      },
    );
  }

  _deleteSubmit() async {
    bool check = await _checkDefalutSmsApp();
    if (check) {
      setState(() {
        showLoading = true;
      });
      SmsRemover smsRemover = SmsRemover();
      for (int i = 0; i < showMessageList.length; ++i) {
        await smsRemover.removeSmsById(
            showMessageList[i].id!, showMessageList[i].threadId!);
      }

      setState(() {
        showLoading = false;
      });
      _querySms();
    }
  }

  _requestPermission() async {
    PermissionStatus status = await Permission.sms.request();
    bool ok = (status == PermissionStatus.granted);
    if (ok && showMessageList.isEmpty) {
      _querySms();
    }
    _showToast('操作${ok ? '成功' : '失败'}');
  }

  _setAppPermission() async {
    bool ok = await openAppSettings();
    if (!ok) {
      _showToast('操作失败');
    }
  }

  _setDefaultApp() async {
    try {
      final set = await platform.invokeMethod<String>('setDefaultSmsApp');
      final get = await platform.invokeMethod<String>('getDefaultSmsApp');
      if (set == 'had' || get == packageId) {
        _showToast('操作成功');
      }
    } on PlatformException catch (e) {
      _showToast(e.message ?? '操作失败');
    }
  }

  _resetDefaultSmsApp() async {
    try {
      final result = await platform.invokeMethod<String>('resetDefaultSmsApp');
      if (result == 'no') {
        _showToast('操作失败');
      }
    } on PlatformException catch (e) {
      _showToast(e.message ?? '操作失败');
    }
  }

  @override
  void initState() {
    _querySms();
    super.initState();
  }

  Widget _buildItem(int index, SmsMessage item, BuildContext context,
      Animation<double> animation) {
    return SlideTransition(
      position:
          Tween<Offset>(begin: const Offset(1, 0), end: const Offset(0, 0))
              .animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeInBack,
                  reverseCurve: Curves.easeInOutBack)),
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  item.sender ?? '',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                Text(
                  item.date.toString().substring(0, 19),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            onTap: () {
              showCupertinoModalPopup(
                  context: context,
                  builder: (context) {
                    return CupertinoActionSheet(
                      title: const Text('提示'),
                      message: const Text('是否要删除或移出当前项？'),
                      actions: <Widget>[
                        CupertinoActionSheetAction(
                          onPressed: () {
                            Navigator.of(context).pop('remove');
                            _removeIndex(index);
                          },
                          child: const Text('移出列表'),
                        ),
                        CupertinoActionSheetAction(
                          onPressed: () {
                            Navigator.of(context).pop('delete');
                            _deleteIndex(index);
                          },
                          isDestructiveAction: true,
                          isDefaultAction: true,
                          child: const Text('直接删除'),
                        ),
                        CupertinoActionSheetAction(
                          onPressed: () {
                            Navigator.of(context).pop('same');
                            _sameAddress(index);
                          },
                          child: const Text('同号短信'),
                        ),
                      ],
                      cancelButton: CupertinoActionSheetAction(
                        child: const Text('取消'),
                        onPressed: () {
                          Navigator.of(context).pop('cancel');
                        },
                      ),
                    );
                  });
            },
          ),
          const Divider()
        ],
      ),
    );
  }

  _selectView(IconData icon, String text, String id) {
    return PopupMenuItem<String>(
      value: id,
      child: Row(
        children: <Widget>[
          Icon(icon),
          const SizedBox(width: 10),
          Text(text),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(title),
        actions: [
          IconButton(
            tooltip: '所有短信列表',
            onPressed: () {
              textController.text = '';
              _querySms();
            },
            icon: const Icon(Icons.format_list_bulleted_outlined),
          ),
          IconButton(
            tooltip: '关键字过滤',
            onPressed: _filterMsg,
            icon: const Icon(Icons.search_outlined),
          ),
          PopupMenuButton(
            itemBuilder: (BuildContext context) => <PopupMenuItem<String>>[
              _selectView(Icons.message_outlined, '申请短信权限', 'A'),
              _selectView(Icons.settings_outlined, '应用权限设置', 'B'),
              _selectView(Icons.admin_panel_settings_outlined, '设置默认短信应用', 'C'),
              _selectView(Icons.refresh_rounded, '恢复默认短信应用', 'D'),
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
              }
            },
          ),
        ],
      ),
      body: showLoading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  Container(
                    margin: const EdgeInsets.only(top: 20),
                    child: Text(
                      '请稍等',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
            )
          : showMessageList.isEmpty
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
                        '没有短信',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 80),
                      FilledButton(
                          onPressed: () {
                            textController.text = '';
                            _querySms();
                          },
                          child: const Text('移除过滤条件')),
                      const SizedBox(height: 10),
                      FilledButton(
                        onPressed: _setDefaultApp,
                        child: const Text('设置默认短信'),
                      ),
                      const SizedBox(height: 10),
                      FilledButton(
                        onPressed: _requestPermission,
                        child: const Text('申请短信权限'),
                      ),
                    ],
                  ),
                )
              : AnimatedList(
                  key: _listKey,
                  initialItemCount: showMessageList.length,
                  itemBuilder: (BuildContext context, int index,
                      Animation<double> animation) {
                    SmsMessage item = showMessageList[index];
                    return _buildItem(index, item, context, animation);
                  },
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        tooltip: '删除当前列表所有短信',
        shape: const CircleBorder(),
        onPressed: _deleteMsg,
        child: const Icon(Icons.delete_forever_outlined),
      ),
    );
  }
}
