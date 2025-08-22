import 'dart:ui' show Color;
import 'package:flutter/foundation.dart';
import '../../core/models/strip_state.dart';
import '../../core/repositories/led_repository.dart';
import '../../core/storage/settings_store.dart';
import 'dart:async';

class ControllerVm extends ChangeNotifier {
  // Delay per coalescere input rapidi (slider, carosello, ecc.)
  final Duration _debounceDelay = const Duration(milliseconds: 350);
  // Timer per-strip
  final List<Timer?> _debounce = List<Timer?>.filled(nStrips, null, growable: false);
  // Stato invii in corso / pendenti (per evitare sovrapposizioni)
  final List<bool> _inFlight = List<bool>.filled(nStrips, false, growable: false);
  final List<bool> _pending  = List<bool>.filled(nStrips, false, growable: false);
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

  void updateAndAutoApply(int i, StripState st) {
    strips[i] = st;
    notifyListeners();
    _scheduleApply(i);
  }

  void setAnimated(int i, bool v) {
    animated[i] = v;
    notifyListeners();
    _scheduleApply(i);
  }

  void _scheduleApply(int i) {
    _debounce[i]?.cancel();
    _debounce[i] = Timer(_debounceDelay, () => _sendApply(i));
  }

  Future<void> _sendApply(int i) async {
    if (_inFlight[i]) { _pending[i] = true; return; }
    _inFlight[i] = true;
    try {
      await repo.apply(i, strips[i], animated: animated[i]);
      // niente load() qui: manteniamo la UI reattiva; lo stato locale è già aggiornato
    } catch (_) {
      // opzionale: log/telemetria
    } finally {
      _inFlight[i] = false;
      if (_pending[i]) {
        _pending[i] = false;
        _scheduleApply(i); // invia l’ultimo stato rimasto indietro
      }
    }
  }
}
