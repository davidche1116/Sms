import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sms/app.dart';

import 'helpers/app_channel.dart';

/// 分页/增量加载：启动第一页、触底追加、按 _id 去重、筛选补全量。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final base = DateTime(2026, 9, 26, 12, 0);

  List<Map<String, dynamic>> buildRows(int n) => [
    for (var i = 0; i < n; i++)
      {
        '_id': i + 1,
        'thread_id': 1,
        'address': '10086',
        'body': 'msg-${i + 1}',
        'date': base.subtract(Duration(minutes: i)).millisecondsSinceEpoch,
        'read': 1,
        'type': 1,
        'sub_id': 1,
      },
  ];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(clearAppChannelHandler);

  /// 断言文案为中文，固定 locale。
  Future<void> pumpSmsApp(WidgetTester tester) async {
    await tester.pumpWidget(const SmsApp(locale: Locale('zh')));
    await tester.pumpAndSettle();
  }

  /// 返回每次 querySms 的 `{limit, offset, keyword?}`，便于断言分页参数。
  List<Map<String, dynamic>> mockPaged({
    required List<Map<String, dynamic>> all,
    bool Function(List<Map<String, dynamic>> page)? injectDup,
  }) {
    final calls = <Map<String, dynamic>>[];
    setAppChannelHandler((call) async {
      switch (call.method) {
        case 'hasReadSmsPermission':
          return true;
        case 'isDefaultSms':
          return true;
        case 'isMiui':
          return false;
        case 'querySms':
          final args = Map<Object?, Object?>.from(call.arguments as Map? ?? {});
          final keyword = args['keyword'] as String?;
          final callRecord = <String, dynamic>{
            'limit': args['limit'],
            'offset': args['offset'],
          };
          if (keyword != null) callRecord['keyword'] = keyword;
          calls.add(callRecord);
          // 模拟服务端 keyword 过滤
          var filtered = all;
          if (keyword != null && keyword.isNotEmpty) {
            filtered = all.where((row) {
              final body = row['body'] as String? ?? '';
              final addr = row['address'] as String? ?? '';
              return body.contains(keyword) || addr.contains(keyword);
            }).toList();
          }
          final limit = (args['limit'] as num?)?.toInt();
          final offset = (args['offset'] as num?)?.toInt() ?? 0;
          var page = filtered.skip(offset);
          if (limit != null) page = page.take(limit);
          final rows = page.toList();
          if (injectDup?.call(rows) == true) {
            rows.addAll(rows.take(5).toList());
          }
          return {'messages': rows, 'total': filtered.length, 'error': null};
        default:
          return null;
      }
    });
    return calls;
  }

  testWidgets('启动加载第一页，顶栏显示已加载 X / total', (tester) async {
    final calls = mockPaged(all: buildRows(250));
    await pumpSmsApp(tester);

    expect(calls, [
      {'limit': 200, 'offset': 0},
    ]);
    // SliverList 懒构建：只断言首屏可见项 + 顶栏计数（已加载 200/250）
    expect(find.textContaining('已加载'), findsOneWidget);
    expect(find.textContaining('200 / 250 条'), findsOneWidget);
    expect(find.text('msg-1'), findsOneWidget);
    expect(find.text('msg-2'), findsOneWidget);
    // 未请求第二页，offset 仍停在 0
    expect(calls.length, 1);
  });

  testWidgets('滚动触底加载下一页并按 _id 去重追加', (tester) async {
    // 第一页故意重复 5 条，验证追加/展示仍按 _id 去重
    final calls = mockPaged(
      all: buildRows(250),
      injectDup: (page) => page.length >= 200,
    );
    await pumpSmsApp(tester);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -200000));
    await tester.pumpAndSettle();

    expect(calls.length, greaterThanOrEqualTo(2));
    // 第一页 200 条去重后 offset=200（不是 205）
    expect(calls[1], {'limit': 200, 'offset': 200});
    // 全部加载后顶栏回到「250 条」
    expect(find.text('250 条'), findsOneWidget);
    expect(find.textContaining('已加载'), findsNothing);
  });

  testWidgets('筛选激活时使用服务端筛选（带 keyword 参数分页）', (tester) async {
    final calls = mockPaged(all: buildRows(250));
    await pumpSmsApp(tester);

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'msg-250');
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    // 服务端筛选：带 keyword 参数，仍分页（limit=200）
    expect(calls.last['limit'], 200);
    expect(calls.last['keyword'], 'msg-250');
    // mock 模拟服务端过滤后只返回匹配行
    expect(find.text('msg-250'), findsOneWidget);
    expect(find.text('msg-1'), findsNothing);
    expect(find.text('1 条'), findsOneWidget);
  });

  testWidgets('清除关键词 chip 后整库重载，不残留服务端过滤子集', (tester) async {
    final calls = mockPaged(all: buildRows(250));
    await pumpSmsApp(tester);

    // 激活服务端关键词过滤 → 列表只剩匹配子集
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'msg-250');
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    expect(find.text('1 条'), findsOneWidget);

    // 删除关键词 chip → 必须重新查询第一页（不带 keyword）
    calls.clear();
    await tester.tap(
      find.descendant(
        of: find.byType(Chip),
        matching: find.byIcon(Icons.close),
      ),
    );
    await tester.pumpAndSettle();

    expect(calls, [
      {'limit': 200, 'offset': 0},
    ]);
    expect(find.text('msg-1'), findsOneWidget);
    expect(find.textContaining('200 / 250 条'), findsOneWidget);
  });

  testWidgets('partial=true 时显示「部分短信可能未加载」横幅，可点按重试', (tester) async {
    var partial = true;
    var queryCount = 0;
    setAppChannelHandler((call) async {
      switch (call.method) {
        case 'hasReadSmsPermission':
          return true;
        case 'isDefaultSms':
          return true;
        case 'isMiui':
          return false;
        case 'querySms':
          queryCount++;
          return {
            'messages': buildRows(3),
            'total': 3,
            'error': null,
            'partial': partial,
            if (partial)
              'warnings': [
                {'code': 'mms_uri_security', 'message': 'mms query restricted'},
              ],
          };
        default:
          return null;
      }
    });

    await pumpSmsApp(tester);
    expect(find.textContaining('部分短信可能未加载'), findsOneWidget);
    expect(find.text('msg-1'), findsOneWidget);

    // 恢复完整后重试 → 横幅消失
    partial = false;
    await tester.tap(find.textContaining('部分短信可能未加载'));
    await tester.pumpAndSettle();
    expect(queryCount, 2);
    expect(find.textContaining('部分短信可能未加载'), findsNothing);
  });

  testWidgets('partial=false 不显示横幅', (tester) async {
    setAppChannelHandler((call) async {
      switch (call.method) {
        case 'hasReadSmsPermission':
          return true;
        case 'isDefaultSms':
          return true;
        case 'isMiui':
          return false;
        case 'querySms':
          return {'messages': buildRows(2), 'total': 2, 'error': null};
        default:
          return null;
      }
    });

    await pumpSmsApp(tester);
    expect(find.textContaining('部分短信可能未加载'), findsNothing);
  });
}
