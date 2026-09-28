import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sms/generated/app_localizations.dart';

import '../helpers/mock_sms_channel.dart';

/// i18n 冒烟：中文/英文 locale 下关键主路径文案。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpHomeHarness();

  testWidgets('zh locale：首页标题/计数为中文', (tester) async {
    await pumpHome(tester);

    expect(find.text('短信'), findsOneWidget);
    expect(find.textContaining('条'), findsWidgets);
    final l10n = AppLocalizations.of(tester.element(find.text('短信')));
    expect(l10n.homeTitle, '短信');
  });

  testWidgets('en locale：首页标题/计数为英文', (tester) async {
    await pumpHome(tester, locale: const Locale('en'));

    expect(find.text('Messages'), findsOneWidget);
    expect(find.textContaining('messages'), findsWidgets);
    expect(find.text('短信'), findsNothing);
    final l10n = AppLocalizations.of(tester.element(find.text('Messages')));
    expect(l10n.homeTitle, 'Messages');
    expect(l10n.confirmDelete, 'Delete');
  });

  testWidgets('en locale：权限空态为英文', (tester) async {
    mockHomeChannel(
      queryResult: {
        'messages': <Map<String, dynamic>>[],
        'error': 'permission',
      },
    );
    await pumpHome(tester, locale: const Locale('en'));

    expect(find.text('SMS permission required'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Request SMS permission'),
      findsOneWidget,
    );
  });

  testWidgets('zh locale：删除确认为中文', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.textContaining('流量提醒'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(find.text('删除短信？'), findsOneWidget);
    expect(find.textContaining('将删除'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
  });

  testWidgets('en locale：删除确认为英文', (tester) async {
    await pumpHome(tester, locale: const Locale('en'));

    await tester.tap(find.textContaining('流量提醒'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Delete messages?'), findsOneWidget);
    expect(find.textContaining('cannot be undone'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('zh_TW locale：首页标题/计数为繁体', (tester) async {
    await pumpHome(tester, locale: const Locale('zh', 'TW'));

    expect(find.text('簡訊'), findsOneWidget);
    final l10n = AppLocalizations.of(tester.element(find.text('簡訊')));
    expect(l10n.homeTitle, '簡訊');
    expect(l10n.confirmDelete, '確認刪除');
    expect(l10n.appTitle, '簡訊清理');
  });
}
