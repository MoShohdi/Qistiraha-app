import 'package:flutter/material.dart';

/// ============================================================================
/// Qistiraha design system — single source of truth for the professional,
/// muted-SaaS look. Import this instead of hardcoding hex colors, paddings, or
/// radii. Desktop screens and the shared component library
/// (`lib/widgets/desktop/…`) build entirely on these tokens.
/// ============================================================================

/// Muted, cohesive SaaS palette: deep-slate primary/CTA, one restrained blue
/// accent, soft neutral surfaces, subtle borders, and desaturated semantics so
/// charts and primary buttons are what "pop".
abstract final class AppColors {
  // Brand / primary — deep slate charcoal. Primary CTAs and key accents.
  static const Color ink = Color(0xFF1E2337);
  static const Color inkSoft = Color(0xFF2C3350);

  // Accent — one restrained blue, used sparingly (links, selection, charts).
  static const Color accent = Color(0xFF5A75AD);
  static const Color accentSoft = Color(0xFF99AFD7); // tints / chart fills
  static const Color accentWash = Color(0xFFEEF2F8); // faint selected/hover bg

  // Neutral surfaces.
  static const Color background = Color(0xFFF7F8FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFFAFBFC);

  // Borders / dividers — subtle.
  static const Color border = Color(0xFFE6E8EC);
  static const Color borderStrong = Color(0xFFD5DAE1);

  // Text.
  static const Color textPrimary = Color(0xFF1E2337);
  static const Color textSecondary = Color(0xFF5B6472);
  static const Color textTertiary = Color(0xFF8A94A6);

  // Semantics — desaturated, not neon.
  static const Color success = Color(0xFF2E9E6B);
  static const Color successWash = Color(0xFFEAF6F0);
  static const Color warning = Color(0xFFC98A2B);
  static const Color warningWash = Color(0xFFFBF3E6);
  static const Color danger = Color(0xFFD35B5B);
  static const Color dangerWash = Color(0xFFFBEEEE);

  /// Ordered categorical series for charts — all pulled from the palette so
  /// visualizations read as one system.
  static const List<Color> chartSeries = [
    accent,
    ink,
    success,
    warning,
    Color(0xFF7E8AA8),
  ];
}

/// 4-pt spacing scale. Use these instead of ad-hoc EdgeInsets numbers.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  static const EdgeInsets cardPadding = EdgeInsets.all(lg);
  static const EdgeInsets pagePadding = EdgeInsets.all(xxl);
}

/// Corner radii. Desktop leans on the crisp 8–12 range.
abstract final class AppRadii {
  static const double sm = 8;
  static const double md = 10;
  static const double lg = 14;
  static const double pill = 999;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
}

/// Soft, diffuse elevation — desktop cards should lift, not shout.
abstract final class AppShadows {
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x0F000000), // ~6% black
      blurRadius: 18,
      offset: Offset(0, 6),
    ),
  ];

  static const List<BoxShadow> raised = [
    BoxShadow(
      color: Color(0x1A000000), // ~10% black
      blurRadius: 24,
      offset: Offset(0, 10),
    ),
  ];
}

/// The assembled [ThemeData]. Wired once in `main.dart`; refines default
/// Material widgets (buttons, cards, dialogs, inputs, chips, popovers) toward
/// the SaaS language without disrupting the existing mobile layouts.
abstract final class AppTheme {
  static ThemeData get light {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.accent,
          primary: AppColors.ink,
          secondary: AppColors.accent,
          surface: AppColors.surface,
          error: AppColors.danger,
        ).copyWith(
          onPrimary: Colors.white,
          onSurface: AppColors.textPrimary,
        );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      dividerColor: AppColors.border,
      splashFactory: InkRipple.splashFactory,
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.lgAll,
          side: const BorderSide(color: AppColors.border),
        ),
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.lgAll),
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surface,
        elevation: 3,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.mdAll,
          side: const BorderSide(color: AppColors.border),
        ),
        textStyle: const TextStyle(
          fontSize: 13.5,
          color: AppColors.textPrimary,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.ink,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: AppRadii.smAll),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.borderStrong),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: AppRadii.smAll),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        hintStyle: const TextStyle(color: AppColors.textTertiary),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        border: OutlineInputBorder(
          borderRadius: AppRadii.smAll,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.smAll,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.smAll,
          borderSide: const BorderSide(color: AppColors.accent, width: 1.6),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.ink,
        side: const BorderSide(color: AppColors.borderStrong),
        labelStyle: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
        secondaryLabelStyle: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
      ),
      tabBarTheme: const TabBarThemeData(
        indicatorColor: AppColors.accent,
        labelColor: AppColors.textPrimary,
        unselectedLabelColor: AppColors.textTertiary,
        labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        dividerColor: AppColors.border,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.ink,
        unselectedItemColor: AppColors.textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13.5),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.smAll),
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base) {
    TextStyle p(TextStyle? s, double size, FontWeight w, {Color? c}) =>
        (s ?? const TextStyle()).copyWith(
          fontSize: size,
          fontWeight: w,
          color: c ?? AppColors.textPrimary,
          height: 1.3,
        );
    return base.copyWith(
      headlineSmall: p(base.headlineSmall, 22, FontWeight.w700),
      titleLarge: p(base.titleLarge, 18, FontWeight.w700),
      titleMedium: p(base.titleMedium, 14.5, FontWeight.w700),
      bodyLarge: p(base.bodyLarge, 14, FontWeight.w500),
      bodyMedium: p(base.bodyMedium, 13, FontWeight.w500, c: AppColors.textSecondary),
      labelLarge: p(base.labelLarge, 13, FontWeight.w600),
      labelSmall: p(base.labelSmall, 11, FontWeight.w600, c: AppColors.textTertiary),
    );
  }
}
