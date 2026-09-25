import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sms/l10n/generated/app_localizations.dart';
import 'package:sms/l10n/generated/app_localizations_en.dart';
import 'package:sms/utils/date_format.dart';
import 'package:sms/widgets/message_item.dart';
import 'package:sms_advanced/sms_advanced.dart';

Widget _host(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

MessageItem _item(SmsMessage message) {
  return MessageItem(
    index: 0,
    item: message,
    animation: const AlwaysStoppedAnimation<double>(1),
    appLocalizations: AppLocalizationsEn(),
    onDelete: (_) {},
    onRemove: (_) {},
    onSameAddress: (_) {},
    onSameSim: (_) {},
    onShowToast: (_) {},
  );
}

void main() {
  group('formatSmsDate', () {
    test('null 返回空串而不是抛异常', () {
      expect(formatSmsDate(null), '');
    });

    test('补零输出 YYYY-MM-DD HH:mm', () {
      expect(formatSmsDate(DateTime(2026, 1, 2, 3, 4)), '2026-01-02 03:04');
    });
  });

  group('buildSmsClipboardText', () {
    test('可空字段写空串，不出现 "null"', () {
      final text = buildSmsClipboardText(body: 'hi');
      expect(text, isNot(contains('null')));
      expect(text, contains('hi'));
    });
  });

  group('MessageItem', () {
    testWidgets('date/sim/body 全为 null 时渲染不崩溃', (WidgetTester tester) async {
      // 回归：旧实现用 item.date.toString().substring(0, 19)，
      // date 为 null 时 "null" 长度不足会抛 RangeError。
      await tester.pumpWidget(_host(_item(SmsMessage('10086', null, id: 1))));

      expect(tester.takeException(), isNull);
      // sim 为 null 时显示占位符，而不是 "SIMnull"。
      expect(find.text('SIM-'), findsOneWidget);
    });

    testWidgets('正常短信渲染号码与正文', (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          _item(
            SmsMessage(
              '10086',
              'balance reminder',
              id: 1,
              sim: 0,
              date: DateTime(2026, 9, 1, 12, 30),
            ),
          ),
        ),
      );

      expect(find.text('balance reminder'), findsOneWidget);
      expect(find.text('SIM0'), findsOneWidget);
      expect(find.text('2026-09-01 12:30'), findsOneWidget);
    });
  });
}
