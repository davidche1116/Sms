import 'package:flutter/material.dart';

import 'features/list/home_page.dart';
import 'services/theme_store.dart';

class SmsApp extends StatefulWidget {
  const SmsApp({super.key});

  @override
  State<SmsApp> createState() => _SmsAppState();
}

class _SmsAppState extends State<SmsApp> {
  final _store = ThemeStore();

  /// 递增代际：用户在加载完成前改主题时，丢弃在途的加载结果。
  int _themeGen = 0;

  Color seed = ThemeStore.defaultSeed;
  ThemeMode mode = ThemeStore.defaultMode;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final gen = ++_themeGen;
    final (s, m) = await _store.load();
    if (!mounted || gen != _themeGen) return;
    setState(() {
      seed = s;
      mode = m;
    });
  }

  void _onThemeChanged(Color? c, ThemeMode? m) {
    _themeGen++;
    setState(() {
      if (c != null) seed = c;
      if (m != null) mode = m;
    });
    _store.save(seed: c, mode: m);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '短信清理',
      debugShowCheckedModeBanner: false,
      themeMode: mode,
      theme: _theme(Brightness.light, seed),
      darkTheme: _theme(Brightness.dark, seed),
      home: HomePage(
        seed: seed,
        mode: mode,
        onThemeChanged: _onThemeChanged,
      ),
    );
  }

  ThemeData _theme(Brightness b, Color seed) {
    // fromSeed 会推导出另一套 primary，和色盘上的色块不一致。
    // 这里强制 primary = 用户所选颜色，保证「预设绿」和标题栏颜色相同。
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: b)
        .copyWith(
          primary: seed,
          onPrimary: b == Brightness.light ? Colors.white : Colors.black,
        );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surfaceContainerLowest,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        margin: const EdgeInsets.only(bottom: 8),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: scheme.surfaceContainerLow,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
