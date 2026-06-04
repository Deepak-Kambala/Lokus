import 'package:flutter/material.dart';

class AppTheme {
  static bool isLight = false;

  static void setBrightnessMode(ThemeMode mode, Brightness platformBrightness) {
    isLight = mode == ThemeMode.light ||
        (mode == ThemeMode.system && platformBrightness == Brightness.light);
  }

  // Colors
  static Color get background =>
      isLight ? Color(0xFFF7F7F8) : Color(0xFF0E0E10);
  static Color get surface => isLight ? Color(0xFFFFFFFF) : Color(0xFF161618);
  static Color get surfaceElevated =>
      isLight ? Color(0xFFF0F0F2) : Color(0xFF1C1C1F);
  static Color get surfaceHighlight =>
      isLight ? Color(0xFFE6E6EA) : Color(0xFF242428);
  static Color get border => isLight ? Color(0xFFD7D7DD) : Color(0xFF2A2A2E);
  static Color get borderSubtle =>
      isLight ? Color(0xFFEAEAEE) : Color(0xFF1F1F23);

  static Color get accent => isLight ? Color(0xFF111113) : Color(0xFFF5F5F7);
  static Color get onAccent => isLight ? Color(0xFFFFFFFF) : Color(0xFF0E0E10);
  static Color get accentLight =>
      isLight ? Color(0xFF000000) : Color(0xFFFFFFFF);
  static Color get accentDim => isLight ? Color(0xFFB8B8C0) : Color(0xFF5C5C62);
  static Color get accentSurface =>
      isLight ? Color(0xFFEDEDF1) : Color(0xFF242428);

  static Color get textPrimary =>
      isLight ? Color(0xFF111113) : Color(0xFFF5F5F7);
  static Color get textSecondary =>
      isLight ? Color(0xFF5D5D66) : Color(0xFF8E8E93);
  static Color get textTertiary =>
      isLight ? Color(0xFF90909A) : Color(0xFF48484E);
  static Color get textDisabled =>
      isLight ? Color(0xFFB9B9C1) : Color(0xFF3A3A40);

  static Color get success => isLight ? Color(0xFF1F7A45) : Color(0xFFE6E6E8);
  static Color get warning => isLight ? Color(0xFF8A6B14) : Color(0xFFB8B8BE);
  static Color get error => isLight ? Color(0xFFB42318) : Color(0xFFFFFFFF);
  static Color get info => isLight ? Color(0xFF3F4C66) : Color(0xFFD6D6DA);

  static Color get userBubble =>
      isLight ? Color(0xFFEDEDF1) : Color(0xFF242428);
  static Color get assistantBubble =>
      isLight ? Color(0xFFFFFFFF) : Color(0xFF161618);

  static ThemeData get lightTheme {
    return darkTheme.copyWith(
      brightness: Brightness.light,
      scaffoldBackgroundColor: Color(0xFFF7F7F8),
      colorScheme: ColorScheme.light(
        primary: Color(0xFF111113),
        secondary: Color(0xFF4B4B50),
        surface: Color(0xFFFFFFFF),
        surfaceContainerHighest: Color(0xFFEAEAED),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Color(0xFF111113),
        outline: Color(0xFFD8D8DD),
        error: Color(0xFF111113),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.dark(
        primary: accent,
        primaryContainer: accentDim,
        secondary: accentLight,
        surface: surface,
        surfaceContainerHighest: surfaceHighlight,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: textPrimary,
        outline: border,
        error: error,
      ),
      fontFamily: 'Inter',
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: 0,
        ),
        displayMedium: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: 0,
        ),
        headlineLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: 0,
        ),
        headlineMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: 0,
        ),
        headlineSmall: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        titleSmall: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: textSecondary,
        ),
        bodyLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: textPrimary,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textPrimary,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: textSecondary,
          height: 1.4,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textPrimary,
          letterSpacing: 0.1,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textSecondary,
          letterSpacing: 0.1,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: textTertiary,
          letterSpacing: 0.2,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textPrimary, size: 20),
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: border, width: 1),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
      iconTheme: IconThemeData(
        color: textSecondary,
        size: 20,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: accent,
        selectionColor: accentSurface,
        selectionHandleColor: accent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceElevated,
        prefixIconColor: textSecondary,
        suffixIconColor: textSecondary,
        iconColor: textSecondary,
        labelStyle: TextStyle(
          color: textSecondary,
          fontSize: 14,
          fontFamily: 'Inter',
        ),
        hintStyle: TextStyle(
          color: textTertiary,
          fontSize: 14,
          fontFamily: 'Inter',
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: onAccent,
          elevation: 0,
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: BorderSide(color: border),
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        width: 300,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        minLeadingWidth: 24,
        iconColor: textSecondary,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          color: textSecondary,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return textTertiary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent;
          return surfaceHighlight;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: textPrimary,
        unselectedLabelColor: textSecondary,
        indicatorColor: accent,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: border,
        labelStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: surfaceHighlight,
        circularTrackColor: surfaceHighlight,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceElevated,
        contentTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          color: textPrimary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: border),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceElevated,
        selectedColor: accentSurface,
        labelStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textSecondary,
        ),
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
    );
  }
}
