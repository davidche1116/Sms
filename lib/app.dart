import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'features/list/home_page.dart';
import 'generated/app_localizations.dart';
import 'services/locale_store.dart';
import 'services/theme_store.dart';

class SmsApp extends StatefulWidget {
  const SmsApp({super.key, this.locale});

  /// 强制界面语言（测试用）；null 时读 [LocaleStore]，再跟随系统。
  final Locale? locale;

  @override
  State<SmsApp> createState() => _SmsAppState();
}

class _SmsAppState extends State<SmsApp> {
  final _store = ThemeStore();
  final _localeStore = LocaleStore();

  /// 递增代际：用户在加载完成前改主题时，丢弃在途的加载结果。
  int _themeGen = 0;

  Color seed = ThemeStore.defaultSeed;
  ThemeMode mode = ThemeStore.defaultMode;

  /// 用户选择的界面语言；null = 跟随系统。
  Locale? _preferredLocale;

  @override
  void initState() {
    super.initState();
    unawaited(_loadTheme());
    unawaited(_loadLocale());
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

  Future<void> _loadLocale() async {
    final l = await _localeStore.load();
    if (!mounted) return;
    setState(() => _preferredLocale = l);
  }

  void _onThemeChanged(Color? c, ThemeMode? m) {
    _themeGen++;
    setState(() {
      if (c != null) seed = c;
      if (m != null) mode = m;
    });
    unawaited(_store.save(seed: c, mode: m));
  }

  void _onLocaleChanged(Locale? locale) {
    setState(() => _preferredLocale = locale);
    unawaited(_localeStore.save(locale));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: widget.locale ?? _preferredLocale,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      localeListResolutionCallback: (deviceLocales, supported) {
        // 测试强制 locale 优先，其次用户在设置里选的语言，最后跟随系统。
        if (widget.locale != null) return widget.locale;
        if (_preferredLocale != null) return _preferredLocale;
        for (final l in deviceLocales ?? const <Locale>[]) {
          // 先精确匹配 language+country（zh_TW → 繁中），再回落同语言。
          for (final s in supported) {
            if (s.languageCode == l.languageCode &&
                s.countryCode == l.countryCode) {
              return s;
            }
          }
          for (final s in supported) {
            if (s.languageCode == l.languageCode) return s;
          }
        }
        // 产品默认中文。
        return const Locale('zh');
      },
      themeMode: mode,
      theme: _theme(Brightness.light, seed),
      darkTheme: _theme(Brightness.dark, seed),
      home: HomePage(
        seed: seed,
        mode: mode,
        onThemeChanged: _onThemeChanged,
        locale: widget.locale ?? _preferredLocale,
        onLocaleChanged: _onLocaleChanged,
      ),
    );
  }

  ThemeData _theme(Brightness b, Color seed) {
    // fromSeed 会推导出另一套 primary，和色盘上的色块不一致。
    // 这里强制 primary = 用户所选颜色，保证「预设绿」和标题栏颜色相同。
    final seedBrightness = ThemeData.estimateBrightnessForColor(seed);
    final onPrimary = seedBrightness == Brightness.light
        ? Colors.black
        : Colors.white;
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: b,
    ).copyWith(primary: seed, onPrimary: onPrimary);
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
