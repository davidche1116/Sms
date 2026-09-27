import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sms/app.dart';

/// 分页/增量加载：启动第一页、触底追加、按 _id 去重、筛选补全量。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const appChannel = MethodChannel('com.dc16.sms/smsApp');
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

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(appChannel, null);
  });

  /// 返回每次 querySms 的 `{limit, offset}`，便于断言分页参数。
  List<Map<String, dynamic>> mockPaged({
    required List<Map<String, dynamic>> all,
    bool Function(List<Map<String, dynamic>> page)? injectDup,
  }) {
    final calls = <Map<String, dynamic>>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(appChannel, (call) async {
          switch (call.method) {
            case 'hasReadSmsPermission':
              return true;
            case 'isDefaultSms':
              return true;
            case 'isMiui':
              return false;
            case 'querySms':
              final args = Map<Object?, Object?>.from(
                call.arguments as Map? ?? {},
              );
              calls.add({
                'limit': args['limit'],
                'offset': args['offset'],
              });
              final limit = (args['limit'] as num?)?.toInt();
              final offset = (args['offset'] as num?)?.toInt() ?? 0;
              var page = all.skip(offset);
              if (limit != null) page = page.take(limit);
              final rows = page.toList();
              if (injectDup?.call(rows) == true) {
                rows.addAll(rows.take(5).toList());
              }
              return {'messages': rows, 'total': all.length, 'error': null};
            default:
              return null;
          }
        });
    return calls;
  }

  testWidgets('启动加载第一页，顶栏显示已加载 X / total', (tester) async {
    final calls = mockPaged(all: buildRows(250));
    await tester.pumpWidget(const SmsApp());
    await tester.pumpAndSettle();

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
    await tester.pumpWidget(const SmsApp());
    await tester.pumpAndSettle();

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -200000));
    await tester.pumpAndSettle();

    expect(calls.length, greaterThanOrEqualTo(2));
    // 第一页 200 条去重后 offset=200（不是 205）
    expect(calls[1], {'limit': 200, 'offset': 200});
    // 全部加载后顶栏回到「250 条」
    expect(find.text('250 条'), findsOneWidget);
    expect(find.textContaining('已加载'), findsNothing);
  });

  testWidgets('筛选激活时补齐全量（querySms 不带 limit）', (tester) async {
    final calls = mockPaged(all: buildRows(250));
    await tester.pumpWidget(const SmsApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'msg-250');
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    // 最后一次 querySms 必须是全量（不带 limit）
    expect(calls.last['limit'], isNull);
    expect(find.text('msg-250'), findsOneWidget);
    expect(find.text('msg-1'), findsNothing);
    expect(find.text('1 条'), findsOneWidget);
  });
}
