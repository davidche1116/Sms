import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_sms_channel.dart';

/// 删除进度细粒度（P3-18）：分块真实进度、失败中断、取消停发。
///
/// 默认 deleteChunkSize=200；夹具造 450 条有 id 行 → 3 块（200/200/50）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpHomeHarness();

  /// 450 条有 id 的 SMS 行；date 降序键 = bulk-i（i 越小越新）。
  List<Map<String, dynamic>> bulkRows(int n) => [
    for (var i = 1; i <= n; i++)
      {
        '_id': i,
        'thread_id': i,
        'address': '100${i % 1000}',
        'body': 'bulk-$i',
        'date': sampleToday.millisecondsSinceEpoch - i * 1000,
        'read': 1,
        'type': 1,
        'sub_id': 1,
      },
  ];

  testWidgets('分块删除：通道按块调用，完成后全删并 toast', (tester) async {
    var calls = 0;
    mockHomeChannel(
      queryResult: {'messages': bulkRows(450), 'error': null},
      onDelete: (ids) {
        calls++;
        return ids.length;
      },
    );
    await pumpHome(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认删除'));
    await tester.pumpAndSettle();

    expect(calls, 3); // 200 + 200 + 50
    expect(find.text('已删除 450 条'), findsOneWidget);
    expect(find.textContaining('bulk-'), findsNothing);
  });

  testWidgets('分块删除：进度与「已删 X，不可撤销」随块更新', (tester) async {
    final gate = Completer<void>();
    var calls = 0;
    mockHomeChannel(
      queryResult: {'messages': bulkRows(450), 'error': null},
      onDelete: (ids) {
        calls++;
        // 第 2 块悬住，便于观察中间进度
        if (calls == 2) {
          return gate.future.then((_) => ids.length);
        }
        return ids.length;
      },
    );
    await pumpHome(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认删除'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(calls, 2);
    expect(find.text('已完成 200 / 450'), findsOneWidget);
    expect(find.text('已删 200，不可撤销'), findsOneWidget);
    expect(find.text('停止'), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('已删除 450 条'), findsOneWidget);
    expect(find.textContaining('bulk-'), findsNothing);
  });

  testWidgets('某块失败：停止后续块，toast 已删 X / N 并移除已删', (tester) async {
    var calls = 0;
    mockHomeChannel(
      queryResult: {'messages': bulkRows(450), 'error': null},
      onDelete: (ids) {
        calls++;
        return calls == 2 ? null : ids.length;
      },
    );
    await pumpHome(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认删除'));
    await tester.pumpAndSettle();

    expect(calls, 2); // 第 2 块失败后不再发第 3 块
    expect(find.text('已删除 200 / 450 条后失败'), findsOneWidget);
    // 已删前缀从列表消失，未删的仍在（首屏可见 bulk-201）
    expect(find.textContaining('bulk-1'), findsNothing);
    expect(find.textContaining('bulk-200'), findsNothing);
    expect(find.textContaining('bulk-201'), findsOneWidget);
  });

  testWidgets('取消：停止后续块，toast 已取消并移除已删', (tester) async {
    final gate = Completer<void>();
    var calls = 0;
    mockHomeChannel(
      queryResult: {'messages': bulkRows(450), 'error': null},
      onDelete: (ids) {
        calls++;
        if (calls == 1) {
          return gate.future.then((_) => ids.length);
        }
        return ids.length;
      },
    );
    await pumpHome(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认删除'));
    await tester.pump();
    expect(find.text('停止'), findsOneWidget);
    expect(find.text('删除中…'), findsOneWidget);

    await tester.tap(find.text('停止'));
    await tester.pump();
    expect(find.text('停止中…'), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();

    // 已发出的首块不撤回（200），后续 2 块不再发
    expect(calls, 1);
    expect(find.text('已取消，已删除 200 条'), findsOneWidget);
    expect(find.textContaining('bulk-1'), findsNothing);
    expect(find.textContaining('bulk-201'), findsOneWidget);
  });

  testWidgets('首块失败零删除：保持失败文案，列表不变', (tester) async {
    mockHomeChannel(
      queryResult: {'messages': bulkRows(450), 'error': null},
      onDelete: (_) => null,
    );
    await pumpHome(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认删除'));
    await tester.pumpAndSettle();

    expect(find.textContaining('删除失败'), findsOneWidget);
    expect(find.textContaining('bulk-1'), findsOneWidget);
    // 零删除：不进入「已删 X / N」部分失败文案
    expect(find.textContaining('条后失败'), findsNothing);
  });

  testWidgets('零删除且非默认：toast 提示设为默认', (tester) async {
    mockHomeChannel(
      queryResult: {'messages': bulkRows(450), 'error': null},
      onDelete: (_) {
        return {
          'ok': false,
          'deleted': 0,
          'failed': 450,
          'error': 'not_default',
          'errors': [
            {
              'index': -1,
              'code': 'not_default',
              'message': 'not default sms app',
            },
          ],
        };
      },
    );
    await pumpHome(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认删除'));
    await tester.pumpAndSettle();

    expect(find.text('删除失败：请先设为默认短信应用'), findsOneWidget);
    expect(find.textContaining('bulk-1'), findsOneWidget);
  });

  testWidgets('零删除且原生异常：toast 不误报设为默认', (tester) async {
    mockHomeChannel(
      queryResult: {'messages': bulkRows(450), 'error': null},
      onDelete: (_) {
        return {
          'ok': false,
          'deleted': 0,
          'failed': 450,
          'error': 'failed',
          'errors': [
            {'index': 0, 'code': 'failed', 'message': 'boom'},
          ],
        };
      },
    );
    await pumpHome(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认删除'));
    await tester.pumpAndSettle();

    expect(find.text('删除失败，请重试'), findsOneWidget);
    expect(find.textContaining('设为默认'), findsNothing);
    expect(find.textContaining('bulk-1'), findsOneWidget);
  });

  testWidgets('中途原生异常：部分文案，不提示设为默认', (tester) async {
    var calls = 0;
    mockHomeChannel(
      queryResult: {'messages': bulkRows(450), 'error': null},
      onDelete: (ids) {
        calls++;
        if (calls == 1) return ids.length;
        return {
          'ok': false,
          'deleted': 0,
          'failed': ids.length,
          'error': 'failed',
          'errors': [
            {'index': 0, 'code': 'failed', 'message': 'boom'},
          ],
        };
      },
    );
    await pumpHome(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认删除'));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.text('已删除 200 / 450 条后失败'), findsOneWidget);
    expect(find.textContaining('设为默认'), findsNothing);
  });

  testWidgets('块内部分失败：停止后续块，按前缀报部分文案', (tester) async {
    var calls = 0;
    mockHomeChannel(
      queryResult: {'messages': bulkRows(450), 'error': null},
      onDelete: (ids) {
        calls++;
        if (calls == 1) return ids.length;
        return {
          'ok': true,
          'deleted': 1,
          'failed': ids.length - 1,
          'error': null,
          'errors': [
            for (var i = 1; i < ids.length; i++)
              {'index': i, 'code': 'failed', 'message': 'boom'},
          ],
        };
      },
    );
    await pumpHome(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认删除'));
    await tester.pumpAndSettle();

    expect(calls, 2); // 第 3 块不再发出
    // 部分失败块不计入已删前缀：只报第 1 块的 200
    expect(find.text('已删除 200 / 450 条后失败'), findsOneWidget);
    expect(find.textContaining('设为默认'), findsNothing);
    // 已删前缀（bulk-1..200）移除；部分失败块的行仍在（保守不删）
    expect(find.textContaining('bulk-1'), findsNothing);
    expect(find.textContaining('bulk-200'), findsNothing);
    expect(find.textContaining('bulk-201'), findsOneWidget);
  });

  testWidgets('单条滑删成功语义不回退', (tester) async {
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
    expect(find.textContaining('验证码 8888'), findsOneWidget);
  });

  testWidgets('进度弹层仍保留 >3000 警告', (tester) async {
    mockHomeChannel(
      queryResult: {'messages': bulkRows(3001), 'error': null, 'total': 3001},
    );
    await pumpHome(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('删除短信？'), findsOneWidget);
    expect(find.textContaining('数量较大'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.textContaining('数量较大'), findsNothing);
  });
}
