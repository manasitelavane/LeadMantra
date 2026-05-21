import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  static const Color primary        = Color(0xFF1A237E);
  static const Color primaryVariant = Color(0xFF283593);
  static const Color accent         = Color(0xFFF57C00);
  static const Color accentLight    = Color(0xFFFFF3E0);

  // App bar: white background so the full logo (orange + navy) is always visible.
  static const Color appBarBg       = Colors.white;
  static const Color appBarFg       = Color(0xFF1A237E);

  static ThemeData light() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      appBarTheme: const AppBarTheme(
        backgroundColor: appBarBg,
        foregroundColor: appBarFg,
        elevation:       0,
        scrolledUnderElevation: 0,
        centerTitle:     true,
        titleTextStyle:  TextStyle(
          color:       appBarFg,
          fontSize:    16,
          fontWeight:  FontWeight.w700,
          letterSpacing: 0.3,
        ),
        iconTheme:        IconThemeData(color: appBarFg, size: 20),
        actionsIconTheme: IconThemeData(color: appBarFg, size: 20),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor:           Colors.transparent,
          statusBarIconBrightness:  Brightness.dark,
        ),
      ),
      cardTheme: const CardThemeData(
        color:     Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        margin: EdgeInsets.zero,
      ),
      iconTheme: const IconThemeData(size: 20),
      chipTheme: const ChipThemeData(labelStyle: TextStyle(fontSize: 12)),
    );
  }
}
