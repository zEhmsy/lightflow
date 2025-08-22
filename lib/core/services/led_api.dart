import 'dart:convert';
import 'dart:ui' show Color;
import 'package:http/http.dart' as http;
import '../models/strip_state.dart';
import '../utils/color_hex.dart';

class LedApi {
  final String base; // es. http://192.168.1.75:80
  LedApi(this.base);

  Uri _u(String path, [Map<String, String>? q]) {
    final p = path.startsWith('/') ? path : '/$path';
    return Uri.parse(base + p).replace(queryParameters: q);
  }

  Future<Map<String, dynamic>> fetchState({Duration timeout = const Duration(seconds: 5)}) async {
    final r = await http.get(_u('/state')).timeout(timeout);
    if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  // Applica SOLO alla striscia 'which'; parametri omessi non cambiano
  Future<void> setStrip(int which, StripState st, {bool? animated}) async {
    final params = <String, String>{
      'which': '$which',
      'n': '${st.n}',
      'b': '${st.b}',
      's': '${st.s.clamp(1, 50)}',             // clamp 1..50 ms
      'c': hex6(st.c),                         // RRGGBB senza '#'
    };
    if (animated != null) {
      params['mode'] = animated ? 'anim' : 'solid';
    }
    final r = await http.get(_u('/set', params)).timeout(const Duration(seconds: 5));
    if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
  }

  Future<void> sync() async {
    final r = await http.get(_u('/sync')).timeout(const Duration(seconds: 5));
    if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
  }
}
