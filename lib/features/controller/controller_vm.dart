import 'dart:ui' show Color;
import 'package:flutter/foundation.dart';
import '../../core/models/strip_state.dart';
import '../../core/repositories/led_repository.dart';
import '../../core/storage/settings_store.dart';

class ControllerVm extends ChangeNotifier {
  final LedRepository repo;
  final SettingsStore store;
  static const nStrips = 8;
  static const maxN = 300;

  bool loading = true;

  List<StripState> strips = List.generate(
    nStrips,
    (_) => const StripState(n: 1, b: 0, s: 1, c: Color(0xFFFFFFFF)),
  );

  List<String> names = List.generate(nStrips, (i) => 'Striscia $i');

  // NUOVO: stato modalità per striscia (true=anim, false=solid)
  List<bool> animated = List.filled(nStrips, true);

  ControllerVm(this.repo, this.store);

  Future<void> load() async {
    loading = true; notifyListeners();
    try {
      // carica tutto
      final j = await repo.api.fetchState();
      final used = (j['used'] as List).cast<num>().map((e) => e.toInt()).toList();
      final b    = (j['b']    as List).cast<num>().map((e) => e.toInt()).toList();
      final s    = (j['s']    as List).cast<num>().map((e) => e.toInt()).toList();
      final c    = (j['c']    as List).cast<String>().toList();
      final m    = (j['m']    as List?)?.cast<num>().map((e) => e.toInt()).toList();

      for (var i = 0; i < nStrips; i++) {
        strips[i] = StripState.fromParts(n: used[i], b: b[i], s: s[i], hex6: c[i]);
        if (m != null && i < m.length) animated[i] = (m[i] == 0); // 0=anim, 1=solid
      }

      // nomi salvati
      final saved = await store.getStripNames();
      if (saved != null && saved.isNotEmpty) {
        names = List.generate(nStrips, (i) => i < saved.length && saved[i].trim().isNotEmpty
          ? saved[i] : 'Striscia $i');
      }
    } finally {
      loading = false; notifyListeners();
    }
  }

  void update(int i, StripState st) { strips[i] = st; notifyListeners(); }
  void setAnimated(int i, bool v) { animated[i] = v; notifyListeners(); }

  Future<void> apply(int which) async {
    final idx = which == -1 ? 0 : which; // UI usa solo 0..7
    await repo.apply(which, strips[idx], animated: animated[idx]);
    await load();
  }

  Future<void> sync() => repo.sync();

  Future<void> rename(int i, String newName) async {
    final nn = newName.trim().isEmpty ? 'Striscia $i' : newName.trim();
    names[i] = nn;
    notifyListeners();
    await store.setStripNames(names);
  }
}
