import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/strip_state.dart';


class LedApi {
  final String base; // es. http://192.168.1.120:80
  const LedApi(this.base);


  Uri _u(String path, [Map<String, String>? q]) {
    final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final u = Uri.parse('$b$path');
    return q == null ? u : u.replace(queryParameters: q);
  }


  Future<List<StripState>> fetchState({Duration timeout = const Duration(seconds: 5)}) async {
    final r = await http.get(_u('/state')).timeout(timeout);
    if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    return StripState.fromJsonState(j);
  }


  Future<void> setStrip(int which, StripState st) async {
    final params = {
      'which': '$which',
      'n': '${st.n}',
      'b': '${st.b}',
      's': '${st.s}',
      'c': st.c.value.toRadixString(16).toUpperCase().padLeft(8, '0').substring(2),
    };
    final r = await http.get(_u('/set', params)).timeout(const Duration(seconds: 5));
    if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
  }


  Future<void> sync() async {
    final r = await http.get(_u('/sync')).timeout(const Duration(seconds: 5));
    if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
  }
}