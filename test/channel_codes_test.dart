import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sms/services/sms_repository.dart';

/// 通道协议契约测试：每个已知线字符串 → 正确枚举；未知字符串 → 安全默认。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const appChannel = MethodChannel('com.dc16.sms/smsApp');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(appChannel, null);
  });

  void mockChannel(String method, Object? Function() respond) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(appChannel, (call) async {
          if (call.method != method) return null;
          return respond();
        });
  }

  group('DefaultSmsResult.fromWire（setDefaultSms: had|no|error）', () {
    test('had → alreadyDefault', () {
      expect(
        DefaultSmsResult.fromWire(ChannelCodes.setDefaultHad),
        DefaultSmsResult.alreadyDefault,
      );
      expect(DefaultSmsResult.fromWire('had'), DefaultSmsResult.alreadyDefault);
    });

    test('no → requested', () {
      expect(
        DefaultSmsResult.fromWire(ChannelCodes.setDefaultNo),
        DefaultSmsResult.requested,
      );
      expect(DefaultSmsResult.fromWire('no'), DefaultSmsResult.requested);
    });

    test('error → error', () {
      expect(
        DefaultSmsResult.fromWire(ChannelCodes.error),
        DefaultSmsResult.error,
      );
      expect(DefaultSmsResult.fromWire('error'), DefaultSmsResult.error);
    });

    test('未知字符串 / null → error（安全默认）', () {
      expect(DefaultSmsResult.fromWire('ok'), DefaultSmsResult.error);
      expect(DefaultSmsResult.fromWire(''), DefaultSmsResult.error);
      expect(DefaultSmsResult.fromWire(null), DefaultSmsResult.error);
      expect(DefaultSmsResult.fromWire('HAD'), DefaultSmsResult.error);
    });
  });

  group('RestoreDefaultResult.fromWire（restoreDefaultSms: not_default|settings|error）', () {
    test('not_default → notDefault', () {
      expect(
        RestoreDefaultResult.fromWire(ChannelCodes.restoreNotDefault),
        RestoreDefaultResult.notDefault,
      );
      expect(
        RestoreDefaultResult.fromWire('not_default'),
        RestoreDefaultResult.notDefault,
      );
    });

    test('settings → openedSettings', () {
      expect(
        RestoreDefaultResult.fromWire(ChannelCodes.restoreSettings),
        RestoreDefaultResult.openedSettings,
      );
      expect(
        RestoreDefaultResult.fromWire('settings'),
        RestoreDefaultResult.openedSettings,
      );
    });

    test('error → error', () {
      expect(
        RestoreDefaultResult.fromWire(ChannelCodes.error),
        RestoreDefaultResult.error,
      );
      expect(RestoreDefaultResult.fromWire('error'), RestoreDefaultResult.error);
    });

    test('未知字符串 / null / 历史误记的 ok → error（安全默认）', () {
      expect(RestoreDefaultResult.fromWire('ok'), RestoreDefaultResult.error);
      expect(RestoreDefaultResult.fromWire(''), RestoreDefaultResult.error);
      expect(RestoreDefaultResult.fromWire(null), RestoreDefaultResult.error);
    });
  });

  group('MiuiNotifState.fromWire（miuiNotificationSmsState）', () {
    test('allow → allow', () {
      expect(
        MiuiNotifState.fromWire(ChannelCodes.miuiAllow),
        MiuiNotifState.allow,
      );
      expect(MiuiNotifState.fromWire('allow'), MiuiNotifState.allow);
    });

    test('likely_off → likelyOff', () {
      expect(
        MiuiNotifState.fromWire(ChannelCodes.miuiLikelyOff),
        MiuiNotifState.likelyOff,
      );
      expect(MiuiNotifState.fromWire('likely_off'), MiuiNotifState.likelyOff);
    });

    test('ignore → ignore（历史兼容）', () {
      expect(
        MiuiNotifState.fromWire(ChannelCodes.miuiIgnore),
        MiuiNotifState.ignore,
      );
      expect(MiuiNotifState.fromWire('ignore'), MiuiNotifState.ignore);
    });

    test('deny → deny（历史兼容）', () {
      expect(
        MiuiNotifState.fromWire(ChannelCodes.miuiDeny),
        MiuiNotifState.deny,
      );
      expect(MiuiNotifState.fromWire('deny'), MiuiNotifState.deny);
    });

    test('unknown → unknown', () {
      expect(
        MiuiNotifState.fromWire(ChannelCodes.miuiUnknown),
        MiuiNotifState.unknown,
      );
      expect(MiuiNotifState.fromWire('unknown'), MiuiNotifState.unknown);
    });

    test('未知字符串 / null → unknown（安全默认）', () {
      expect(MiuiNotifState.fromWire('ALLOW'), MiuiNotifState.unknown);
      expect(MiuiNotifState.fromWire('off'), MiuiNotifState.unknown);
      expect(MiuiNotifState.fromWire(''), MiuiNotifState.unknown);
      expect(MiuiNotifState.fromWire(null), MiuiNotifState.unknown);
    });
  });

  group('QueryError.fromWire（querySms error: null|permission|unknown）', () {
    test('null → none', () {
      expect(QueryError.fromWire(null), QueryError.none);
    });

    test('permission → permission', () {
      expect(
        QueryError.fromWire(ChannelCodes.queryErrorPermission),
        QueryError.permission,
      );
      expect(QueryError.fromWire('permission'), QueryError.permission);
    });

    test('unknown → unknown', () {
      expect(
        QueryError.fromWire(ChannelCodes.queryErrorUnknown),
        QueryError.unknown,
      );
      expect(QueryError.fromWire('unknown'), QueryError.unknown);
    });

    test('未知字符串 → unknown（安全默认）', () {
      expect(QueryError.fromWire('Permission'), QueryError.unknown);
      expect(QueryError.fromWire(''), QueryError.unknown);
      expect(QueryError.fromWire(42), QueryError.unknown);
    });
  });

  group('SmsRepository 通道映射（mock 线值 → 类型化返回）', () {
    test('setDefaultSms：had/no/error/未知/null', () async {
      for (final (wire, expected) in [
        ('had', DefaultSmsResult.alreadyDefault),
        ('no', DefaultSmsResult.requested),
        ('error', DefaultSmsResult.error),
        ('ok', DefaultSmsResult.error),
        (null, DefaultSmsResult.error),
      ]) {
        mockChannel('setDefaultSms', () => wire);
        expect(
          await SmsRepository().setDefaultSms(),
          expected,
          reason: 'wire=$wire',
        );
      }
    });

    test('restoreDefaultSms：not_default/settings/error/未知', () async {
      for (final (wire, expected) in [
        ('not_default', RestoreDefaultResult.notDefault),
        ('settings', RestoreDefaultResult.openedSettings),
        ('error', RestoreDefaultResult.error),
        ('ok', RestoreDefaultResult.error),
        (null, RestoreDefaultResult.error),
      ]) {
        mockChannel('restoreDefaultSms', () => wire);
        expect(
          await SmsRepository().restoreDefaultSms(),
          expected,
          reason: 'wire=$wire',
        );
      }
    });

    test('miuiNotificationSmsState：全量已知值 + 未知', () async {
      for (final (wire, expected) in [
        ('allow', MiuiNotifState.allow),
        ('likely_off', MiuiNotifState.likelyOff),
        ('ignore', MiuiNotifState.ignore),
        ('deny', MiuiNotifState.deny),
        ('unknown', MiuiNotifState.unknown),
        ('nope', MiuiNotifState.unknown),
        (null, MiuiNotifState.unknown),
      ]) {
        mockChannel('miuiNotificationSmsState', () => wire);
        expect(
          await SmsRepository().miuiNotificationSmsState(),
          expected,
          reason: 'wire=$wire',
        );
      }
    });

    test('deleteSmsBatch：int → ok；null → failed', () async {
      mockChannel('deleteSmsBatch', () => 3);
      var r = await SmsRepository().deleteSmsBatch([1, 2, 3]);
      expect(r.ok, isTrue);
      expect(r.deleted, 3);
      expect(r.failure, isNull);

      mockChannel('deleteSmsBatch', () => null);
      r = await SmsRepository().deleteSmsBatch([1]);
      expect(r.ok, isFalse);
      expect(r.deleted, 0);
      expect(r.failure, BatchFailure.notDefaultOrError);
    });

    test('insertSmsBatch：int → ok；null → failed；空列表 → ok(0)', () async {
      mockChannel('insertSmsBatch', () => 2);
      var r = await SmsRepository().insertSmsBatch([
        {'address': '1', 'body': 'a'},
        {'address': '2', 'body': 'b'},
      ]);
      expect(r.ok, isTrue);
      expect(r.inserted, 2);
      expect(r.failure, isNull);

      mockChannel('insertSmsBatch', () => null);
      r = await SmsRepository().insertSmsBatch([
        {'address': '1', 'body': 'a'},
      ]);
      expect(r.ok, isFalse);
      expect(r.inserted, 0);
      expect(r.failure, BatchFailure.notDefaultOrError);

      final empty = await SmsRepository().insertSmsBatch(const []);
      expect(empty.ok, isTrue);
      expect(empty.inserted, 0);
    });

    test('querySms：error 字段映射（permission 抛权限异常，未知抛普通异常）', () async {
      mockChannel('querySms', () {
        return {
          ChannelCodes.keyMessages: <Map<String, dynamic>>[],
          ChannelCodes.keyError: ChannelCodes.queryErrorPermission,
        };
      });
      await expectLater(
        SmsRepository().queryPage(),
        throwsA(isA<SmsQueryPermissionException>()),
      );

      mockChannel('querySms', () {
        return {
          ChannelCodes.keyMessages: <Map<String, dynamic>>[],
          ChannelCodes.keyError: 'weird',
        };
      });
      await expectLater(SmsRepository().queryPage(), throwsException);

      mockChannel('querySms', () {
        return {
          ChannelCodes.keyMessages: <Map<String, dynamic>>[],
          ChannelCodes.keyError: null,
          ChannelCodes.keyTotal: 0,
        };
      });
      final page = await SmsRepository().queryPage();
      expect(page.items, isEmpty);
      expect(page.total, 0);
    });

    test('insertTestSms：{ok,ids} 键契约', () async {
      mockChannel('insertTestSms', () {
        return {ChannelCodes.keyOk: true, ChannelCodes.keyIds: [7, 8]};
      });
      expect(await SmsRepository().insertTestSms(), [7, 8]);

      mockChannel('insertTestSms', () {
        return {ChannelCodes.keyOk: false, ChannelCodes.keyIds: <int>[]};
      });
      expect(await SmsRepository().insertTestSms(), isNull);
    });
  });

  group('协议常量双端一致性（与 Kotlin ChannelCodes 同值）', () {
    test('字面量快照，防止误改线协议', () {
      expect(ChannelCodes.setDefaultHad, 'had');
      expect(ChannelCodes.setDefaultNo, 'no');
      expect(ChannelCodes.error, 'error');
      expect(ChannelCodes.restoreNotDefault, 'not_default');
      expect(ChannelCodes.restoreSettings, 'settings');
      expect(ChannelCodes.miuiAllow, 'allow');
      expect(ChannelCodes.miuiLikelyOff, 'likely_off');
      expect(ChannelCodes.miuiIgnore, 'ignore');
      expect(ChannelCodes.miuiDeny, 'deny');
      expect(ChannelCodes.miuiUnknown, 'unknown');
      expect(ChannelCodes.queryErrorPermission, 'permission');
      expect(ChannelCodes.queryErrorUnknown, 'unknown');
      expect(ChannelCodes.keyOk, 'ok');
      expect(ChannelCodes.keyIds, 'ids');
      expect(ChannelCodes.keyDeleted, 'deleted');
      expect(ChannelCodes.keyMessages, 'messages');
      expect(ChannelCodes.keyTotal, 'total');
      expect(ChannelCodes.keyError, 'error');
    });
  });
}
