import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_sms_channel.dart';

/// 删除确认对齐（README：四个删除入口均有确认）。
/// 覆盖滑删取消/成功/失败回弹、动作 Sheet、FAB、多选删除。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpHomeHarness();

  testWidgets('滑删弹确认；取消后卡片回弹仍在', (tester) async {
    await pumpHome(tester);
    expect(find.textContaining('流量提醒'), findsOneWidget);

    await tester.fling(
      find.textContaining('流量提醒'),
      const Offset(-500, 0),
      1000,
    );
    await tester.pumpAndSettle();

    expect(find.text('删除短信？'), findsOneWidget);
    expect(find.text('将删除 1 条短信。删除后不可恢复。'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(find.text('删除短信？'), findsNothing);
    expect(find.textContaining('流量提醒'), findsOneWidget);
  });

  testWidgets('滑删确认后删除成功：卡片移除', (tester) async {
    await pumpHome(tester);

    await tester.fling(
      find.textContaining('流量提醒'),
      const Offset(-500, 0),
      1000,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认删除'));
    await tester.pumpAndSettle();

    expect(find.textContaining('流量提醒'), findsNothing);
    // 其余仍在
    expect(find.textContaining('验证码 8888'), findsOneWidget);
  });

  testWidgets('滑删确认但删除失败：卡片回弹不消失', (tester) async {
    mockHomeChannel(onDelete: (_) => null);
    await pumpHome(tester);

    await tester.fling(
      find.textContaining('流量提醒'),
      const Offset(-500, 0),
      1000,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认删除'));
    await tester.pumpAndSettle();

    expect(find.textContaining('删除失败'), findsOneWidget);
    expect(find.textContaining('流量提醒'), findsOneWidget);
  });

  testWidgets('动作 Sheet 删除同样先确认；取消不删', (tester) async {
    await pumpHome(tester);
    await tester.tap(find.textContaining('流量提醒'));
    await tester.pumpAndSettle();

    expect(find.text('删除'), findsOneWidget);
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(find.text('删除短信？'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(find.textContaining('流量提醒'), findsOneWidget);
  });

  testWidgets('动作 Sheet 确认删除：卡片移除', (tester) async {
    await pumpHome(tester);
    await tester.tap(find.textContaining('流量提醒'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('确认删除'));
    await tester.pumpAndSettle();

    expect(find.textContaining('流量提醒'), findsNothing);
    expect(find.textContaining('验证码 8888'), findsOneWidget);
  });

  testWidgets('FAB 批量删除确认文案按条数', (tester) async {
    await pumpHome(tester);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('删除短信？'), findsOneWidget);
    // 4 行里 1 行无 id 不可删，文案只计 3 条可删目标
    expect(find.text('将删除 3 条短信。删除后不可恢复。'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.textContaining('流量提醒'), findsOneWidget);
  });

  testWidgets('多选删除确认文案按已选条数；取消不删', (tester) async {
    await pumpHome(tester);
    await tester.longPress(find.textContaining('流量提醒'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('验证码 8888'));
    await tester.pumpAndSettle();
    expect(find.text('已选 2'), findsOneWidget);

    await tester.tap(find.text('删除选中'));
    await tester.pumpAndSettle();

    expect(find.text('删除短信？'), findsOneWidget);
    expect(find.text('将删除 2 条短信。删除后不可恢复。'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(find.textContaining('流量提醒'), findsOneWidget);
    expect(find.textContaining('验证码 8888'), findsOneWidget);
  });
}
