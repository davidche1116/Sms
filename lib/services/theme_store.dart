import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 主题色与深色模式的本地持久化；重启后仍然生效。
class ThemeStore {
  static const _seedKey = 'theme_seed_argb';
  static const _modeKey = 'theme_mode';

  static const defaultSeed = Color(0xFF2BAE67);
  static const defaultMode = ThemeMode.system;

  Future<(Color, ThemeMode)> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      return (_seed(p) ?? defaultSeed, _mode(p) ?? defaultMode);
    } catch (_) {
      return (defaultSeed, defaultMode);
    }
  }

  Future<void> save({Color? seed, ThemeMode? mode}) async {
    try {
      final p = await SharedPreferences.getInstance();
      if (seed != null) await p.setInt(_seedKey, seed.toARGB32());
      if (mode != null) await p.setString(_modeKey, mode.name);
    } catch (_) {
      // 写入失败不影响本次会话外观，下次启动回退默认
    }
  }

  /// 单字段容错：类型损坏只回退该字段，不连带另一字段。
  Color? _seed(SharedPreferences p) {
    try {
      final v = p.getInt(_seedKey);
      return v == null ? null : Color(v);
    } catch (_) {
      return null;
    }
  }

  ThemeMode? _mode(SharedPreferences p) {
    try {
      final raw = p.getString(_modeKey);
      for (final m in ThemeMode.values) {
        if (m.name == raw) return m;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
