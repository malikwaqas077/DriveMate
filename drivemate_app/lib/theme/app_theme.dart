import 'package:flutter/material.dart';

/// DriveMate App Theme
/// Modern Material 3 design with custom color palette, typography, and component themes

/// Theme extension for custom gradients derived from the current theme color
class DriveMateThemeExtension extends ThemeExtension<DriveMateThemeExtension> {
  const DriveMateThemeExtension({
    required this.primaryGradient,
    required this.heroGradient,
  });

  final LinearGradient primaryGradient;
  final LinearGradient heroGradient;

  @override
  DriveMateThemeExtension copyWith({
    LinearGradient? primaryGradient,
    LinearGradient? heroGradient,
  }) =>
      DriveMateThemeExtension(
        primaryGradient: primaryGradient ?? this.primaryGradient,
        heroGradient: heroGradient ?? this.heroGradient,
      );

  @override
  DriveMateThemeExtension lerp(
    covariant ThemeExtension<DriveMateThemeExtension>? other,
    double t,
  ) =>
      this;
}

/// Creates a gradient from a base color (darker -> base -> lighter)
LinearGradient _gradientFromColor(Color base, {bool isDark = false}) {
  final darker = Color.lerp(base, Colors.black, 0.25) ?? base;
  final lighter = Color.lerp(base, Colors.white, isDark ? 0.1 : 0.2) ?? base;
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [darker, base, lighter],
    stops: const [0.0, 0.5, 1.0],
  );
}

class AppTheme {
  AppTheme._();

  // ─────────────────────────────────────────────────────────────────────────────
  // BRAND COLORS (semantic - do not change with theme color)
  // ─────────────────────────────────────────────────────────────────────────────

  // Primary palette - fallback when no context (e.g. default seed = teal)
  static const Color primaryDark = Color(0xFF0D7377);
  static const Color primary = Color(0xFF14919B);
  static const Color primaryLight = Color(0xFF32E0C4);

  // Secondary palette - Warm orange accents
  static const Color secondaryDark = Color(0xFFE65100);
  static const Color secondary = Color(0xFFFF8A50);
  static const Color secondaryLight = Color(0xFFFFBB93);

