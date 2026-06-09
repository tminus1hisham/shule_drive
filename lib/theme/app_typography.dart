import 'package:flutter/material.dart';

/// Builds the app-wide [TextTheme].
///
/// - Body / UI text uses **Inter** ([fontFamily]).
/// - Large display + headline text uses **Plus Jakarta Sans** ([displayFamily])
///   for a friendlier, more modern feel.
///
/// Both are bundled variable fonts (see pubspec.yaml); Flutter maps [FontWeight]
/// onto the `wght` axis, so every weight resolves from the single asset.
class AppTypography {
  AppTypography._();

  static const String fontFamily = 'Inter';
  static const String displayFamily = 'PlusJakartaSans';

  /// [primary] is used for headings / body, [secondary] for muted captions.
  static TextTheme textTheme(Color primary, Color secondary) {
    TextStyle display(double size, FontWeight weight, double spacing) =>
        TextStyle(
          fontFamily: displayFamily,
          fontSize: size,
          fontWeight: weight,
          height: 1.2,
          letterSpacing: spacing,
          color: primary,
        );

    TextStyle ui(
      double size,
      FontWeight weight, {
      double height = 1.4,
      Color? color,
      double spacing = 0,
    }) => TextStyle(
      fontFamily: fontFamily,
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: spacing,
      color: color ?? primary,
    );

    return TextTheme(
      // Display / headlines — Plus Jakarta Sans
      displayLarge: display(40, FontWeight.w700, -1.0),
      displayMedium: display(32, FontWeight.w700, -0.8),
      displaySmall: display(28, FontWeight.w700, -0.5),
      headlineMedium: display(24, FontWeight.w700, -0.3),
      headlineSmall: display(20, FontWeight.w700, -0.2),
      titleLarge: display(20, FontWeight.w700, -0.2),

      // Titles / labels / body — Inter
      titleMedium: ui(16, FontWeight.w600, height: 1.3),
      titleSmall: ui(14, FontWeight.w600, height: 1.3),
      bodyLarge: ui(16, FontWeight.w400),
      bodyMedium: ui(14, FontWeight.w400),
      bodySmall: ui(12, FontWeight.w400, color: secondary),
      labelLarge: ui(14, FontWeight.w600, height: 1.2),
      labelMedium: ui(12, FontWeight.w500, height: 1.2),
      labelSmall: ui(11, FontWeight.w500, height: 1.2, color: secondary),
    );
  }
}
