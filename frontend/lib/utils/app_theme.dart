import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF1F4C7C); // Blue
  static const Color accent = Color(0xFF4285F4); // Light Blue
  static const Color background = Color(0xFFF5F5F5); // Light gray background
  static const Color card = Colors.white;
  static const Color error = Color(0xFFD32F2F);
  static const Color success = Color(0xFF34A853);
  static const Color warning = Color(0xFFFBBC05);
  static const Color text = Color(0xFF000000);
  static const Color subtitle = Color(0xFF406A93);
}

class AppFonts {
  static const String primaryFont = 'Roboto';
  static const String secondaryFont = 'Montserrat';
}

class AppImages {
  static const String logo = 'assets/images/logo.png'; 
}

ThemeData appTheme = ThemeData(
  primaryColor: AppColors.primary,
  colorScheme: ColorScheme.fromSwatch().copyWith(
    primary: AppColors.primary,
    secondary: AppColors.accent,
    background: AppColors.background,
    error: AppColors.error,
  ),
  scaffoldBackgroundColor: AppColors.background,
  fontFamily: AppFonts.primaryFont,
  appBarTheme: AppBarTheme(
    backgroundColor: AppColors.card,
    elevation: 1,
    iconTheme: IconThemeData(color: AppColors.primary),
    titleTextStyle: TextStyle(
      color: AppColors.text,
      fontWeight: FontWeight.bold,
      fontSize: 22,
      fontFamily: AppFonts.secondaryFont,
    ),
  ),
  cardTheme: CardThemeData(
    color: AppColors.card,
    elevation: 2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    margin: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
  ),
  snackBarTheme: SnackBarThemeData(
    backgroundColor: AppColors.primary,
    contentTextStyle: TextStyle(color: Colors.white),
  ),
  inputDecorationTheme: InputDecorationTheme(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: AppColors.accent),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: AppColors.primary, width: 2),
    ),
    labelStyle: TextStyle(color: AppColors.primary),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      textStyle: TextStyle(
        fontFamily: AppFonts.secondaryFont,
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
      padding: EdgeInsets.symmetric(vertical: 14, horizontal: 24),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.primary,
      side: BorderSide(color: AppColors.primary),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      textStyle: TextStyle(
        fontFamily: AppFonts.secondaryFont,
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
      padding: EdgeInsets.symmetric(vertical: 14, horizontal: 24),
    ),
  ),
  textTheme: TextTheme(
    headlineLarge: TextStyle(fontFamily: AppFonts.secondaryFont, fontWeight: FontWeight.bold, fontSize: 28, color: AppColors.text),
    headlineMedium: TextStyle(fontFamily: AppFonts.secondaryFont, fontWeight: FontWeight.bold, fontSize: 22, color: AppColors.text),
    titleLarge: TextStyle(fontFamily: AppFonts.secondaryFont, fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.text),
    bodyLarge: TextStyle(fontFamily: AppFonts.primaryFont, fontSize: 16, color: AppColors.text),
    bodyMedium: TextStyle(fontFamily: AppFonts.primaryFont, fontSize: 14, color: AppColors.subtitle),
    labelLarge: TextStyle(fontFamily: AppFonts.primaryFont, fontWeight: FontWeight.w500, fontSize: 14, color: AppColors.primary),
  ),
); 