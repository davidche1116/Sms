import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sms/app.dart';
import 'package:sms/features/filter/filter_sheet.dart';
import 'package:sms/models/sms_item.dart';
import 'package:sms/services/csv_exporter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const appChannel = MethodChannel('com.dc16.sms/smsApp');
  final today = DateTime(2026, 9, 26, 11, 2);
  final yesterday = DateTime(2026, 9, 25, 9, 0);
  final older = DateTime(2026, 8, 1, 8, 0);

  List<Map<String, dynamic>> sampleRows() => [
    {
      '_id': 1,
      'thread_id': 1,
      'address': '10010',
      'body': '【流量提醒】测试短信',
      'date': today.millisecondsSinceEpoch,
      'read': 1,
      'type': 1,
      'sub_id': 1,
    },
    {
      '_id': 2,
      'thread_id': 2,
      'address': '10086',
      'body': '验证码 8888，勿泄露',
      'date': yesterday.millisecondsSinceEpoch,
      'read': 0,
      'type': 1,
      'sub_id': 1,
    },
    {
      '_id': 3,
      'thread_id': 3,
      'address': '13800000000',
      'body': '已发送：好的，收到',
      'date': older.millisecondsSinceEpoch,
      'read': 1,
      'type': 2,
      'sub_id': 2,
    },
    {
      // 无 id 行：防御路径，不可选中
      'thread_id': 4,
      'address': '10000',
      'body': '无 id 行',
      'date': today.millisecondsSinceEpoch,
      'read': 1,
      'type': 1,
      'sub_id': 1,
    },
  ];

  void mockChannel({
    Object? queryResult,
    int Function(List<int> ids)? onDelete,
  }) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(appChannel, (call) async {
          switch (call.method) {
            case 'hasReadSmsPermission':
              return true;
            case 'isDefaultSms':
              return true;
            case 'querySms':
              return queryResult ??
                  {
                    'messages': sampleRows(),
                    'error': null,
                  };
            case 'deleteSmsBatch':
              final ids = (call.arguments as List).cast<int>();
              return onDelete?.call(ids) ?? ids.length;
            default:
              return null;
          }
        });
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockChannel();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(appChannel, null);
  });

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(const SmsApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('首页显示短信列表与顶栏入口', (tester) async {
    await pumpHome(tester);

    expect(find.text('短信'), findsOneWidget);
    expect(find.textContaining('流量提醒'), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
  });

  testWidgets('error=permission 时展示 NeedPerm 空态', (tester) async {
    mockChannel(queryResult: {
      'messages': <Map<String, dynamic>>[],
      'error': 'permission',
    });
    await pumpHome(tester);

    expect(find.text('需要短信权限'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '申请短信权限'), findsOneWidget);
    expect(find.textContaining('设为默认短信应用'), findsWidgets);
  });

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

  group('SmsItem 映射（QUERY_DELETE_DESIGN §5.8 / §10）', () {
    test('type → kind：1 收件 / 2,4,5,6 发送 / 3 草稿', () {
      expect(const SmsItem(body: 'a', address: 'b', type: 1).kind,
          SmsKind.received);
      for (final t in [2, 4, 5, 6]) {
        expect(SmsItem(body: 'a', address: 'b', type: t).kind, SmsKind.sent);
      }
      expect(
          const SmsItem(body: 'a', address: 'b', type: 3).kind, SmsKind.draft);
    });

    test('type 缺省按收件处理；date 为 null 不崩溃', () {
      final e = const SmsItem(body: 'a', address: 'b');
      expect(e.kind, SmsKind.received);
      expect(e.time, '');
      expect(e.dayLabel, '未知');
    });

    test('昨天标签跨月正确（10-01 的前一条 09-30）', () {
      final ms = DateTime(2000, 1, 1).millisecondsSinceEpoch;
      final e = SmsItem(body: 'a', address: 'b', dateMs: ms);
      expect(e.dayLabel, '2000-01-01');
      expect(e.time, '01-01');
    });
  });

  group('SmsFilter（features/filter）', () {
    test('active 与 reset', () {
      final f = SmsFilter();
      expect(f.active, isFalse);
      f
        ..keyword = '验证码'
        ..type = 2;
      expect(f.active, isTrue);
      f.reset();
      expect(f.active, isFalse);
      expect(f.type, 0);
    });

    test('copy 生成独立副本', () {
      final f = SmsFilter()
        ..keyword = 'x'
        ..sameSim = 2;
      final c = f.copy();
      f.keyword = 'y';
      expect(c.keyword, 'x');
      expect(c.sameSim, 2);
    });

    test('matches：关键词 / 同号 / 同卡 / 类型 / 日期', () {
      final items = [
        const SmsItem(
          id: 1,
          body: '流量提醒',
          address: '10010',
          dateMs: 0,
          type: 1,
          sim: 1,
        ),
        const SmsItem(
          id: 2,
          body: '验证码 8888',
          address: '10086',
          dateMs: 0,
          type: 1,
          sim: 1,
        ),
        const SmsItem(
          id: 3,
          body: '好的',
          address: '138',
          dateMs: 0,
          type: 2,
          sim: 2,
        ),
        // date null：日期筛选时被丢弃，无日期筛选时保留
        const SmsItem(id: 4, body: '无日期', address: '1', type: 1, sim: 1),
      ];

      final byKeyword = SmsFilter()..keyword = '验证码';
      expect(items.where(byKeyword.matches).map((e) => e.id), [2]);

      final byAddr = SmsFilter()..sameAddress = '10010';
      expect(items.where(byAddr.matches).map((e) => e.id), [1]);

      final bySim = SmsFilter()..sameSim = 2;
      expect(items.where(bySim.matches).map((e) => e.id), [3]);

      final byType = SmsFilter()..type = 2;
      expect(items.where(byType.matches).map((e) => e.id), [3]);

      final byDate = SmsFilter()..start = DateTime(2000, 1, 2);
      expect(items.where(byDate.matches).map((e) => e.id), isEmpty);
    });
  });

  group('CsvExporter.escapeField（RFC 4180）', () {
    test('普通字段不加引号', () {
      expect(CsvExporter.escapeField('10086'), '10086');
      expect(CsvExporter.escapeField('你好'), '你好');
    });

    test('逗号 / 引号 / 换行需转义，内部引号翻倍', () {
      expect(CsvExporter.escapeField('a,b'), '"a,b"');
      expect(CsvExporter.escapeField('say "hi"'), '"say ""hi"""');
      expect(CsvExporter.escapeField('line1\nline2'), '"line1\nline2"');
      expect(CsvExporter.escapeField('a\r\nb'), '"a\r\nb"');
    });
  });
}
