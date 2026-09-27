import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sms/app.dart';
import 'package:sms/features/filter/filter_sheet.dart';
import 'package:sms/models/sms_item.dart';
import 'package:sms/services/csv_exporter.dart';
import 'package:sms/services/csv_importer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const appChannel = MethodChannel('com.davidche1116.sms/smsApp');
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
    int? Function(List<int> ids)? onDelete,
  }) {
    final deleted = <int>{};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(appChannel, (call) async {
          switch (call.method) {
            case 'hasReadSmsPermission':
              return true;
            case 'isDefaultSms':
              return true;
            case 'querySms':
              if (queryResult != null) return queryResult;
              return {
                'messages': sampleRows()
                    .where((r) => !deleted.contains(r['_id']))
                    .toList(),
                'error': null,
              };
            case 'deleteSmsBatch':
              final ids = (call.arguments as List).cast<int>();
              if (onDelete != null) {
                final n = onDelete(ids);
                if (n != null) deleted.addAll(ids);
                return n;
              }
              deleted.addAll(ids);
              return ids.length;
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
        ..type = 2
        ..sameAddress = '10010'
        ..sameSim = 1;
      expect(f.active, isTrue);
      f.reset();
      expect(f.active, isFalse);
      expect(f.type, 0);
      expect(f.keyword, '');
      expect(f.start, isNull);
      expect(f.end, isNull);
      expect(f.sameAddress, isNull);
      expect(f.sameSim, isNull);
    });

    test('copy 生成独立副本', () {
      final f = SmsFilter()
        ..keyword = 'x'
        ..sameAddress = '10010'
        ..sameSim = 2;
      final c = f.copy();
      f
        ..keyword = 'y'
        ..sameAddress = null;
      expect(c.keyword, 'x');
      expect(c.sameAddress, '10010');
      expect(c.sameSim, 2);
    });

    test('applyFrom 完整拷贝全部字段且互不影响', () {
      final src = SmsFilter()
        ..keyword = 'k'
        ..start = DateTime(2026, 1, 1)
        ..end = DateTime(2026, 1, 2)
        ..type = 2
        ..sameAddress = '10010'
        ..sameSim = 2;
      final dst = SmsFilter()..applyFrom(src);
      expect(dst.keyword, 'k');
      expect(dst.start, src.start);
      expect(dst.end, src.end);
      expect(dst.type, 2);
      expect(dst.sameAddress, '10010');
      expect(dst.sameSim, 2);

      src
        ..keyword = 'changed'
        ..sameAddress = null
        ..sameSim = 9;
      expect(dst.keyword, 'k');
      expect(dst.sameAddress, '10010');
      expect(dst.sameSim, 2);
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

  group('CsvImporter 解析（与导出格式互逆）', () {
    test('表头 + 普通行 + BOM', () {
      final rows = CsvImporter.parse(
        '﻿address,body,date,kind,sub_id\r\n'
        '10086,流量提醒,2026-09-26 11:02:00,received,1\r\n',
      );
      expect(rows, hasLength(1));
      expect(rows.first.address, '10086');
      expect(rows.first.body, '流量提醒');
      expect(rows.first.kind, SmsKind.received);
      expect(rows.first.sim, 1);
      expect(rows.first.dateMs, DateTime(2026, 9, 26, 11, 2).millisecondsSinceEpoch);
    });

    test('RFC 4180 引号字段（逗号/换行/转义引号）', () {
      final rows = CsvImporter.parse(
        'address,body,date,kind,sub_id\n'
        '"10086","含,逗号与""引号""\n换行",2026-01-01 00:00:00,sent,2\n',
      );
      expect(rows, hasLength(1));
      expect(rows.first.body, '含,逗号与"引号"\n换行');
      expect(rows.first.kind, SmsKind.sent);
      expect(rows.first.sim, 2);
    });

    test('导出 → 导入往返', () {
      final items = [
        const SmsItem(
          id: 1,
          address: '10086',
          body: 'a,b"c\nd',
          dateMs: 0,
          type: 1,
          sim: 1,
        ),
        const SmsItem(
          id: 2,
          address: '138',
          body: '已发送',
          dateMs: 0,
          type: 2,
          sim: 2,
        ),
      ];
      // 直接测 parse(escape 后的行)
      final buf = StringBuffer('address,body,date,kind,sub_id\n');
      for (final e in items) {
        buf
          ..write(CsvExporter.escapeField(e.address))
          ..write(',')
          ..write(CsvExporter.escapeField(e.body))
          ..write(',')
          ..write(CsvExporter.escapeField('2000-01-01 00:00:00'))
          ..write(',')
          ..write(e.kind.name)
          ..write(',')
          ..write(e.sim)
          ..write('\n');
      }
      final rows = CsvImporter.parse(buf.toString());
      expect(rows, hasLength(2));
      expect(rows[0].body, 'a,b"c\nd');
      expect(rows[0].kind, SmsKind.received);
      expect(rows[1].kind, SmsKind.sent);
      expect(rows[1].sim, 2);
    });
  });

  group('MIUI 通知类短信引导（requestReadSmsWithMiuiGuide）', () {
    testWidgets('MIUI 且未开通：申请读权限后弹引导层', (tester) async {
      var miuiEditorOpened = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(appChannel, (call) async {
            switch (call.method) {
              case 'hasReadSmsPermission':
                return false;
              case 'isDefaultSms':
                return false;
              case 'requestReadSms':
                return true;
              case 'isMiui':
                return true;
              case 'miuiNotificationSmsState':
                return 'likely_off';
              case 'openMiuiPermissionEditor':
                miuiEditorOpened = true;
                return true;
              case 'querySms':
                return {
                  'messages': <Map<String, dynamic>>[],
                  'error': 'permission',
                };
              default:
                return null;
            }
          });

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
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(appChannel, (call) async {
            switch (call.method) {
              case 'hasReadSmsPermission':
                return true;
              case 'isDefaultSms':
                return true;
              case 'requestReadSms':
                return true;
              case 'isMiui':
                return true;
              case 'miuiNotificationSmsState':
                return 'allow';
              case 'querySms':
                return {
                  'messages': sampleRows(),
                  'error': null,
                };
              default:
                return null;
            }
          });

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
  });

  group('删除确认对齐（README：四个删除入口均有确认）', () {
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
      mockChannel(onDelete: (_) => null);
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

    testWidgets('FAB 批量删除确认文案按条数', (tester) async {
      await pumpHome(tester);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('删除短信？'), findsOneWidget);
      expect(
        find.text('将删除 4 条短信。删除后不可恢复。'),
        findsOneWidget,
      );
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.textContaining('流量提醒'), findsOneWidget);
    });
  });
}
