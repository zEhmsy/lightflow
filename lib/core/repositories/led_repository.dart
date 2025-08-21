import '../models/strip_state.dart';
import '../services/led_api.dart';


class LedRepository {
  final LedApi api;
  const LedRepository(this.api);


  Future<List<StripState>> load() => api.fetchState();
  Future<void> apply(int which, StripState st) => api.setStrip(which, st);
  Future<void> sync() => api.sync();
}