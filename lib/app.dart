import 'package:flutter/material.dart';
import 'features/connect/connect_page.dart';


class LedApp extends StatelessWidget {
  const LedApp({super.key});


  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF2B60FF);
    return MaterialApp(
      title: 'LED 8 Strisce',
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: seed,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: seed,
        brightness: Brightness.dark,
      ).copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B0B10),
        cardColor: const Color(0xFF17171F),
      ),
      home: const ConnectPage(),
    );
  }
}