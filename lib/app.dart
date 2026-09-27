import 'package:flutter/material.dart';

import 'features/list/home_page.dart';

class SmsApp extends StatefulWidget {
  const SmsApp({super.key});

  @override
  State<SmsApp> createState() => _SmsAppState();
}

class _SmsAppState extends State<SmsApp> {
  Color seed = const Color(0xFF2BAE67);
  ThemeMode mode = ThemeMode.system;

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
        onThemeChanged: (c, m) => setState(() {
          if (c != null) seed = c;
          if (m != null) mode = m;
        }),
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
