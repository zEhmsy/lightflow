import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/device_info.dart';


class DevicesStore {
  static const _kDevices = 'devices_known_v1';


  Future<List<DeviceInfo>> getAll() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getStringList(_kDevices) ?? const [];
    return raw.map((s) => DeviceInfo.fromJson(jsonDecode(s) as Map<String, dynamic>)).toList();
  }


  Future<void> upsert(DeviceInfo d) async {
    final sp = await SharedPreferences.getInstance();
    final list = sp.getStringList(_kDevices) ?? <String>[];
    final items = list
      .map((s) => DeviceInfo.fromJson(jsonDecode(s) as Map<String, dynamic>))
      .toList();
    final idx = items.indexWhere((x) => x.id == d.id);
    if (idx >= 0) {
      items[idx] = d;
    } else {
      items.add(d);
    }
    await sp.setStringList(_kDevices, items.map((e) => jsonEncode(e.toJson())).toList());
  }
}
