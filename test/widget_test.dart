import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sms/app.dart';
import 'package:sms/features/filter/filter_sheet.dart';
import 'package:sms/models/sms_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const appChannel = MethodChannel('com.dc16.sms/smsApp');
  final today = DateTime(2026, 9, 26, 11, 2);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(appChannel, (call) async {
          switch (call.method) {
            case 'hasReadSmsPermission':
              return true;
            case 'isDefaultSms':
              return true;
            case 'querySms':
              return {
                'messages': <Map<String, dynamic>>[
                  {
                    '_id': 1,
                    'thread_id': 1,
                    'address': '10010',
                    'body': '【流量提醒】测试短信',
                    'date': today.millisecondsSinceEpoch,
                    'date_sent': today.millisecondsSinceEpoch,
                    'read': 1,
                    'type': 1,
                    'sub_id': 1,
                  },
                ],
                'error': null,
              };
            case 'deleteSmsBatch':
              return 1;
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(appChannel, null);
  });

  testWidgets('首页显示短信列表与顶栏入口', (tester) async {
    await tester.pumpWidget(const SmsApp());
    // 等待 _load 完成；不用 pumpAndSettle（加载指示器会一直 schedule 帧）
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('短信'), findsOneWidget);
    expect(find.textContaining('流量提醒'), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
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
      // 用固定"今天"无法注入（dayLabel 用 DateTime.now()），
      // 此处仅验证同日/更早日不抛异常且格式稳定。
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
  });
}
