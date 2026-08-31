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
abstract final class MfDarkPalette {
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

/// Light palette fixed by the Flutter migration plan.
abstract final class MfLightPalette {
  /// Application background.
  static const Color background = Color(0xFFF7F8FA);

  /// Primary panel surface.
  static const Color surface = Color(0xFFFFFFFF);

  /// Raised control surface.
  static const Color elevated = Color(0xFFF1F3F5);

  /// Borders and inactive tracks.
  static const Color border = Color(0xFFDDE1E7);

  /// Primary text.
  static const Color foreground = Color(0xFF161A20);

  /// Secondary text.
  static const Color muted = Color(0xFF596273);

  /// Tertiary text and inactive metadata.
  static const Color faint = Color(0xFF7B8492);

  /// Primary action and selected range.
  static const Color accent = Color(0xFF6D4AFF);

  /// Emphasized accent state.
  static const Color accentBright = Color(0xFF5C3CE6);
}

/// Active semantic colors selected by the Flutter composition root.
abstract final class MfPalette {
  static bool _light = false;

  /// Selects the semantic palette before the presentation subtree is built.
  static void activate(Brightness brightness) {
    _light = brightness == Brightness.light;
  }

  /// Application background.
  static Color get background =>
      _light ? MfLightPalette.background : MfDarkPalette.background;

  /// Primary panel surface.
  static Color get surface =>
      _light ? MfLightPalette.surface : MfDarkPalette.surface;

  /// Raised control surface.
  static Color get elevated =>
      _light ? MfLightPalette.elevated : MfDarkPalette.elevated;

  /// Borders and inactive tracks.
  static Color get border =>
      _light ? MfLightPalette.border : MfDarkPalette.border;

  /// Primary text.
  static Color get foreground =>
      _light ? MfLightPalette.foreground : MfDarkPalette.foreground;

  /// Secondary text.
  static Color get muted => _light ? MfLightPalette.muted : MfDarkPalette.muted;

  /// Tertiary text and inactive metadata.
  static Color get faint => _light ? MfLightPalette.faint : MfDarkPalette.faint;

  /// Primary action and selected range.
  static Color get accent =>
      _light ? MfLightPalette.accent : MfDarkPalette.accent;

  /// Emphasized accent state.
  static Color get accentBright =>
      _light ? MfLightPalette.accentBright : MfDarkPalette.accentBright;
}

/// shadcn_ui theme derived from MediaForge's dark palette.
abstract final class MfTheme {
  /// Light desktop theme fixed by the M10 migration contract.
  static final ShadThemeData light = ShadThemeData(
    brightness: Brightness.light,
    radius: const BorderRadius.all(Radius.circular(MfRadius.md)),
    colorScheme: const ShadColorScheme(
      background: MfLightPalette.background,
      foreground: MfLightPalette.foreground,
      card: MfLightPalette.surface,
      cardForeground: MfLightPalette.foreground,
      popover: MfLightPalette.elevated,
      popoverForeground: MfLightPalette.foreground,
      primary: MfLightPalette.accent,
      primaryForeground: Color(0xFFFFFFFF),
      secondary: MfLightPalette.elevated,
      secondaryForeground: MfLightPalette.foreground,
      muted: MfLightPalette.elevated,
      mutedForeground: MfLightPalette.muted,
      accent: MfLightPalette.accentBright,
      accentForeground: Color(0xFFFFFFFF),
      destructive: MfLightPalette.accent,
      destructiveForeground: Color(0xFFFFFFFF),
      border: MfLightPalette.border,
      input: MfLightPalette.border,
      ring: MfLightPalette.accentBright,
      selection: MfLightPalette.accent,
    ),
  );

  /// Dark desktop theme used by the M1 approval gate.
  static final ShadThemeData dark = ShadThemeData(
    brightness: Brightness.dark,
    radius: const BorderRadius.all(Radius.circular(MfRadius.md)),
    colorScheme: const ShadColorScheme(
      background: MfDarkPalette.background,
      foreground: MfDarkPalette.foreground,
      card: MfDarkPalette.surface,
      cardForeground: MfDarkPalette.foreground,
      popover: MfDarkPalette.elevated,
      popoverForeground: MfDarkPalette.foreground,
      primary: MfDarkPalette.accent,
      primaryForeground: MfDarkPalette.foreground,
      secondary: MfDarkPalette.elevated,
      secondaryForeground: MfDarkPalette.foreground,
      muted: MfDarkPalette.elevated,
      mutedForeground: MfDarkPalette.muted,
      accent: MfDarkPalette.accentBright,
      accentForeground: MfDarkPalette.foreground,
      destructive: MfDarkPalette.accent,
      destructiveForeground: MfDarkPalette.foreground,
      border: MfDarkPalette.border,
      input: MfDarkPalette.border,
      ring: MfDarkPalette.accentBright,
      selection: MfDarkPalette.accent,
    ),
  );
}
