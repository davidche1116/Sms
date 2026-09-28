import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 界面语言持久化：`system` 或 `zh` / `zh_TW` / `en`。
class LocaleStore {
  static const _key = 'app_locale';

  /// 跟随系统。
  static const system = '';

  Future<Locale?> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      return _parse(p.getString(_key));
    } catch (_) {
      return null;
    }
  }

  Future<void> save(Locale? locale) async {
    try {
      final p = await SharedPreferences.getInstance();
      if (locale == null) {
        await p.setString(_key, system);
      } else {
        await p.setString(
          _key,
          locale.countryCode == null || locale.countryCode!.isEmpty
              ? locale.languageCode
              : '${locale.languageCode}_${locale.countryCode}',
        );
      }
    } catch (_) {
      // 写失败下次启动回退跟随系统
    }
  }

  Locale? _parse(String? raw) {
    if (raw == null || raw == system) return null;
    final parts = raw.split('_');
    if (parts.isEmpty || parts.first.isEmpty) return null;
    if (parts.length == 1) return Locale(parts.first);
    return Locale(parts.first, parts[1]);
  }
}