  // Accent colors for status indicators
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFDBEAFE);

  // Neutral palette
  static const Color neutral50 = Color(0xFFFAFAFA);
  static const Color neutral100 = Color(0xFFF4F4F5);
  static const Color neutral200 = Color(0xFFE4E4E7);
  static const Color neutral300 = Color(0xFFD4D4D8);
  static const Color neutral400 = Color(0xFFA1A1AA);
  static const Color neutral500 = Color(0xFF71717A);
  static const Color neutral600 = Color(0xFF52525B);
  static const Color neutral700 = Color(0xFF3F3F46);
  static const Color neutral800 = Color(0xFF27272A);
  static const Color neutral900 = Color(0xFF18181B);

  // Default gradient (used when no BuildContext available)
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryDark, primary, primaryLight],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0D7377), Color(0xFF14919B), Color(0xFF212F45)],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC)],
  );

  /// Build light theme with the given seed color
  static ThemeData lightTheme(int seedColorValue) {
    final seedColor = Color(seedColorValue);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
      primary: seedColor,
      onPrimary: Colors.white,
      error: error,
      onError: Colors.white,
      errorContainer: errorLight,
      onErrorContainer: error,
      surface: Colors.white,
      onSurface: neutral900,
      surfaceContainerHighest: neutral100,
      onSurfaceVariant: neutral600,
      outline: neutral300,
      outlineVariant: neutral200,
      shadow: Colors.black.withOpacity(0.05),
    );

    final primaryColor = colorScheme.primary;
    final extensions = DriveMateThemeExtension(
      primaryGradient: _gradientFromColor(primaryColor, isDark: false),
      heroGradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(primaryColor, Colors.black, 0.3) ?? primaryColor,
          primaryColor,
          const Color(0xFF212F45),
        ],
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      extensions: [extensions],
      brightness: Brightness.light,
      scaffoldBackgroundColor: neutral50,
      fontFamily: 'Inter',

      // AppBar Theme
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: neutral900,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: neutral900,
          letterSpacing: -0.5,
        ),
        iconTheme: const IconThemeData(color: neutral700),
      ),

      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        elevation: 0,
        backgroundColor: Colors.white,
        selectedItemColor: primaryColor,
        unselectedItemColor: neutral400,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),

      // Navigation Bar Theme (Material 3)
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: primaryColor.withOpacity(0.15),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: primaryColor, size: 24);
          }
          return IconThemeData(color: neutral500, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: primaryColor,
            );
          }
          return TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: neutral500,
          );
        }),
      ),

      // Tab Bar Theme
      tabBarTheme: TabBarThemeData(
        labelColor: primaryColor,
        unselectedLabelColor: neutral500,
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(width: 3, color: primaryColor),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
        ),
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
      ),

      // Card Theme
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: neutral200, width: 1),
        ),
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: neutral100,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        isDense: false,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: neutral200, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: neutral200, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: error, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: neutral200, width: 1),
        ),
        labelStyle: TextStyle(color: neutral600, fontWeight: FontWeight.w500),
        hintStyle: TextStyle(color: neutral400),
        prefixIconColor: neutral500,
        suffixIconColor: neutral500,
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // Filled Button Theme
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: BorderSide(color: primaryColor, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Floating Action Button Theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 4,
        highlightElevation: 8,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        extendedPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),

      // Chip Theme
      chipTheme: ChipThemeData(
        elevation: 0,
        backgroundColor: neutral100,
        selectedColor: primary.withOpacity(0.15),
        labelStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: neutral700,
        ),
        secondaryLabelStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: primaryColor,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        side: BorderSide.none,
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        elevation: 8,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: neutral900,
          letterSpacing: -0.3,
        ),
        contentTextStyle: TextStyle(
          fontSize: 15,
          color: neutral700,
          height: 1.5,
        ),
      ),

      // Bottom Sheet Theme
      bottomSheetTheme: const BottomSheetThemeData(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: true,
        dragHandleColor: neutral300,
        dragHandleSize: Size(40, 4),
      ),

      // Snackbar Theme
      snackBarTheme: SnackBarThemeData(
        elevation: 0,
        backgroundColor: neutral800,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.all(16),
      ),

      // List Tile Theme
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: neutral900,
        ),
        subtitleTextStyle: TextStyle(
          fontSize: 14,
          color: neutral600,
        ),
      ),

      // Divider Theme
      dividerTheme: DividerThemeData(
        color: neutral200,
        thickness: 1,
        space: 1,
      ),

      // Switch Theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return neutral400;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primary;
          }
          return neutral200;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),

      // Progress Indicator Theme
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primaryColor,
        linearTrackColor: neutral200,
        circularTrackColor: neutral200,
      ),

      // Icon Theme
      iconTheme: const IconThemeData(
        color: neutral700,
        size: 24,
      ),

      // Text Theme
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 57,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.25,
          color: neutral900,
        ),
        displayMedium: TextStyle(
          fontSize: 45,
          fontWeight: FontWeight.w400,
          color: neutral900,
        ),
        displaySmall: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w400,
          color: neutral900,
        ),
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
          color: neutral900,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
          color: neutral900,
        ),
        headlineSmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
          color: neutral900,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: neutral900,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
          color: neutral900,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
          color: neutral900,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.15,
          color: neutral700,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.25,
          color: neutral700,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.4,
          color: neutral600,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: neutral900,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
          color: neutral700,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
          color: neutral600,
        ),
      ),
    );
  }

  /// Build dark theme with the given seed color
  static ThemeData darkTheme(int seedColorValue) {
    final seedColor = Color(seedColorValue);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
      primary: Color.lerp(seedColor, Colors.white, 0.2) ?? seedColor,
      onPrimary: neutral900,
      error: const Color(0xFFFCA5A5),
      onError: neutral900,
      errorContainer: const Color(0xFF7F1D1D),
      onErrorContainer: const Color(0xFFFCA5A5),
      surface: const Color(0xFF1A1A2E),
      onSurface: neutral100,
      surfaceContainerHighest: const Color(0xFF2D2D44),
      onSurfaceVariant: neutral300,
      outline: neutral600,
      outlineVariant: neutral700,
      shadow: Colors.black.withOpacity(0.3),
    );

    final primaryColor = colorScheme.primary;
    final extensions = DriveMateThemeExtension(
      primaryGradient: _gradientFromColor(primaryColor, isDark: true),
      heroGradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(primaryColor, Colors.black, 0.3) ?? primaryColor,
          primaryColor,
          const Color(0xFF212F45),
        ],
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      extensions: [extensions],
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0F0F1A),
      fontFamily: 'Inter',

      // AppBar Theme
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: Color(0xFF1A1A2E),
        surfaceTintColor: Colors.transparent,
        foregroundColor: neutral100,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: neutral100,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: neutral200),
      ),

      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        elevation: 0,
        backgroundColor: const Color(0xFF1A1A2E),
        selectedItemColor: primaryColor,
        unselectedItemColor: neutral500,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),

      // Navigation Bar Theme (Material 3)
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: const Color(0xFF1A1A2E),
        surfaceTintColor: Colors.transparent,
        indicatorColor: primaryColor.withOpacity(0.15),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: primaryColor, size: 24);
          }
          return IconThemeData(color: neutral500, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: primaryColor,
            );
          }
          return TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: neutral500,
          );
        }),
      ),

      // Tab Bar Theme
      tabBarTheme: TabBarThemeData(
        labelColor: primaryColor,
        unselectedLabelColor: neutral400,
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(width: 3, color: primaryColor),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
        ),
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
      ),

      // Card Theme
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: neutral700.withOpacity(0.5), width: 1),
        ),
        color: const Color(0xFF1A1A2E),
        surfaceTintColor: Colors.transparent,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2D2D44),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        isDense: false,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: neutral600, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: neutral600, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFFCA5A5), width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFFCA5A5), width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: neutral600, width: 1),
        ),
        labelStyle: TextStyle(color: neutral300, fontWeight: FontWeight.w500),
        hintStyle: TextStyle(color: neutral400),
        prefixIconColor: neutral300,
        suffixIconColor: neutral300,
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: primaryColor,
          foregroundColor: neutral900,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // Filled Button Theme
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: primaryLight,
          foregroundColor: neutral900,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: BorderSide(color: primaryColor, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Floating Action Button Theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 4,
        highlightElevation: 8,
        backgroundColor: primaryLight,
        foregroundColor: neutral900,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        extendedPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),

      // Chip Theme
      chipTheme: ChipThemeData(
        elevation: 0,
        backgroundColor: const Color(0xFF2D2D44),
        selectedColor: primaryColor.withOpacity(0.2),
        labelStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: neutral200,
        ),
        secondaryLabelStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: primaryLight,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        side: BorderSide.none,
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        elevation: 8,
        backgroundColor: const Color(0xFF1A1A2E),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: neutral100,
          letterSpacing: -0.3,
        ),
        contentTextStyle: TextStyle(
          fontSize: 15,
          color: neutral300,
          height: 1.5,
        ),
      ),

      // Bottom Sheet Theme
      bottomSheetTheme: const BottomSheetThemeData(
        elevation: 0,
        backgroundColor: Color(0xFF1A1A2E),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: true,
        dragHandleColor: neutral600,
        dragHandleSize: Size(40, 4),
      ),

      // Snackbar Theme
      snackBarTheme: SnackBarThemeData(
        elevation: 0,
        backgroundColor: neutral100,
        contentTextStyle: const TextStyle(
          color: neutral900,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.all(16),
      ),

      // List Tile Theme
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: neutral100,
        ),
        subtitleTextStyle: TextStyle(
          fontSize: 14,
          color: neutral400,
        ),
      ),

      // Divider Theme
      dividerTheme: DividerThemeData(
        color: neutral700.withOpacity(0.5),
        thickness: 1,
        space: 1,
      ),

      // Switch Theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return neutral900;
          }
          return neutral500;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor;
          }
          return neutral700;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),

      // Progress Indicator Theme
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primaryColor,
        linearTrackColor: neutral700,
        circularTrackColor: neutral700,
      ),

      // Icon Theme
      iconTheme: const IconThemeData(
        color: neutral300,
        size: 24,
      ),

      // Text Theme
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 57,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.25,
          color: neutral100,
        ),
        displayMedium: TextStyle(
          fontSize: 45,
          fontWeight: FontWeight.w400,
          color: neutral100,
        ),
        displaySmall: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w400,
          color: neutral100,
        ),
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
          color: neutral100,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
          color: neutral100,
        ),
        headlineSmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
          color: neutral100,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: neutral100,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
          color: neutral100,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
          color: neutral100,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.15,
          color: neutral200,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.25,
          color: neutral200,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.4,
          color: neutral300,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: neutral100,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
          color: neutral200,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
          color: neutral300,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CUSTOM EXTENSIONS
