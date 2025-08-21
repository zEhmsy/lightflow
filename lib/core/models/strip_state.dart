import 'package:flutter/material.dart';
import '../utils/color_hex.dart';


class StripState {
  final int n; // LED usati
  final int b; // brightness 0..255
  final int s; // delay ms 1..1000
  final Color c; // colore


  const StripState({required this.n, required this.b, required this.s, required this.c});


  StripState copyWith({int? n, int? b, int? s, Color? c}) =>
    StripState(n: n ?? this.n, b: b ?? this.b, s: s ?? this.s, c: c ?? this.c);


  static List<StripState> fromJsonState(Map<String, dynamic> j) {
    final used = (j['used'] as List).cast<num>().map((e) => e.toInt()).toList();
    final b = (j['b'] as List).cast<num>().map((e) => e.toInt()).toList();
    final s = (j['s'] as List).cast<num>().map((e) => e.toInt()).toList();
    final c = (j['c'] as List).cast<String>().map((e) => colorFromHex6(e)).toList();
    final len = [used.length, b.length, s.length, c.length].reduce((a, b) => a < b ? a : b);
    return List.generate(len, (i) => StripState(n: used[i], b: b[i], s: s[i], c: c[i]));
  }
}