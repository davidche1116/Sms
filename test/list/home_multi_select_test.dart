import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_sms_channel.dart';

/// 多选：_id 对齐、点选/全选、无 id 行防御。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpHomeHarness();

  testWidgets('筛选后多选仍按 _id 对齐（不错位）', (tester) async {
    await pumpHome(tester);
    final body = find.textContaining('验证码 8888');
    expect(body, findsOneWidget);

    // 进入多选并选中「验证码」那条（id=2）
    await tester.longPress(body);
    await tester.pumpAndSettle();
    expect(find.text('已选 1'), findsOneWidget);

    // 退出多选，打开筛选，只保留关键词「验证码」
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '验证码');
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    // 筛选后只剩 1 条；重新多选，应只命中 id=2
    await tester.longPress(find.textContaining('验证码 8888'));
    await tester.pumpAndSettle();
    expect(find.text('已选 1'), findsOneWidget);
    expect(find.textContaining('流量提醒'), findsNothing);
    expect(find.textContaining('已发送'), findsNothing);
  });

  testWidgets('长按进入多选，点选切换计数', (tester) async {
    await pumpHome(tester);

    await tester.longPress(find.textContaining('流量提醒'));
    await tester.pumpAndSettle();
    expect(find.text('已选 1'), findsOneWidget);

    // 再点另一条 → 2；再点同一条取消 → 1
    await tester.tap(find.textContaining('验证码 8888'));
    await tester.pumpAndSettle();
    expect(find.text('已选 2'), findsOneWidget);

    await tester.tap(find.textContaining('验证码 8888'));
    await tester.pumpAndSettle();
    expect(find.text('已选 1'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.textContaining('已选'), findsNothing);
  });

  testWidgets('无 id 行不可长按进入多选；全选只计有 id 行', (tester) async {
    await pumpHome(tester);

    await tester.longPress(find.textContaining('无 id 行'));
    await tester.pumpAndSettle();
    expect(find.textContaining('已选'), findsNothing);

    // 从有 id 行进入多选后全选：3 条有 id（无 id 行不计）
    await tester.longPress(find.textContaining('流量提醒'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('全选'));
    await tester.pumpAndSettle();
    expect(find.text('已选 3'), findsOneWidget);
  });
}
