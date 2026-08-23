import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Spacing tokens shared by every MediaForge Flutter feature.
abstract final class MfSpacing {
  /// Four logical pixels.
  static const double xxs = 4;

  /// Eight logical pixels.
  static const double xs = 8;

  /// Twelve logical pixels.
  static const double sm = 12;

  /// Sixteen logical pixels.
  static const double md = 16;

  /// Twenty logical pixels.
  static const double lg = 20;

  /// Twenty-four logical pixels.
  static const double xl = 24;

  /// Thirty-two logical pixels.
  static const double xxl = 32;
}

/// Radius tokens for controls and bounded surfaces.
abstract final class MfRadius {
  /// Compact control radius.
  static const double sm = 6;

  /// Standard control radius.
  static const double md = 8;

  /// Panel radius.
  static const double lg = 10;

  /// Prominent bounded surface radius.
  static const double xl = 12;
}

/// Motion durations reserved for M2 interactions.
abstract final class MfMotion {
  /// Direct feedback transition.
  static const Duration fast = Duration(milliseconds: 120);

  /// Standard state transition.
  static const Duration standard = Duration(milliseconds: 160);

  /// Emphasized state transition.
  static const Duration emphasized = Duration(milliseconds: 180);
}

/// Dark palette approved for the M1 visual prototype.
abstract final class MfPalette {
  /// Application background.
  static const Color background = Color(0xFF0B0D10);

  /// Primary panel surface.
  static const Color surface = Color(0xFF111419);

  /// Raised control surface.
  static const Color elevated = Color(0xFF171B21);

  /// Borders and inactive tracks.
  static const Color border = Color(0xFF252A32);

  /// Primary text.
  static const Color foreground = Color(0xFFF4F6F8);

  /// Secondary text.
  static const Color muted = Color(0xFFA2ABB8);

  /// Tertiary text and inactive metadata.
  static const Color faint = Color(0xFF707A88);

  /// Primary action and selected range.
  static const Color accent = Color(0xFF7C5CFC);

  /// Emphasized accent state.
  static const Color accentBright = Color(0xFF8D74FF);
}

/// shadcn_ui theme derived from MediaForge's dark palette.
abstract final class MfTheme {
  /// Dark desktop theme used by the M1 approval gate.
  static final ShadThemeData dark = ShadThemeData(
    brightness: Brightness.dark,
    radius: const BorderRadius.all(Radius.circular(MfRadius.md)),
    colorScheme: const ShadColorScheme(
      background: MfPalette.background,
      foreground: MfPalette.foreground,
      card: MfPalette.surface,
      cardForeground: MfPalette.foreground,
      popover: MfPalette.elevated,
      popoverForeground: MfPalette.foreground,
      primary: MfPalette.accent,
      primaryForeground: MfPalette.foreground,
      secondary: MfPalette.elevated,
      secondaryForeground: MfPalette.foreground,
      muted: MfPalette.elevated,
      mutedForeground: MfPalette.muted,
      accent: MfPalette.accentBright,
      accentForeground: MfPalette.foreground,
      destructive: MfPalette.accent,
      destructiveForeground: MfPalette.foreground,
      border: MfPalette.border,
      input: MfPalette.border,
      ring: MfPalette.accentBright,
      selection: MfPalette.accent,
    ),
  );
}
