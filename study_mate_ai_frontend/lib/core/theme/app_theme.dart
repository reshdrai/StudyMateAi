// import 'package:flutter/material.dart';
// import 'app_colors.dart';

// class AppTheme {
//   static ThemeData light() {
//     final colorScheme = ColorScheme(
//       brightness: Brightness.light,
//       primary: AppColors.primary,
//       onPrimary: Colors.white,
//       secondary: AppColors.surfaceSoft,
//       onSecondary: AppColors.textPrimary,
//       error: AppColors.error,
//       onError: Colors.white,
//       surface: AppColors.surface,
//       onSurface: AppColors.textPrimary,
//     );

//     return ThemeData(
//       useMaterial3: true,
//       colorScheme: colorScheme,
//       scaffoldBackgroundColor: AppColors.background,
//       fontFamily: 'Poppins', // optional: remove if you don’t use custom font
//       appBarTheme: const AppBarTheme(
//         backgroundColor: AppColors.background,
//         elevation: 0,
//         centerTitle: true,
//         foregroundColor: AppColors.textPrimary,
//       ),
//       inputDecorationTheme: InputDecorationTheme(
//         filled: true,
//         fillColor: AppColors.surface,
//         hintStyle: const TextStyle(color: AppColors.textSecondary),
//         labelStyle: const TextStyle(color: AppColors.textSecondary),
//         enabledBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(14),
//           borderSide: const BorderSide(color: AppColors.outline),
//         ),
//         focusedBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(14),
//           borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
//         ),
//       ),
//       elevatedButtonTheme: ElevatedButtonThemeData(
//         style: ElevatedButton.styleFrom(
//           backgroundColor: AppColors.primary,
//           foregroundColor: Colors.white,
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(14),
//           ),
//           padding: const EdgeInsets.symmetric(vertical: 16),
//           textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
//         ),
//       ),
//       textButtonTheme: TextButtonThemeData(
//         style: TextButton.styleFrom(
//           foregroundColor: AppColors.primary,
//           textStyle: const TextStyle(fontWeight: FontWeight.w600),
//         ),
//       ),
//       dividerColor: AppColors.divider,
//     );
//   }
// }
import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  // ── Light — identical to original ──────────────────────────────────
  static ThemeData light() {
    const background = AppColors.background; // #F7F5FB
    const surface = AppColors.surface; // #FFFFFF
    const surfaceSoft = AppColors.surfaceSoft; // #F0ECFA
    const textPrimary = AppColors.textPrimary; // #1C1B1F
    const textSecondary = AppColors.textSecondary; // #6B6676
    const outline = AppColors.outline; // #DDD7EE

    return _build(
      brightness: Brightness.light,
      background: background,
      surface: surface,
      surfaceSoft: surfaceSoft,
      textPrimary: textPrimary,
      textSecondary: textSecondary,
      outline: outline,
      cardColor: surface,
    );
  }

  // ── Dark — deep purple-tinted blacks that complement the brand ──────
  // Logic: keep AppColors.primary (#6C4CD2) as accent.
  // Backgrounds shift to very dark purple-grey so cards feel consistent.
  static ThemeData dark() {
    const background = Color(0xFF12101A); // near-black, warm purple tint
    const surface = Color(
      0xFF1C1828,
    ); // dark card — same purple tint, slightly lighter
    const surfaceSoft = Color(0xFF261F38); // chip / soft bg
    const textPrimary = Color(0xFFEDE8FF); // off-white with purple warmth
    const textSecondary = Color(0xFF9B92C4); // muted purple-grey
    const outline = Color(0xFF342D4F); // subtle border

    return _build(
      brightness: Brightness.dark,
      background: background,
      surface: surface,
      surfaceSoft: surfaceSoft,
      textPrimary: textPrimary,
      textSecondary: textSecondary,
      outline: outline,
      cardColor: surface,
    );
  }

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color surfaceSoft,
    required Color textPrimary,
    required Color textSecondary,
    required Color outline,
    required Color cardColor,
  }) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: surfaceSoft,
      onSecondary: textPrimary,
      error: AppColors.error,
      onError: Colors.white,
      surface: surface,
      onSurface: textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      cardColor: cardColor,
      dividerColor: outline,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: true,
        foregroundColor: textPrimary,
        surfaceTintColor: Colors.transparent,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: textSecondary,
        elevation: 8,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: TextStyle(color: textSecondary),
        labelStyle: TextStyle(color: textSecondary),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.primary
              : Colors.grey,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.primary.withOpacity(0.4)
              : outline,
        ),
      ),
    );
  }
}
