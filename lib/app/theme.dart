import 'package:flutter/material.dart';

/// GRP design tokens. Keeps the Rive template palette and adds semantic colors.
class GrpTheme {
  static ThemeData light() {
    const seed = Color(0xFF2D5BFF);
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: seed),
      scaffoldBackgroundColor: const Color(0xFFEEF1F8),
      fontFamily: 'Intel',
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        errorStyle: TextStyle(height: 0),
        border: defaultGrpInputBorder,
        enabledBorder: defaultGrpInputBorder,
        focusedBorder: defaultGrpInputBorder,
        errorBorder: defaultGrpInputBorder,
      ),
    );
  }
}

const defaultGrpInputBorder = OutlineInputBorder(
  borderRadius: BorderRadius.all(Radius.circular(16)),
  borderSide: BorderSide(color: Color(0xFFDEE3F2), width: 1),
);
