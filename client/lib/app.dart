import 'package:flutter/material.dart';

import 'api/api_client.dart';
import 'screens/users_screen.dart';
import 'theme/palette.dart';

class IWasHereApp extends StatelessWidget {
  const IWasHereApp({super.key, required this.api});

  final ApiClient api;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF8C8377),
      brightness: Brightness.dark,
    ).copyWith(
      primary: Palette.accent,
      onPrimary: const Color(0xFF17130D),
      secondary: Palette.accent,
      surface: Palette.surface,
      onSurface: Palette.text,
      error: Palette.danger,
    );

    return MaterialApp(
      title: 'I Was Here',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: Palette.background,
        splashFactory: InkRipple.splashFactory,
        appBarTheme: const AppBarTheme(
          backgroundColor: Palette.background,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleSpacing: 24,
          titleTextStyle: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 3,
            color: Palette.muted,
          ),
          iconTheme: IconThemeData(color: Palette.muted, size: 20),
          actionsIconTheme: IconThemeData(color: Palette.muted, size: 20),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontSize: 46,
            height: 1.02,
            fontWeight: FontWeight.w300,
            letterSpacing: -1.0,
            color: Palette.text,
          ),
          displaySmall: TextStyle(
            fontSize: 32,
            height: 1.1,
            fontWeight: FontWeight.w300,
            letterSpacing: -0.4,
            color: Palette.text,
          ),
          headlineSmall: TextStyle(
            fontSize: 23,
            height: 1.2,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.2,
            color: Palette.text,
          ),
          titleMedium: TextStyle(
            fontSize: 15.5,
            height: 1.35,
            fontWeight: FontWeight.w500,
            color: Palette.text,
          ),
          titleSmall: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Palette.text,
          ),
          bodyMedium: TextStyle(fontSize: 14.5, height: 1.65, color: Palette.body),
          bodySmall: TextStyle(fontSize: 12.5, height: 1.6, color: Palette.muted),
          labelLarge: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.2,
            color: Palette.body,
          ),
          labelSmall: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
            letterSpacing: 2.4,
            color: Palette.muted,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Palette.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Palette.line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Palette.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Palette.accent, width: 1.2),
          ),
          labelStyle: const TextStyle(color: Palette.muted),
          helperStyle: const TextStyle(color: Palette.muted, fontSize: 11.5),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: Palette.accent,
            foregroundColor: const Color(0xFF17130D),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
            textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, letterSpacing: 0.6),
            shape: const StadiumBorder(),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: Palette.text,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
            side: const BorderSide(color: Palette.line),
            textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, letterSpacing: 0.6),
            shape: const StadiumBorder(),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Palette.muted,
            textStyle: const TextStyle(fontSize: 12, letterSpacing: 1.2),
          ),
        ),
        chipTheme: const ChipThemeData(
          backgroundColor: Colors.transparent,
          side: BorderSide(color: Palette.line),
          labelStyle: TextStyle(color: Palette.body, fontSize: 12),
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          shape: StadiumBorder(),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF17171A),
          contentTextStyle: const TextStyle(color: Palette.text, fontSize: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          insetPadding: const EdgeInsets.all(16),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: Palette.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titleTextStyle: const TextStyle(fontSize: 19, fontWeight: FontWeight.w400, color: Palette.text),
          contentTextStyle: const TextStyle(fontSize: 14, height: 1.6, color: Palette.body),
        ),
        dividerTheme: const DividerThemeData(color: Palette.line, thickness: 1, space: 1),
        progressIndicatorTheme: const ProgressIndicatorThemeData(color: Palette.accent),
      ),
      home: UsersScreen(api: api),
    );
  }
}
