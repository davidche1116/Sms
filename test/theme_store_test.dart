import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sms/app.dart';
import 'package:sms/services/theme_store.dart';

import 'helpers/app_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('空存储返回默认主题色与跟随系统', () async {
    final (seed, mode) = await ThemeStore().load();
    expect(seed.toARGB32(), ThemeStore.defaultSeed.toARGB32());
    expect(mode, ThemeMode.system);
  });

  test('save 后 load 读回相同 seed 与 mode', () async {
    const seed = Color(0xFF2B7FE7);
    await ThemeStore().save(seed: seed, mode: ThemeMode.dark);

    final (s, m) = await ThemeStore().load();
    expect(s.toARGB32(), seed.toARGB32());
    expect(m, ThemeMode.dark);
  });

  test('只写 seed 时 mode 保持默认；只写 mode 时 seed 保持默认', () async {
    const seed = Color(0xFFEC407A);
    await ThemeStore().save(seed: seed);
    var (s, m) = await ThemeStore().load();
    expect(s.toARGB32(), seed.toARGB32());
    expect(m, ThemeMode.system);

    await ThemeStore().save(mode: ThemeMode.light);
    (s, m) = await ThemeStore().load();
    expect(s.toARGB32(), seed.toARGB32());
    expect(m, ThemeMode.light);
  });

  test('非法 mode 字符串回退默认，seed 不受影响', () async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('theme_seed_argb', 0xFFE67E22);
    await p.setString('theme_mode', 'purple');

    final (s, m) = await ThemeStore().load();
    expect(s.toARGB32(), 0xFFE67E22);
    expect(m, ThemeMode.system);
  });

  test('seed 类型错误时回退默认色', () async {
    final p = await SharedPreferences.getInstance();
    await p.setString('theme_seed_argb', 'not-an-int');
    await p.setString('theme_mode', 'dark');

    final (s, m) = await ThemeStore().load();
    expect(s.toARGB32(), ThemeStore.defaultSeed.toARGB32());
    expect(m, ThemeMode.dark);
  });

  test('与 HiddenStore 键名不冲突', () async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList('hidden_sms_ids', ['1', '2']);
    await ThemeStore().save(
      seed: const Color(0xFF00BCD4),
      mode: ThemeMode.dark,
    );

    expect(p.getStringList('hidden_sms_ids'), ['1', '2']);
    expect(p.getInt('theme_seed_argb'), 0xFF00BCD4);
    expect(p.getString('theme_mode'), 'dark');
    expect(
      p.getKeys(),
      containsAll(['hidden_sms_ids', 'theme_seed_argb', 'theme_mode']),
    );
  });

  group('SmsApp 启动加载', () {
    tearDown(clearAppChannelHandler);

    void mockChannel() {
      setAppChannelHandler((call) async {
        switch (call.method) {
          case 'hasReadSmsPermission':
          case 'isDefaultSms':
            return true;
          case 'querySms':
            return {'messages': <Map<String, dynamic>>[], 'error': null};
          default:
            return null;
        }
      });
    }

    testWidgets('已持久化的 seed 与 mode 启动后生效', (tester) async {
      SharedPreferences.setMockInitialValues({
        'theme_seed_argb': 0xFF7B61FF,
        'theme_mode': 'dark',
      });
      mockChannel();

      await tester.pumpWidget(const SmsApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.dark);
      expect(app.theme!.colorScheme.primary.toARGB32(), 0xFF7B61FF);
      expect(app.darkTheme!.colorScheme.primary.toARGB32(), 0xFF7B61FF);
    });

    testWidgets('无持久化时使用默认主题', (tester) async {
      mockChannel();
      await tester.pumpWidget(const SmsApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.system);
      expect(
        app.theme!.colorScheme.primary.toARGB32(),
        ThemeStore.defaultSeed.toARGB32(),
      );
    });
  });
}
