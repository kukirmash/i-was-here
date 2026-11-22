import 'package:flutter/material.dart';

import 'api/api_client.dart';
import 'screens/users_screen.dart';

class IWasHereApp extends StatelessWidget {
  const IWasHereApp({super.key, required this.api});

  final ApiClient api;

  static const Color _background = Color(0xFF0E1014);
  static const Color _accent = Color(0xFFD8C08A);

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF8E9BB3),
      brightness: Brightness.dark,
    ).copyWith(
      secondary: _accent,
      tertiary: const Color(0xFF7FB3A8),
    );

    return MaterialApp(
      title: 'I Was Here',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        scaffoldBackgroundColor: _background,
        appBarTheme: const AppBarTheme(
          backgroundColor: _background,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
            color: Color(0xFFF1EEE7),
          ),
          iconTheme: IconThemeData(color: Color(0xFFCBC4B6)),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Color(0xFF171A20),
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFF23272F),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: _accent,
          foregroundColor: Color(0xFF1A1712),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: _accent,
            foregroundColor: const Color(0xFF1A1712),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFE6DFD2),
            side: const BorderSide(color: Color(0xFF3A3F4A)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          ),
        ),
        chipTheme: const ChipThemeData(
          backgroundColor: Color(0xFF1B1F26),
          side: BorderSide(color: Color(0xFF343A44)),
          labelStyle: TextStyle(color: Color(0xFFE6DFD2)),
        ),
      ),
      home: UsersScreen(api: api),
    );
  }
}
