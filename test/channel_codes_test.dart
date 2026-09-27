import 'package:flutter_test/flutter_test.dart';
import 'package:sms/services/sms_repository.dart';

import 'helpers/app_channel.dart';

/// 通道协议契约测试：每个已知线字符串 → 正确枚举；未知字符串 → 安全默认。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(clearAppChannelHandler);

  void mockChannel(String method, Object? Function() respond) {
    setAppChannelHandler((call) async {
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

    test('insertSmsBatch：Map 新契约解析 + 旧 int/null 兼容 + 空列表', () async {
      // 新契约：全成
      mockChannel('insertSmsBatch', () {
        return {
          ChannelCodes.keyOk: true,
          ChannelCodes.keyInserted: 2,
          ChannelCodes.keyFailed: 0,
          ChannelCodes.keyErrors: <Map<String, Object?>>[],
        };
      });
      var r = await SmsRepository().insertSmsBatch([
        {'address': '1', 'body': 'a'},
        {'address': '2', 'body': 'b'},
      ]);
      expect(r.ok, isTrue);
      expect(r.inserted, 2);
      expect(r.failed, 0);
      expect(r.errors, isEmpty);
      expect(r.failure, isNull);

      // 新契约：部分成功 + 逐行明细
      mockChannel('insertSmsBatch', () {
        return {
          ChannelCodes.keyOk: true,
          ChannelCodes.keyInserted: 1,
          ChannelCodes.keyFailed: 2,
          ChannelCodes.keyErrors: [
            {
              ChannelCodes.keyIndex: 1,
              ChannelCodes.keyCode: ChannelCodes.insertErrorFailed,
              ChannelCodes.keyMessage: 'insert returned null',
            },
            {
              ChannelCodes.keyIndex: 2,
              ChannelCodes.keyCode: ChannelCodes.insertErrorUnknown,
              ChannelCodes.keyMessage: 'batch failed',
            },
          ],
        };
      });
      r = await SmsRepository().insertSmsBatch([
        {'address': '1', 'body': 'a'},
        {'address': '2', 'body': 'b'},
        {'address': '3', 'body': 'c'},
      ]);
      expect(r.ok, isTrue);
      expect(r.inserted, 1);
      expect(r.failed, 2);
      expect(r.errors, hasLength(2));
      expect(r.errors[0].index, 1);
      expect(r.errors[0].code, ChannelCodes.insertErrorFailed);
      expect(r.errors[0].message, 'insert returned null');
      expect(r.errors[1].index, 2);
      expect(r.errors[1].code, ChannelCodes.insertErrorUnknown);
      expect(r.errors[1].message, 'batch failed');

      // 新契约：非默认整批失败
      mockChannel('insertSmsBatch', () {
        return {
          ChannelCodes.keyOk: false,
          ChannelCodes.keyInserted: 0,
          ChannelCodes.keyFailed: 2,
          ChannelCodes.keyErrors: [
            {
              ChannelCodes.keyIndex: -1,
              ChannelCodes.keyCode: ChannelCodes.insertErrorNotDefault,
              ChannelCodes.keyMessage: 'not default sms app',
            },
          ],
        };
      });
      r = await SmsRepository().insertSmsBatch([
        {'address': '1', 'body': 'a'},
        {'address': '2', 'body': 'b'},
      ]);
      expect(r.ok, isFalse);
      expect(r.inserted, 0);
      expect(r.failed, 2);
      expect(r.errors.single.index, -1);
      expect(r.errors.single.code, ChannelCodes.insertErrorNotDefault);
      expect(r.failure, BatchFailure.notDefault);

      // 新契约：ok=false 且非 not_default → native
      mockChannel('insertSmsBatch', () {
        return {
          ChannelCodes.keyOk: false,
          ChannelCodes.keyInserted: 0,
          ChannelCodes.keyFailed: 1,
          ChannelCodes.keyErrors: [
            {
              ChannelCodes.keyIndex: -1,
              ChannelCodes.keyCode: ChannelCodes.insertErrorUnknown,
              ChannelCodes.keyMessage: 'boom',
            },
          ],
        };
      });
      r = await SmsRepository().insertSmsBatch([
        {'address': '1', 'body': 'a'},
      ]);
      expect(r.ok, isFalse);
      expect(r.failure, BatchFailure.native);

      // 旧契约：int → 全成
      mockChannel('insertSmsBatch', () => 2);
      r = await SmsRepository().insertSmsBatch([
        {'address': '1', 'body': 'a'},
        {'address': '2', 'body': 'b'},
      ]);
      expect(r.ok, isTrue);
      expect(r.inserted, 2);
      expect(r.failed, 0);
      expect(r.failure, isNull);

      // 旧契约：null → failed
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

    test('insertSmsBatch：多分片下 errors[].index 重映射为全局下标', () async {
      // 250 行 → 2 个通道分片（200+50）；第二片 index=1 应映射为 201。
      final rows = [
        for (var i = 0; i < 250; i++) {'address': '$i', 'body': 'b$i'},
      ];
      var calls = 0;
      setAppChannelHandler((call) async {
            if (call.method != 'insertSmsBatch') return null;
            calls++;
            final n = (call.arguments as List).length;
            if (calls == 1) {
              return {
                ChannelCodes.keyOk: true,
                ChannelCodes.keyInserted: n - 1,
                ChannelCodes.keyFailed: 1,
                ChannelCodes.keyErrors: [
                  {
                    ChannelCodes.keyIndex: 5,
                    ChannelCodes.keyCode: ChannelCodes.insertErrorFailed,
                    ChannelCodes.keyMessage: 'row 5',
                  },
                ],
              };
            }
            return {
              ChannelCodes.keyOk: true,
              ChannelCodes.keyInserted: n - 1,
              ChannelCodes.keyFailed: 1,
              ChannelCodes.keyErrors: [
                {
                  ChannelCodes.keyIndex: 1,
                  ChannelCodes.keyCode: ChannelCodes.insertErrorFailed,
                  ChannelCodes.keyMessage: 'row 201',
                },
              ],
            };
          });

      final r = await SmsRepository().insertSmsBatch(rows);
      expect(calls, 2);
      expect(r.ok, isTrue);
      expect(r.inserted, 248);
      expect(r.failed, 2);
      expect(r.errors.map((e) => e.index), [5, 201]);
      expect(r.errors[1].message, 'row 201');
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
      expect(ChannelCodes.keyInserted, 'inserted');
      expect(ChannelCodes.keyFailed, 'failed');
      expect(ChannelCodes.keyErrors, 'errors');
      expect(ChannelCodes.keyIndex, 'index');
      expect(ChannelCodes.keyCode, 'code');
      expect(ChannelCodes.keyMessage, 'message');
      expect(ChannelCodes.insertErrorNotDefault, 'not_default');
      expect(ChannelCodes.insertErrorFailed, 'failed');
      expect(ChannelCodes.insertErrorUnknown, 'unknown');
    });
  });
}
