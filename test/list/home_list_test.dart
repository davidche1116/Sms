import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_sms_channel.dart';

/// 首页列表基础展示与权限空态。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpHomeHarness();

  testWidgets('首页显示短信列表与顶栏入口', (tester) async {
    await pumpHome(tester);

    expect(find.text('短信'), findsOneWidget);
    expect(find.textContaining('流量提醒'), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
  });

  testWidgets('error=permission 时展示 NeedPerm 空态', (tester) async {
    mockHomeChannel(
      queryResult: {
        'messages': <Map<String, dynamic>>[],
        'error': 'permission',
      },
    );
    await pumpHome(tester);

    expect(find.text('需要短信权限'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '申请短信权限'), findsOneWidget);
    expect(find.textContaining('设为默认短信应用'), findsWidgets);
  });
}
