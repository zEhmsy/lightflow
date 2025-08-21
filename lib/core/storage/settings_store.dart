import 'package:shared_preferences/shared_preferences.dart';

class SettingsStore {
  static const _kLastBase = 'last_base';
  static const _kStripNames = 'strip_names';

  Future<String?> getLastBase() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kLastBase);
  }

  Future<void> setLastBase(String base) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kLastBase, base);
  }

  // NEW: persistenza nomi strisce
  Future<List<String>?> getStripNames() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getStringList(_kStripNames);
  }

  Future<void> setStripNames(List<String> names) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setStringList(_kStripNames, names);
  }
}