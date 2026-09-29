import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sms/generated/app_localizations.dart';
import 'package:sms/services/channel.dart';
import 'package:sms/services/locale_store.dart';

import '../helpers/mock_sms_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpHomeHarness();

  group('LocaleStore', () {
    test('save/load 往返：null=跟随系统，zh_TW 保留 country', () async {
      SharedPreferences.setMockInitialValues({});
      final store = LocaleStore();
      expect(await store.load(), isNull);

      await store.save(const Locale('zh', 'TW'));
      expect(await store.load(), const Locale('zh', 'TW'));

      await store.save(const Locale('en'));
      expect(await store.load(), const Locale('en'));

      await store.save(null);
      expect(await store.load(), isNull);
    });
  });

  group('InsertRowError.labelOf', () {
    final zh = lookupAppLocalizations(const Locale('zh'));

    test('按 code 本地化，不透出原生 message', () {
      const e = InsertRowError(
        index: 0,
        code: ChannelCodes.insertErrorFailed,
        message: 'insert returned null',
      );
      expect(e.labelOf(zh), '写入失败');
      expect(e.labelOf(zh), isNot(contains('insert')));
    });

    test('not_default / invalid / unknown', () {
      expect(
        const InsertRowError(
          index: -1,
          code: ChannelCodes.insertErrorNotDefault,
        ).labelOf(zh),
        '非默认短信应用',
      );
      expect(
        const InsertRowError(
          index: 0,
          code: ChannelCodes.insertErrorInvalid,
        ).labelOf(zh),
        '数据格式非法',
      );
      expect(const InsertRowError(index: 0, code: '???').labelOf(zh), '未知错误');
    });
  });

  testWidgets('设置页：语言 / 开源许可 / 问题反馈入口可见', (tester) async {
    await pumpHome(tester);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(find.text('语言'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('开源许可'), 200);
    await tester.pumpAndSettle();
    expect(find.text('开源许可'), findsOneWidget);
    expect(find.text('问题反馈'), findsOneWidget);
    expect(find.text('隐私说明'), findsOneWidget);
  });

  testWidgets('设置页：点隐私弹出对话框', (tester) async {
    await pumpHome(tester);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('隐私说明'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('隐私说明'));
    await tester.pumpAndSettle();

    expect(find.text('隐私说明'), findsWidgets);
    expect(find.textContaining('无网络上传'), findsOneWidget);
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
  });

  testWidgets('设置页：语言弹层含四档并可选英文', (tester) async {
    await pumpHome(tester);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.text('语言'));
    await tester.pumpAndSettle();

    // 当前值「简体中文」显示在设置行，弹层里再有一份 → findsWidgets
    expect(find.text('简体中文'), findsWidgets);
    expect(find.text('繁體中文'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    // 弹层里点「English」后，语言行应同步显示 English
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('English'), findsOneWidget);
  });
}