// ─────────────────────────────────────────────────────────────────────────────

extension ThemeExtensions on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colorScheme => theme.colorScheme;
  TextTheme get textTheme => theme.textTheme;
  bool get isDark => theme.brightness == Brightness.dark;

  /// Primary gradient derived from the current theme color
  LinearGradient get primaryGradient =>
      theme.extension<DriveMateThemeExtension>()?.primaryGradient ??
      AppTheme.primaryGradient;
}

// ─────────────────────────────────────────────────────────────────────────────
// SEMANTIC COLORS (theme-aware)
// Bug 1.10: Provides dark-mode-safe semantic colors
// ─────────────────────────────────────────────────────────────────────────────

extension SemanticColors on BuildContext {
  // Status colors that adapt to dark mode
  Color get successColor => isDark ? const Color(0xFF34D399) : AppTheme.success;
  Color get successBgColor => isDark ? const Color(0xFF064E3B) : AppTheme.successLight;
  Color get warningColor => isDark ? const Color(0xFFFBBF24) : AppTheme.warning;
  Color get warningBgColor => isDark ? const Color(0xFF78350F) : AppTheme.warningLight;
  Color get errorColor => isDark ? const Color(0xFFF87171) : AppTheme.error;
  Color get errorBgColor => isDark ? const Color(0xFF7F1D1D) : AppTheme.errorLight;
  Color get infoColor => isDark ? const Color(0xFF60A5FA) : AppTheme.info;
  Color get infoBgColor => isDark ? const Color(0xFF1E3A5F) : AppTheme.infoLight;

  // Neutral replacements
  Color get neutralBg => isDark ? const Color(0xFF1E1E2E) : AppTheme.neutral50;
  Color get neutralCard => isDark ? const Color(0xFF27272A) : AppTheme.neutral100;
  Color get neutralBorder => isDark ? const Color(0xFF3F3F46) : AppTheme.neutral200;
  Color get neutralSubtle => isDark ? const Color(0xFFA1A1AA) : AppTheme.neutral500;
  Color get neutralText => isDark ? const Color(0xFFE4E4E7) : AppTheme.neutral800;
}
