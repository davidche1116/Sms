import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sms/services/sms_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const appChannel = MethodChannel('com.dc16.sms/smsApp');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(appChannel, null);
  });

  Map<String, dynamic> row(int id, int dateMs) => {
    '_id': id,
    'thread_id': 1,
    'address': '100$id',
    'body': 'b$id',
    'date': dateMs,
    'read': 1,
    'type': 1,
    'sub_id': 1,
  };

  void mockQuery(Object? Function(Map args) respond) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(appChannel, (call) async {
          if (call.method != 'querySms') return null;
          return respond(Map<Object?, Object?>.from(call.arguments as Map? ?? {}));
        });
  }

  group('SmsRepository.queryPage（分页契约）', () {
    test('传递 limit/offset，映射 items 与 total', () async {
      Object? args;
      mockQuery((a) {
        args = a;
        return {
          'messages': [row(3, 300), row(2, 200)],
          'total': 10,
          'error': null,
        };
      });

      final page = await SmsRepository().queryPage(limit: 2, offset: 4);
      expect(args, {'limit': 2, 'offset': 4});
      expect(page.total, 10);
      expect(page.items.map((e) => e.id), [3, 2]);
      expect(page.items.map((e) => e.body), ['b3', 'b2']);
      expect(page.hasMore(2, 2), isTrue);
      expect(page.hasMore(10, 2), isFalse);
    });

    test('不传 limit/offset 时不带分页键（兼容旧调用）', () async {
      Object? args;
      mockQuery((a) {
        args = a;
        return {
          'messages': [row(1, 100)],
          'total': 1,
          'error': null,
        };
      });

      final page = await SmsRepository().queryPage();
      expect(args, isEmpty);
      expect(page.items.single.id, 1);
      expect(page.total, 1);
    });

    test('按 date 降序映射，date 缺失视为最早', () async {
      mockQuery((_) {
        return {
          'messages': [
            row(1, 100),
            {
              '_id': 2,
              'thread_id': 1,
              'address': 'x',
              'body': 'no-date',
              'read': 1,
              'type': 1,
              'sub_id': 1,
            },
            row(3, 300),
          ],
          'total': 3,
          'error': null,
        };
      });

      final page = await SmsRepository().queryPage();
      expect(page.items.map((e) => e.id), [3, 1, 2]);
    });

    test('total 缺失时 hasMore 用本页是否写满估算', () async {
      mockQuery((_) {
        return {
          'messages': [row(1, 1), row(2, 2)],
          'error': null,
        };
      });

      final page = await SmsRepository().queryPage(limit: 2);
      expect(page.total, isNull);
      expect(page.hasMore(2, 2), isTrue);
      expect(page.hasMore(2, 3), isFalse);
    });

    test('error=permission 抛 SmsQueryPermissionException', () async {
      mockQuery((_) {
        return {
          'messages': <Map<String, dynamic>>[],
          'error': 'permission',
        };
      });

      expect(
        () => SmsRepository().queryPage(),
        throwsA(isA<SmsQueryPermissionException>()),
      );
    });

    test('error=unknown 抛普通异常', () async {
      mockQuery((_) {
        return {
          'messages': <Map<String, dynamic>>[],
          'error': 'unknown',
        };
      });

      expect(() => SmsRepository().queryAll(), throwsException);
    });
  });
}
