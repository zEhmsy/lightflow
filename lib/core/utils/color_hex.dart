import 'dart:ui' show Color;

String hex6(Color c) =>
    c.value.toRadixString(16).toUpperCase().padLeft(8, '0').substring(2);

Color colorFromHex6(String hex) {
  final clean = hex.replaceAll('#', '').toUpperCase();
  final v = int.parse(clean, radix: 16) & 0xFFFFFF;
  return Color(0xFF000000 | v);
}
