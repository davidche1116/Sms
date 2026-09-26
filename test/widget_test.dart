import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sms/l10n/generated/app_localizations.dart';
import 'package:sms/l10n/generated/app_localizations_en.dart';
import 'package:sms/main.dart';

/// 断言用的文案统一从国际化对象取：硬编码英文后，一改文案测试就全红。
final AppLocalizations l10n = AppLocalizationsEn();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // permission_handler：短信权限已授权（granted == 1）。
    const permissionChannel = MethodChannel(
      'flutter.baseflow.com/permissions/methods',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, (MethodCall call) async {
          if (call.method == 'checkPermissionStatus') return 1;
          return 0;
        });

    // 本项目原生查询通道：未实现 querySms，回退 sms_advanced。
    const appChannel = MethodChannel('com.dc16.sms/smsApp');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(appChannel, (MethodCall call) async {
          if (call.method == 'querySms') {
            throw MissingPluginException('querySms');
          }
          return null;
        });

    // sms_advanced：短信库为空。
    const queryChannel = MethodChannel(
      'plugins.elyudde.com/querySMS',
      JSONMethodCodec(),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(queryChannel, (MethodCall call) async {
          return <dynamic>[];
        });
  });

  tearDown(() {
    for (final MethodChannel channel in <MethodChannel>[
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      const MethodChannel('com.dc16.sms/smsApp'),
      const MethodChannel('plugins.elyudde.com/querySMS', JSONMethodCodec()),
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    }
  });

  testWidgets('App boots and shows empty SMS state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const SmsApp());
    await tester.pumpAndSettle();

    // 空列表时 AppBar 显示应用名（测试默认英文 locale）。
    expect(find.text(l10n.sms), findsOneWidget);
    // 空状态页提供"请求权限"入口。
    expect(find.text(l10n.set_permission), findsOneWidget);
  });

  testWidgets('Shows queried SMS with count in title', (
    WidgetTester tester,
  ) async {
    const queryChannel = MethodChannel(
      'plugins.elyudde.com/querySMS',
      JSONMethodCodec(),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(queryChannel, (MethodCall call) async {
          // 覆盖 setUp 中的空列表：返回一条可通过 SmsMessage.fromJson
          // 解析的短信（字段名与插件通道协议一致）。
          return <dynamic>[
            <dynamic, dynamic>{
              '_id': 1,
              'thread_id': 5,
              'address': '10086',
              'body': 'balance reminder',
              'sub_id': 0,
              'read': 1,
              'date': 1789000000000,
              'date_sent': 1789000000000,
            },
          ];
        });

    await tester.pumpWidget(const SmsApp());
    await tester.pumpAndSettle();

    // 插件按 Inbox/Sent/Draft 三种类型各查一次，mock 会命中 3 次。
    // 标题显示条数，列表渲染正文与号码。
    expect(find.text(l10n.num_sms('3')), findsOneWidget);
    expect(find.text('balance reminder'), findsWidgets);
    expect(find.text('10086'), findsWidgets);
  });

  testWidgets('App bar menu exposes settings entries', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const SmsApp());
    await tester.pumpAndSettle();

    // 打开右上角菜单，确认各设置入口存在。
    // 空状态页也提供部分同名按钮，因此统一用 findsWidgets。
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text(l10n.set_permission), findsWidgets);
    expect(find.text(l10n.set_default), findsWidgets);
    expect(find.text(l10n.set_export), findsWidgets);
  });

  testWidgets('进入/退出多选模式时 UI 跟随选择态刷新', (WidgetTester tester) async {
    const queryChannel = MethodChannel(
      'plugins.elyudde.com/querySMS',
      JSONMethodCodec(),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(queryChannel, (MethodCall call) async {
          return <dynamic>[
            <dynamic, dynamic>{
              '_id': 1,
              'thread_id': 5,
              'address': '10086',
              'body': 'balance reminder',
              'sub_id': 0,
              'read': 1,
              'date': 1789000000000,
              'date_sent': 1789000000000,
            },
          ];
        });

    await tester.pumpWidget(const SmsApp());
    await tester.pumpAndSettle();

    // 进入多选前：列表项无复选框，AppBar 有"多选"入口图标。
    expect(find.byType(Checkbox), findsNothing);
    expect(find.byIcon(Icons.checklist_outlined), findsOneWidget);

    // 点击"多选"入口进入多选模式。
    await tester.tap(find.byIcon(Icons.checklist_outlined));
    await tester.pumpAndSettle();

    // 进入多选后：列表项出现复选框，AppBar 出现"全选"/"退出多选"，
    // 而"多选"图标消失（按钮组已切换）。
    expect(find.byType(Checkbox), findsWidgets);
    expect(find.text(l10n.select_all), findsOneWidget);
    expect(find.text(l10n.exit_select), findsOneWidget);
    expect(find.byIcon(Icons.checklist_outlined), findsNothing);

    // 点击"退出多选"回到普通模式：复选框消失，入口图标恢复。
    await tester.tap(find.text(l10n.exit_select));
    await tester.pumpAndSettle();

    expect(find.byType(Checkbox), findsNothing);
    expect(find.byIcon(Icons.checklist_outlined), findsOneWidget);
  });
}
