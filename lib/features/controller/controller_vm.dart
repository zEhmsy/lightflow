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

  // NEW: nomi visualizzati
  List<String> names = List.generate(nStrips, (i) => 'Striscia $i');

  ControllerVm(this.repo, this.store);

  Future<void> load() async {
    loading = true; notifyListeners();
    try {
      final fetched = await repo.load();
      if (fetched.length >= nStrips) {
        strips = fetched.take(nStrips).toList();
      } else {
        for (var i = 0; i < nStrips; i++) {
          if (i < fetched.length) strips[i] = fetched[i];
        }
      }
      final saved = await store.getStripNames();
      if (saved != null && saved.isNotEmpty) {
        // adatta le lunghezze
        names = List.generate(nStrips, (i) => i < saved.length ? (saved[i].isEmpty ? 'Striscia $i' : saved[i]) : 'Striscia $i');
      }
    } finally {
      loading = false; notifyListeners();
    }
  }

  Future<void> apply(int which) async {
    final st = which == -1 ? strips[0] : strips[which];
    await repo.apply(which, st);
    await load();
  }

  Future<void> sync() => repo.sync();

  void update(int i, StripState st) {
    strips[i] = st; notifyListeners();
  }

  // NEW: rinomina con persistenza
  Future<void> rename(int i, String newName) async {
    final nn = newName.trim().isEmpty ? 'Striscia $i' : newName.trim();
    names[i] = nn;
    notifyListeners();
    await store.setStripNames(names);
  }
}