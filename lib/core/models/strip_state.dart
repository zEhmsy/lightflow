import 'dart:ui' show Color;
import '../utils/color_hex.dart';

class StripState {
  final int n; // led usati (1..MAX)
  final int b; // brightness (0..255)
  final int s; // speed ms (1..50)
  final Color c; // colore

  const StripState({
    required this.n,
    required this.b,
    required this.s,
    required this.c,
  });

  StripState copyWith({int? n, int? b, int? s, Color? c}) => StripState(
        n: n ?? this.n,
        b: b ?? this.b,
        s: s ?? this.s,
        c: c ?? this.c,
      );

  /// Crea da parti “grezze” dell’API: n,b,s e colore in **RRGGBB**
  factory StripState.fromParts({
    required int n,
    required int b,
    required int s,
    required String hex6,
  }) {
    return StripState(
      n: n,
      b: b,
      s: s,
      c: colorFromHex6(hex6),
    );
  }
}
