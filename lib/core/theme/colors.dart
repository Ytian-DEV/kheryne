import 'package:flutter/material.dart';

/// Kheryne colour tokens. The only place in the app where hex values live.
///
/// Read them with `context.k` (see `theme_ext.dart`).
@immutable
class KheryneColors extends ThemeExtension<KheryneColors> {
  const KheryneColors({
    required this.primary,
    required this.primaryStrong,
    required this.accent,
    required this.container,
    required this.background,
    required this.surface,
    required this.text,
    required this.textSecondary,
    required this.success,
    required this.warning,
    required this.error,
    required this.userBox,
    required this.notNematode,
    required this.separator,
    required this.onPrimary,
    required this.onStatus,
    required this.scrim,
    required this.canvas,
    required this.overlayText,
  });

  final Color primary;
  final Color primaryStrong;
  final Color accent;
  final Color container;
  final Color background;
  final Color surface;
  final Color text;
  final Color textSecondary;
  final Color success;
  final Color warning;
  final Color error;
  final Color userBox;
  final Color notNematode;
  final Color separator;

  /// Text and icons on [primary]. White on #C2185B is 5.9:1; dark mode uses
  /// the dark text colour on #F48FB1 because white there is only 2.0:1.
  final Color onPrimary;

  /// Text and icons on solid status fills (box labels, badges).
  final Color onStatus;

  /// Dim layer behind sheets and floating bars over images.
  final Color scrim;

  /// Backdrop behind micrographs (canvas, live view).
  final Color canvas;

  /// Text drawn directly over images or the dark canvas.
  final Color overlayText;

  static const light = KheryneColors(
    primary: Color(0xFFC2185B),
    primaryStrong: Color(0xFF880E4F),
    accent: Color(0xFFF06292),
    container: Color(0xFFFCE4EC),
    background: Color(0xFFFFF5F8),
    surface: Color(0xFFFFFFFF),
    text: Color(0xFF2D1B24),
    textSecondary: Color(0xFF6E5A64),
    success: Color(0xFF2E7D5B),
    warning: Color(0xFFB7791F),
    error: Color(0xFFB3261E),
    userBox: Color(0xFF7C4DFF),
    notNematode: Color(0xFFD32F2F),
    separator: Color(0x14000000), // #000000 @ 8%
    onPrimary: Color(0xFFFFFFFF),
    onStatus: Color(0xFFFFFFFF),
    scrim: Color(0x99140C10),
    canvas: Color(0xFF0E0A0C),
    overlayText: Color(0xFFF5E9EE),
  );

  static const dark = KheryneColors(
    primary: Color(0xFFF48FB1),
    primaryStrong: Color(0xFFF8BBD0),
    accent: Color(0xFFF06292),
    container: Color(0xFF4A1F33),
    background: Color(0xFF1C1418),
    surface: Color(0xFF2A1F24),
    text: Color(0xFFF5E9EE),
    textSecondary: Color(0xFFBFAAB4),
    success: Color(0xFF6FCF97),
    warning: Color(0xFFF2C94C),
    error: Color(0xFFF28B82),
    userBox: Color(0xFFB39DDB),
    notNematode: Color(0xFFEF5350),
    separator: Color(0x1AFFFFFF), // #FFFFFF @ 10%
    onPrimary: Color(0xFF2D1B24),
    onStatus: Color(0xFF1C1418),
    scrim: Color(0xB30A0608),
    canvas: Color(0xFF0B0809),
    overlayText: Color(0xFFF5E9EE),
  );

  @override
  KheryneColors copyWith({
    Color? primary,
    Color? primaryStrong,
    Color? accent,
    Color? container,
    Color? background,
    Color? surface,
    Color? text,
    Color? textSecondary,
    Color? success,
    Color? warning,
    Color? error,
    Color? userBox,
    Color? notNematode,
    Color? separator,
    Color? onPrimary,
    Color? onStatus,
    Color? scrim,
    Color? canvas,
    Color? overlayText,
  }) {
    return KheryneColors(
      primary: primary ?? this.primary,
      primaryStrong: primaryStrong ?? this.primaryStrong,
      accent: accent ?? this.accent,
      container: container ?? this.container,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      text: text ?? this.text,
      textSecondary: textSecondary ?? this.textSecondary,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      userBox: userBox ?? this.userBox,
      notNematode: notNematode ?? this.notNematode,
      separator: separator ?? this.separator,
      onPrimary: onPrimary ?? this.onPrimary,
      onStatus: onStatus ?? this.onStatus,
      scrim: scrim ?? this.scrim,
      canvas: canvas ?? this.canvas,
      overlayText: overlayText ?? this.overlayText,
    );
  }

  @override
  KheryneColors lerp(ThemeExtension<KheryneColors>? other, double t) {
    if (other is! KheryneColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return KheryneColors(
      primary: l(primary, other.primary),
      primaryStrong: l(primaryStrong, other.primaryStrong),
      accent: l(accent, other.accent),
      container: l(container, other.container),
      background: l(background, other.background),
      surface: l(surface, other.surface),
      text: l(text, other.text),
      textSecondary: l(textSecondary, other.textSecondary),
      success: l(success, other.success),
      warning: l(warning, other.warning),
      error: l(error, other.error),
      userBox: l(userBox, other.userBox),
      notNematode: l(notNematode, other.notNematode),
      separator: l(separator, other.separator),
      onPrimary: l(onPrimary, other.onPrimary),
      onStatus: l(onStatus, other.onStatus),
      scrim: l(scrim, other.scrim),
      canvas: l(canvas, other.canvas),
      overlayText: l(overlayText, other.overlayText),
    );
  }
}

/// Fixed colours for the mock micrograph renderer. These describe the
/// physical look of a brightfield slide, not UI chrome, so they are not
/// themeable and they never appear on controls.
abstract final class MicrographPalette {
  static const field = Color(0xFFF2EBDA);
  static const fieldMid = Color(0xFFDCCDB0);
  static const fieldEdge = Color(0xFF8C7B62);
  static const outside = Color(0xFF0A0708);
  static const body = Color(0xFF7F6B52);
  static const bodyHighlight = Color(0xFFDCCFB4);
  static const debris = Color(0xFF6B5946);
  static const lineArt = Color(0xFF5A4652);
}

/// Text colour with the best contrast on a solid status fill (box labels,
/// badges): the dark text token or white, whichever reads better.
Color onFill(Color fill) {
  final dark = KheryneColors.light.text;
  final light = KheryneColors.light.surface;
  double ratio(Color a, Color b) {
    final la = a.computeLuminance(), lb = b.computeLuminance();
    return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
  }

  return ratio(fill, dark) >= ratio(fill, light) ? dark : light;
}
