import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:sms/features/filter/keyword_presets.dart';

/// 类别预设词表：三语覆盖、无 LIKE 通配符。
void main() {
  final locales = <Locale?>[
    const Locale('zh'),
    const Locale('zh', 'TW'),
    const Locale('en'),
    null,
  ];

  test('每个预设在每种语言下都有非空词表', () {
    for (final p in SmsKeywordPreset.values) {
      for (final loc in locales) {
        expect(
          presetKeywords(p, loc),
          isNotEmpty,
          reason: '${p.name} / $loc 词表为空',
        );
      }
    }
  });

  test('简体 / 繁体 / 英文取到不同词表', () {
    for (final p in SmsKeywordPreset.values) {
      final zh = presetKeywords(p, const Locale('zh'));
      final hant = presetKeywords(p, const Locale('zh', 'TW'));
      final en = presetKeywords(p, const Locale('en'));
      expect(zh, isNot(hant), reason: '${p.name} 简繁未区分');
      expect(zh, isNot(en), reason: '${p.name} 中英未区分');
    }
  });

  test('繁体判定覆盖 scriptCode=Hant 与 countryCode=TW/HK/MO', () {
    final hant = presetKeywords(
      SmsKeywordPreset.carrier,
      const Locale('zh', 'TW'),
    );
    expect(
      presetKeywords(
        SmsKeywordPreset.carrier,
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      ),
      hant,
    );
    expect(
      presetKeywords(SmsKeywordPreset.carrier, const Locale('zh', 'HK')),
      hant,
    );
    expect(
      presetKeywords(SmsKeywordPreset.carrier, const Locale('zh', 'MO')),
      hant,
    );
    // 简体不带 Hant / TW 时走简体表
    expect(
      presetKeywords(SmsKeywordPreset.carrier, const Locale('zh', 'CN')),
      isNot(hant),
    );
  });

  test('关键词不含 LIKE 通配符（原生侧未做 ESCAPE 转义）', () {
    for (final p in SmsKeywordPreset.values) {
      for (final loc in locales) {
        for (final k in presetKeywords(p, loc)) {
          expect(
            k.contains('%') || k.contains('_'),
            isFalse,
            reason: '${p.name} 的关键词 "$k" 含 LIKE 通配符',
          );
        }
      }
    }
  });

  test('避开泛词：银行类不含「支付」，电商类不含裸「订单」', () {
    final bank = presetKeywords(SmsKeywordPreset.bank, const Locale('zh'));
    expect(bank, isNot(contains('支付')));
    final ecom = presetKeywords(SmsKeywordPreset.ecommerce, const Locale('zh'));
    expect(ecom, isNot(contains('订单')));
  });
}
