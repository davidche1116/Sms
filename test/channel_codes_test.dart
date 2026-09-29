import 'package:flutter_test/flutter_test.dart';
import 'package:sms/models/sms_item.dart';
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

  group('parseDefaultSmsResult（setDefaultSms: had|no|error）', () {
    test('had → alreadyDefault', () {
      expect(
        parseDefaultSmsResult(ChannelCodes.setDefaultHad),
        DefaultSmsResult.alreadyDefault,
      );
      expect(parseDefaultSmsResult('had'), DefaultSmsResult.alreadyDefault);
    });

    test('no → requested', () {
      expect(
        parseDefaultSmsResult(ChannelCodes.setDefaultNo),
        DefaultSmsResult.requested,
      );
      expect(parseDefaultSmsResult('no'), DefaultSmsResult.requested);
    });

    test('error → error', () {
      expect(parseDefaultSmsResult(ChannelCodes.error), DefaultSmsResult.error);
      expect(parseDefaultSmsResult('error'), DefaultSmsResult.error);
    });

    test('未知字符串 / null → error（安全默认）', () {
      expect(parseDefaultSmsResult('ok'), DefaultSmsResult.error);
      expect(parseDefaultSmsResult(''), DefaultSmsResult.error);
      expect(parseDefaultSmsResult(null), DefaultSmsResult.error);
      expect(parseDefaultSmsResult('HAD'), DefaultSmsResult.error);
    });
  });

  group(
    'parseRestoreDefaultResult（restoreDefaultSms: not_default|settings|error）',
    () {
      test('not_default → notDefault', () {
        expect(
          parseRestoreDefaultResult(ChannelCodes.restoreNotDefault),
          RestoreDefaultResult.notDefault,
        );
        expect(
          parseRestoreDefaultResult('not_default'),
          RestoreDefaultResult.notDefault,
        );
      });

      test('settings → openedSettings', () {
        expect(
          parseRestoreDefaultResult(ChannelCodes.restoreSettings),
          RestoreDefaultResult.openedSettings,
        );
        expect(
          parseRestoreDefaultResult('settings'),
          RestoreDefaultResult.openedSettings,
        );
      });

      test('error → error', () {
        expect(
          parseRestoreDefaultResult(ChannelCodes.error),
          RestoreDefaultResult.error,
        );
        expect(parseRestoreDefaultResult('error'), RestoreDefaultResult.error);
      });

      test('未知字符串 / null / 历史误记的 ok → error（安全默认）', () {
        expect(parseRestoreDefaultResult('ok'), RestoreDefaultResult.error);
        expect(parseRestoreDefaultResult(''), RestoreDefaultResult.error);
        expect(parseRestoreDefaultResult(null), RestoreDefaultResult.error);
      });
    },
  );

  group('parseMiuiNotifState（miuiNotificationSmsState）', () {
    test('allow → allow', () {
      expect(parseMiuiNotifState(ChannelCodes.miuiAllow), MiuiNotifState.allow);
      expect(parseMiuiNotifState('allow'), MiuiNotifState.allow);
    });

    test('likely_off → likelyOff', () {
      expect(
        parseMiuiNotifState(ChannelCodes.miuiLikelyOff),
        MiuiNotifState.likelyOff,
      );
      expect(parseMiuiNotifState('likely_off'), MiuiNotifState.likelyOff);
    });

    test('ignore → ignore（历史兼容）', () {
      expect(
        parseMiuiNotifState(ChannelCodes.miuiIgnore),
        MiuiNotifState.ignore,
      );
      expect(parseMiuiNotifState('ignore'), MiuiNotifState.ignore);
    });

    test('deny → deny（历史兼容）', () {
      expect(parseMiuiNotifState(ChannelCodes.miuiDeny), MiuiNotifState.deny);
      expect(parseMiuiNotifState('deny'), MiuiNotifState.deny);
    });

    test('unknown → unknown', () {
      expect(
        parseMiuiNotifState(ChannelCodes.miuiUnknown),
        MiuiNotifState.unknown,
      );
      expect(parseMiuiNotifState('unknown'), MiuiNotifState.unknown);
    });

    test('未知字符串 / null → unknown（安全默认）', () {
      expect(parseMiuiNotifState('ALLOW'), MiuiNotifState.unknown);
      expect(parseMiuiNotifState('off'), MiuiNotifState.unknown);
      expect(parseMiuiNotifState(''), MiuiNotifState.unknown);
      expect(parseMiuiNotifState(null), MiuiNotifState.unknown);
    });
  });

  group('parseQueryError（querySms error: null|permission|unknown）', () {
    test('null → none', () {
      expect(parseQueryError(null), QueryError.none);
    });

    test('permission → permission', () {
      expect(
        parseQueryError(ChannelCodes.queryErrorPermission),
        QueryError.permission,
      );
      expect(parseQueryError('permission'), QueryError.permission);
    });

    test('unknown → unknown', () {
      expect(
        parseQueryError(ChannelCodes.queryErrorUnknown),
        QueryError.unknown,
      );
      expect(parseQueryError('unknown'), QueryError.unknown);
    });

    test('未知字符串 → unknown（安全默认）', () {
      expect(parseQueryError('Permission'), QueryError.unknown);
      expect(parseQueryError(''), QueryError.unknown);
      expect(parseQueryError(42), QueryError.unknown);
    });
  });

  group('parseQueryWarning（querySms warnings[] 项）', () {
    test('Map{code,message} → 明细', () {
      const w = QueryWarning(
        code: ChannelCodes.warnSmsUriSecurity,
        message: 'sms query restricted',
      );
      expect(
        parseQueryWarning({
          ChannelCodes.keyCode: ChannelCodes.warnSmsUriSecurity,
          ChannelCodes.keyMessage: 'sms query restricted',
        }),
        w,
      );
    });

    test('缺 message 时为 null', () {
      final w = parseQueryWarning({ChannelCodes.keyCode: 'mms_part_failed'});
      expect(w.code, ChannelCodes.warnMmsPartFailed);
      expect(w.message, isNull);
    });

    test('形态异常 / 非 Map → warnUnknown（安全默认，不抛）', () {
      expect(parseQueryWarning(null).code, ChannelCodes.warnUnknown);
      expect(
        parseQueryWarning('mms_part_failed').code,
        ChannelCodes.warnUnknown,
      );
      expect(parseQueryWarning(42).code, ChannelCodes.warnUnknown);
      expect(
        parseQueryWarning(<Object?, Object?>{}).code,
        ChannelCodes.warnUnknown,
      );
    });

    test('未知 code 原样保留，供日志诊断', () {
      final w = parseQueryWarning({ChannelCodes.keyCode: 'weird_code'});
      expect(w.code, 'weird_code');
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

    test('deleteSmsBatch：Map 新契约解析 + 旧 int/null 兼容', () async {
      // 新契约：全成
      mockChannel('deleteSmsBatch', () {
        return {
          ChannelCodes.keyOk: true,
          ChannelCodes.keyDeleted: 3,
          ChannelCodes.keyFailed: 0,
          ChannelCodes.keyError: null,
          ChannelCodes.keyErrors: <Map<String, Object?>>[],
        };
      });
      var r = await SmsRepository().deleteSmsBatch([
        const SmsItem(id: 1, body: '', address: ''),
        const SmsItem(id: 2, body: '', address: ''),
        const SmsItem(id: 3, body: '', address: ''),
      ]);
      expect(r.ok, isTrue);
      expect(r.deleted, 3);
      expect(r.failed, 0);
      expect(r.errors, isEmpty);
      expect(r.failure, isNull);

      // 新契约：部分成功 + 逐条明细（index 对齐入参）
      mockChannel('deleteSmsBatch', () {
        return {
          ChannelCodes.keyOk: true,
          ChannelCodes.keyDeleted: 1,
          ChannelCodes.keyFailed: 2,
          ChannelCodes.keyError: null,
          ChannelCodes.keyErrors: [
            {
              ChannelCodes.keyIndex: 1,
              ChannelCodes.keyCode: ChannelCodes.deleteErrorFailed,
              ChannelCodes.keyMessage: 'delete failed',
            },
            {
              ChannelCodes.keyIndex: 2,
              ChannelCodes.keyCode: ChannelCodes.deleteErrorFailed,
              ChannelCodes.keyMessage: 'boom',
            },
          ],
        };
      });
      r = await SmsRepository().deleteSmsBatch([
        const SmsItem(id: 1, body: '', address: ''),
        const SmsItem(id: 2, body: '', address: ''),
        const SmsItem(id: 3, body: '', address: ''),
      ]);
      expect(r.ok, isTrue);
      expect(r.deleted, 1);
      expect(r.failed, 2);
      expect(r.errors, hasLength(2));
      expect(r.errors[0].index, 1);
      expect(r.errors[0].code, ChannelCodes.deleteErrorFailed);
      expect(r.errors[0].message, 'delete failed');
      expect(r.errors[1].index, 2);
      expect(r.failure, isNull);

      // 新契约：非默认整批失败
      mockChannel('deleteSmsBatch', () {
        return {
          ChannelCodes.keyOk: false,
          ChannelCodes.keyDeleted: 0,
          ChannelCodes.keyFailed: 2,
          ChannelCodes.keyError: ChannelCodes.deleteErrorNotDefault,
          ChannelCodes.keyErrors: [
            {
              ChannelCodes.keyIndex: -1,
              ChannelCodes.keyCode: ChannelCodes.deleteErrorNotDefault,
              ChannelCodes.keyMessage: 'not default sms app',
            },
          ],
        };
      });
      r = await SmsRepository().deleteSmsBatch([
        const SmsItem(id: 1, body: '', address: ''),
        const SmsItem(id: 2, body: '', address: ''),
      ]);
      expect(r.ok, isFalse);
      expect(r.deleted, 0);
      expect(r.failed, 2);
      expect(r.errors.single.index, -1);
      expect(r.errors.single.code, ChannelCodes.deleteErrorNotDefault);
      expect(r.failure, BatchFailure.notDefault);

      // 新契约：ok=false 且 error=failed → native
      mockChannel('deleteSmsBatch', () {
        return {
          ChannelCodes.keyOk: false,
          ChannelCodes.keyDeleted: 0,
          ChannelCodes.keyFailed: 1,
          ChannelCodes.keyError: ChannelCodes.deleteErrorFailed,
          ChannelCodes.keyErrors: [
            {
              ChannelCodes.keyIndex: 0,
              ChannelCodes.keyCode: ChannelCodes.deleteErrorFailed,
              ChannelCodes.keyMessage: 'boom',
            },
          ],
        };
      });
      r = await SmsRepository().deleteSmsBatch([
        const SmsItem(id: 1, body: '', address: ''),
      ]);
      expect(r.ok, isFalse);
      expect(r.failure, BatchFailure.native);

      // 新契约：ok=false 且 error=unknown → notDefaultOrError（不可区分）
      mockChannel('deleteSmsBatch', () {
        return {
          ChannelCodes.keyOk: false,
          ChannelCodes.keyDeleted: 0,
          ChannelCodes.keyFailed: 1,
          ChannelCodes.keyError: ChannelCodes.deleteErrorUnknown,
          ChannelCodes.keyErrors: <Map<String, Object?>>[],
        };
      });
      r = await SmsRepository().deleteSmsBatch([
        const SmsItem(id: 1, body: '', address: ''),
      ]);
      expect(r.ok, isFalse);
      expect(r.failure, BatchFailure.notDefaultOrError);

      // 旧契约：int → 全成
      mockChannel('deleteSmsBatch', () => 2);
      r = await SmsRepository().deleteSmsBatch([
        const SmsItem(id: 1, body: '', address: ''),
        const SmsItem(id: 2, body: '', address: ''),
      ]);
      expect(r.ok, isTrue);
      expect(r.deleted, 2);
      expect(r.failed, 0);
      expect(r.failure, isNull);

      // 旧契约：null → failed（不可区分）
      mockChannel('deleteSmsBatch', () => null);
      r = await SmsRepository().deleteSmsBatch([
        const SmsItem(id: 1, body: '', address: ''),
      ]);
      expect(r.ok, isFalse);
      expect(r.deleted, 0);
      expect(r.failure, BatchFailure.notDefaultOrError);
    });

    test('deleteSmsBatch：混合 is_mms 线协议载荷', () async {
      Object? captured;
      setAppChannelHandler((call) async {
        if (call.method != 'deleteSmsBatch') return null;
        captured = call.arguments;
        return 2;
      });
      await SmsRepository().deleteSmsBatch([
        const SmsItem(id: 1, body: '', address: '', isMms: false),
        const SmsItem(id: 2, body: '', address: '', isMms: true),
        const SmsItem(body: '', address: ''), // 无 id 被丢弃
      ]);
      expect(captured, [
        {'id': 1, 'is_mms': 0},
        {'id': 2, 'is_mms': 1},
      ]);
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

    test('querySms：partial/warnings 映射（有数据 + 部分失败）', () async {
      mockChannel('querySms', () {
        return {
          ChannelCodes.keyMessages: [
            {
              '_id': 1,
              'address': '10086',
              'body': 'hi',
              'date': 1000,
              'read': 1,
              'type': 1,
              'sub_id': 1,
            },
          ],
          ChannelCodes.keyTotal: 5,
          ChannelCodes.keyError: null,
          ChannelCodes.keyPartial: true,
          ChannelCodes.keyWarnings: [
            {
              ChannelCodes.keyCode: ChannelCodes.warnMmsPartFailed,
              ChannelCodes.keyMessage: 'mms body lookup failed',
            },
            {
              ChannelCodes.keyCode: ChannelCodes.warnSmsUriSecurity,
              ChannelCodes.keyMessage: 'sms query restricted',
            },
          ],
        };
      });
      final page = await SmsRepository().queryPage();
      expect(page.partial, isTrue);
      expect(page.warnings.map((w) => w.code), [
        ChannelCodes.warnMmsPartFailed,
        ChannelCodes.warnSmsUriSecurity,
      ]);
      expect(page.warnings.first.message, 'mms body lookup failed');
      expect(page.items.single.id, 1);
    });

    test('querySms：全成功 → partial=false、warnings 空；缺字段时旧线协议兼容', () async {
      mockChannel('querySms', () {
        return {
          ChannelCodes.keyMessages: <Map<String, dynamic>>[],
          ChannelCodes.keyTotal: 0,
          ChannelCodes.keyError: null,
          // 旧原生可能不带 partial/warnings
        };
      });
      final page = await SmsRepository().queryPage();
      expect(page.partial, isFalse);
      expect(page.warnings, isEmpty);
    });

    test('querySms：error 非空时忽略 partial（互斥语义）', () async {
      // permission 异常在 error 分支抛出，不会走到 partial 解析
      mockChannel('querySms', () {
        return {
          ChannelCodes.keyMessages: <Map<String, dynamic>>[],
          ChannelCodes.keyError: ChannelCodes.queryErrorPermission,
          ChannelCodes.keyPartial: true,
          ChannelCodes.keyWarnings: [
            {ChannelCodes.keyCode: ChannelCodes.warnSmsUriSecurity},
          ],
        };
      });
      await expectLater(
        SmsRepository().queryPage(),
        throwsA(isA<SmsQueryPermissionException>()),
      );
    });

    test('insertTestSms：{ok,ids} 键契约', () async {
      mockChannel('insertTestSms', () {
        return {
          ChannelCodes.keyOk: true,
          ChannelCodes.keyIds: [7, 8],
        };
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
      expect(ChannelCodes.keyPartial, 'partial');
      expect(ChannelCodes.keyWarnings, 'warnings');
      expect(ChannelCodes.warnSmsUriSecurity, 'sms_uri_security');
      expect(ChannelCodes.warnSmsUriFailed, 'sms_uri_failed');
      expect(ChannelCodes.warnMmsUriSecurity, 'mms_uri_security');
      expect(ChannelCodes.warnMmsUriFailed, 'mms_uri_failed');
      expect(ChannelCodes.warnMmsAddrFailed, 'mms_addr_failed');
      expect(ChannelCodes.warnMmsPartFailed, 'mms_part_failed');
      expect(ChannelCodes.warnUnknown, 'unknown');
      expect(ChannelCodes.keyInserted, 'inserted');
      expect(ChannelCodes.keyFailed, 'failed');
      expect(ChannelCodes.keyErrors, 'errors');
      expect(ChannelCodes.keyIndex, 'index');
      expect(ChannelCodes.keyCode, 'code');
      expect(ChannelCodes.keyMessage, 'message');
      expect(ChannelCodes.insertErrorNotDefault, 'not_default');
      expect(ChannelCodes.insertErrorFailed, 'failed');
      expect(ChannelCodes.insertErrorInvalid, 'invalid');
      expect(ChannelCodes.insertErrorUnknown, 'unknown');
      expect(ChannelCodes.deleteErrorNotDefault, 'not_default');
      expect(ChannelCodes.deleteErrorFailed, 'failed');
      expect(ChannelCodes.deleteErrorUnknown, 'unknown');
    });
  });
}
