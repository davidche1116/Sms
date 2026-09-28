import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_sms_channel.dart';

/// MIUI 通知类短信引导（requestReadSmsWithMiuiGuide）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpHomeHarness();

  testWidgets('MIUI 且未开通：申请读权限后弹引导层', (tester) async {
    var miuiEditorOpened = false;
    mockMiuiChannel(
      hasReadSms: false,
      isDefaultSms: false,
      miuiNotifState: 'likely_off',
      onOpenMiuiEditor: () => miuiEditorOpened = true,
    );

    await pumpHome(tester);
    expect(find.text('需要短信权限'), findsOneWidget);

    await tester.tap(find.text('申请短信权限'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('还要开启「通知类短信」'), findsOneWidget);
    expect(find.text('去开启通知类短信'), findsOneWidget);

    await tester.tap(find.text('去开启通知类短信'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(miuiEditorOpened, isTrue);
  });

  testWidgets('MIUI 且已开通 allow：不再弹引导层', (tester) async {
    mockMiuiChannel(hasReadSms: true, miuiNotifState: 'allow');

    await pumpHome(tester);
    expect(find.textContaining('流量提醒'), findsOneWidget);

    // 走更多菜单入口
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('申请短信权限'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('还要开启「通知类短信」'), findsNothing);
    expect(find.textContaining('流量提醒'), findsOneWidget);
  });
}
