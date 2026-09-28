import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_sms_channel.dart';

/// 筛选弹层与 sameAddress Chip 同步（首页联动）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpHomeHarness();

  testWidgets('筛选弹层重置后 sameAddress 与 Chip 清除', (tester) async {
    await pumpHome(tester);

    // 动作 Sheet 设置「同号」筛选
    await tester.tap(find.textContaining('流量提醒'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('同号短信'));
    await tester.pumpAndSettle();

    expect(find.text('同号 10010'), findsOneWidget);
    expect(find.textContaining('验证码'), findsNothing);

    // 打开筛选 → 重置 → 完成：sameAddress 应被一并清掉
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重置'));
    await tester.pump();
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    expect(find.textContaining('同号'), findsNothing);
    expect(find.text('清除全部'), findsNothing);
    expect(find.textContaining('流量提醒'), findsOneWidget);
    expect(find.textContaining('验证码 8888'), findsOneWidget);
    expect(find.textContaining('已发送'), findsOneWidget);
  });

  testWidgets('筛选弹层只改关键词时 sameAddress 保留', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.textContaining('流量提醒'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('同号短信'));
    await tester.pumpAndSettle();
    expect(find.text('同号 10010'), findsOneWidget);

    // 只改关键词，不点重置 → 完成
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '流量');
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    expect(find.text('同号 10010'), findsOneWidget);
    expect(find.text('“流量”'), findsOneWidget);
    expect(find.textContaining('流量提醒'), findsOneWidget);
  });
}
