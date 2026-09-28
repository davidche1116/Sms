import 'package:shared_preferences/shared_preferences.dart';

/// 「移出列表」的本地隐藏 id 持久化；重启后仍然生效。
class HiddenStore {
  static const _key = 'hidden_sms_ids';

  Future<Set<int>> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(_key) ?? const [];
    return raw.map(int.tryParse).nonNulls.toSet();
  }

  Future<void> save(Set<int> ids) async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_key, ids.map((e) => e.toString()).toList());
  }

  Future<void> clear() => save(<int>{});
}
