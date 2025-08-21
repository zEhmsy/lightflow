import 'package:flutter/material.dart';


String hex6(Color c) {
  final v = (c.value & 0xFFFFFF).toRadixString(16).toUpperCase().padLeft(6, '0');
  return v;
}


Color colorFromHex6(String hex) {
  final clean = hex.replaceAll('#', '');
  final v = int.parse(clean, radix: 16) & 0xFFFFFF;
  return Color(0xFF000000 | v);
}