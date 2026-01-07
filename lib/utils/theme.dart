import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Pro Color Palette (Neon & Deep Slate)
  static const Color _seedColor = Color(0xFF6366F1); // Indigo
  static const Color _successColor = Color(0xFF10B981); // Emerald
  static const Color _warningColor = Color(0xFFF59E0B); // Amber
  static const Color _errorColor = Color(0xFFEF4444); // Red
  static const Color _infoColor = Color(0xFF3B82F6); // Blue
  
  static const Color _surfaceDark = Color(0xFF1E293B); // Slate 800
  static const Color _backgroundDark = Color(0xFF0F172A); // Slate 900

  // Public Static Colors (for backward compatibility / direct usage)
  static const Color successColor = _successColor;
  static const Color warningColor = _warningColor;
  static const Color errorColor = _errorColor;
  static const Color infoColor = _infoColor;
  
  // Color Schemes
  static final ColorScheme _lightColorScheme = ColorScheme.light(
    primary: const Color(0xFF4F46E5), // Indigo 600
    onPrimary: Colors.white,
    secondary: const Color(0xFF0EA5E9), // Sky 500
    onSecondary: Colors.white,
    tertiary: const Color(0xFFEC4899), // Pink 500
    surface: Colors.white,
    onSurface: const Color(0xFF0F172A),
    error: _errorColor,
    outline: const Color(0xFFCBD5E1),
    shadow: const Color(0x1A000000),
  );

  static final ColorScheme _darkColorScheme = ColorScheme.dark(
    primary: const Color(0xFF818CF8), // Indigo 400
    onPrimary: const Color(0xFF1E1B4B),
    secondary: const Color(0xFF38BDF8), // Sky 400
    onSecondary: const Color(0xFF0C4A6E),
    tertiary: const Color(0xFFF472B6), // Pink 400
    surface: _surfaceDark,
    onSurface: const Color(0xFFF1F5F9),
    error: const Color(0xFFF87171),
    outline: const Color(0xFF475569),
    shadow: Colors.black54,
  );

  // Light Theme
  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        colorScheme: _lightColorScheme,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC), // Slate 50
        fontFamily: GoogleFonts.inter().fontFamily,
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 2,
          shadowColor: _lightColorScheme.shadow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: _lightColorScheme.onSurface,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: GoogleFonts.outfit(
            color: _lightColorScheme.onSurface,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        textTheme: _buildTextTheme(_lightColorScheme.onSurface),
        iconTheme: IconThemeData(color: _lightColorScheme.onSurface),
        dividerTheme: DividerThemeData(color: _lightColorScheme.outline.withOpacity(0.5)),
      );

  // Dark Theme ("Pro" Mode)
  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: _darkColorScheme,
        scaffoldBackgroundColor: _backgroundDark,
        fontFamily: GoogleFonts.inter().fontFamily,
        cardTheme: const CardThemeData(
          color: _surfaceDark,
          elevation: 4,
          shadowColor: Colors.black26,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: _darkColorScheme.onSurface,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: GoogleFonts.outfit(
            color: _darkColorScheme.onSurface,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        textTheme: _buildTextTheme(_darkColorScheme.onSurface),
        iconTheme: IconThemeData(color: _darkColorScheme.onSurface),
        dividerTheme: DividerThemeData(color: _darkColorScheme.outline.withOpacity(0.5)),
      );

  static TextTheme _buildTextTheme(Color color) {
    return TextTheme(
      displayLarge: displayLarge.copyWith(color: color),
      displayMedium: displayMedium.copyWith(color: color),
      displaySmall: displaySmall.copyWith(color: color),
      headlineLarge: headlineLarge.copyWith(color: color),
      headlineMedium: headlineMedium.copyWith(color: color),
      headlineSmall: headlineSmall.copyWith(color: color),
      titleLarge: titleLarge.copyWith(color: color),
      titleMedium: titleMedium.copyWith(color: color),
      titleSmall: titleSmall.copyWith(color: color),
      bodyLarge: bodyLarge.copyWith(color: color),
      bodyMedium: bodyMedium.copyWith(color: color.withOpacity(0.8)),
      bodySmall: bodySmall.copyWith(color: color.withOpacity(0.6)),
    );
  }

  // Static properties for direct usage (Fixing Member not found errors)
  static TextStyle get displayLarge => GoogleFonts.outfit(fontSize: 57, fontWeight: FontWeight.bold);
  static TextStyle get displayMedium => GoogleFonts.outfit(fontSize: 45, fontWeight: FontWeight.bold);
  static TextStyle get displaySmall => GoogleFonts.outfit(fontSize: 36, fontWeight: FontWeight.w600);
  
  static TextStyle get headlineLarge => GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w600);
  static TextStyle get headlineMedium => GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w600);
  static TextStyle get headlineSmall => GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w500);
  
  static TextStyle get titleLarge => GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w500);
  static TextStyle get titleMedium => GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500);
  static TextStyle get titleSmall => GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500);
  
  static TextStyle get bodyLarge => GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400);
  static TextStyle get bodyMedium => GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400);
  static TextStyle get bodySmall => GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400);

  // Spacing & Radius constants
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 16.0;
  static const double spacingL = 24.0;
  static const double spacingXL = 32.0;

  static const double radiusS = 8.0;
  static const double radiusM = 16.0;
  static const double radiusL = 24.0;

  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 350);
  
  static const double elevationS = 2;
  static const double elevationM = 4;
}
