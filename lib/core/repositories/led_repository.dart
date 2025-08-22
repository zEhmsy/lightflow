import '../models/strip_state.dart';
import '../services/led_api.dart';

class LedRepository {
  final LedApi api;
  LedRepository(this.api);

  Future<List<StripState>> load() async {
    final j = await api.fetchState();
    final used = (j['used'] as List).cast<num>().map((e) => e.toInt()).toList();
    final b    = (j['b']    as List).cast<num>().map((e) => e.toInt()).toList();
    final s    = (j['s']    as List).cast<num>().map((e) => e.toInt()).toList();
    final c    = (j['c']    as List).cast<String>().toList();
    // se serve anche la m[] lo leggerà la VM
    return List.generate(used.length, (i) => StripState.fromParts(
      n: used[i], b: b[i], s: s[i], hex6: c[i],
    ));
  }

  Future<void> apply(int which, StripState st, {bool? animated}) =>
      api.setStrip(which, st, animated: animated);

  Future<void> sync() => api.sync();
}
