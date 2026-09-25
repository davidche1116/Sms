import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sms/services/sms_repository.dart';

/// sms_advanced 的查询通道（JSON 编解码）。
const MethodChannel queryChannel = MethodChannel(
  'plugins.elyudde.com/querySMS',
  JSONMethodCodec(),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('queryByAddress', () {
    test('按全部短信类型查询（收件箱/已发送/草稿）', () async {
      final List<String> calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(queryChannel, (MethodCall call) async {
            calls.add(call.method);
            return <dynamic>[];
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(queryChannel, null),
      );

      await SmsRepository().queryByAddress('10086');

      // 回归：插件 querySms 的 kinds 默认只含 Inbox，必须显式传全类型，
      // 否则"同号码"结果会漏掉已发送与草稿。
      expect(
        calls,
        unorderedEquals(<String>['getInbox', 'getSent', 'getDraft']),
      );
    });
  });
}
