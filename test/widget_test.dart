import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sms/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const appChannel = MethodChannel('com.dc16.sms/smsApp');

  setUp(() {
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
                    'date': DateTime(2026, 9, 26, 11, 2).millisecondsSinceEpoch,
                    'date_sent':
                        DateTime(2026, 9, 26, 11, 2).millisecondsSinceEpoch,
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
}
