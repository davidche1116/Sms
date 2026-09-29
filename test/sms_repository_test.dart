import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sms/services/sms_repository.dart';

import 'helpers/app_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(clearAppChannelHandler);

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
    setAppChannelHandler((call) async {
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

    test('按 date 降序映射（Kotlin 已排序，Dart 透传）', () async {
      mockQuery((_) {
        // Kotlin 已按 date 降序返回（date 缺失视为最早）
        return {
          'messages': [
            row(3, 300),
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
        return {'messages': <Map<String, dynamic>>[], 'error': 'permission'};
      });

      expect(
        () => SmsRepository().queryPage(),
        throwsA(isA<SmsQueryPermissionException>()),
      );
    });

    test('error=unknown 抛普通异常', () async {
      mockQuery((_) {
        return {'messages': <Map<String, dynamic>>[], 'error': 'unknown'};
      });

      expect(() => SmsRepository().queryAll(), throwsException);
    });
  });

  group('系统申请防悬挂（Future.timeout + 可注入超时）', () {
    /// 让指定 method 永不回包（模拟系统弹窗久置 / 进程被杀前的悬挂）。
    void mockHang(String method, {Object? Function(String other)? others}) {
      setAppChannelHandler((call) async {
        if (call.method == method) {
          return Completer<Object?>().future; // 永不完成
        }
        return others?.call(call.method);
      });
    }

    void mockThrow(
      String method,
      Object error, {
      Object? Function(String other)? others,
    }) {
      setAppChannelHandler((call) async {
        if (call.method == method) throw error;
        return others?.call(call.method);
      });
    }

    test('requestReadSms：通道挂起 → 短超时后完成，回查仍无权限 → timeout', () async {
      mockHang(
        'requestReadSms',
        others: (m) => m == 'hasReadSmsPermission' ? false : null,
      );
      final repo = SmsRepository(
        systemResponseTimeout: const Duration(milliseconds: 40),
      );
      final sw = Stopwatch()..start();
      final r = await repo.requestReadSms();
      sw.stop();
      expect(r, RequestReadSmsResult.timeout);
      // 必须在超时附近完成，而不是永久 pending
      expect(sw.elapsedMilliseconds, lessThan(2000));
    });

    test('requestReadSms：超时但回查已有权限 → granted', () async {
      mockHang(
        'requestReadSms',
        others: (m) => m == 'hasReadSmsPermission' ? true : null,
      );
      final repo = SmsRepository(
        systemResponseTimeout: const Duration(milliseconds: 40),
      );
      expect(await repo.requestReadSms(), RequestReadSmsResult.granted);
    });

    test('requestReadSms：原生 lifecycle 取消 → timeout 语义', () async {
      mockThrow(
        'requestReadSms',
        PlatformException(code: ChannelCodes.errorLifecycle),
        others: (m) => m == 'hasReadSmsPermission' ? false : null,
      );
      final repo = SmsRepository(
        systemResponseTimeout: const Duration(milliseconds: 40),
      );
      expect(await repo.requestReadSms(), RequestReadSmsResult.timeout);
    });

    test('requestReadSms：用户拒绝（回 false）→ denied，不误报 timeout', () async {
      setAppChannelHandler((call) async {
        if (call.method == 'requestReadSms') return false;
        if (call.method == 'hasReadSmsPermission') return false;
        return null;
      });
      expect(
        await SmsRepository().requestReadSms(),
        RequestReadSmsResult.denied,
      );
    });

    test('setDefaultSms：通道挂起 → 短超时后完成 → timeout', () async {
      mockHang(
        'setDefaultSms',
        others: (m) => m == 'isDefaultSms' ? false : null,
      );
      final repo = SmsRepository(
        systemResponseTimeout: const Duration(milliseconds: 40),
      );
      final sw = Stopwatch()..start();
      final r = await repo.setDefaultSms();
      sw.stop();
      expect(r, DefaultSmsResult.timeout);
      expect(sw.elapsedMilliseconds, lessThan(2000));
    });

    test('setDefaultSms：超时但回查已是默认 → alreadyDefault', () async {
      mockHang(
        'setDefaultSms',
        others: (m) => m == 'isDefaultSms' ? true : null,
      );
      final repo = SmsRepository(
        systemResponseTimeout: const Duration(milliseconds: 40),
      );
      expect(await repo.setDefaultSms(), DefaultSmsResult.alreadyDefault);
    });

    test('setDefaultSms：原生 lifecycle 取消 → timeout 语义', () async {
      mockThrow(
        'setDefaultSms',
        PlatformException(code: ChannelCodes.errorLifecycle),
        others: (m) => m == 'isDefaultSms' ? false : null,
      );
      final repo = SmsRepository(
        systemResponseTimeout: const Duration(milliseconds: 40),
      );
      expect(await repo.setDefaultSms(), DefaultSmsResult.timeout);
    });

    test('setDefaultSms：正常回包不受超时影响', () async {
      setAppChannelHandler((call) async {
        if (call.method == 'setDefaultSms') return 'had';
        return null;
      });
      // 极短超时也应在回包后立刻完成，不误判 timeout
      final repo = SmsRepository(
        systemResponseTimeout: const Duration(seconds: 5),
      );
      expect(await repo.setDefaultSms(), DefaultSmsResult.alreadyDefault);
    });
  });
}
