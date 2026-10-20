import 'package:flutter/material.dart';

/// Type scale: 34 large title, 28, 22, 17 body, 15, 13 caption, 11 micro.
///
/// Inter for everything; Inter Display (same family, optical size for large
/// text) for 22 px and up so big titles stay tight without manual tracking.
@immutable
class KType extends ThemeExtension<KType> {
  const KType._(this.color, this.secondary);

  factory KType.of(Color color, Color secondary) => KType._(color, secondary);

  final Color color;
  final Color secondary;

  static const String body = 'Inter';
  static const String display = 'InterDisplay';

  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  TextStyle get largeTitle => TextStyle(
      fontFamily: display, fontSize: 34, height: 41 / 34, fontWeight: FontWeight.w600, letterSpacing: -0.4, color: color);
  TextStyle get title1 => TextStyle(
      fontFamily: display, fontSize: 28, height: 34 / 28, fontWeight: FontWeight.w600, letterSpacing: -0.3, color: color);
  TextStyle get title2 => TextStyle(
      fontFamily: display, fontSize: 22, height: 28 / 22, fontWeight: FontWeight.w600, letterSpacing: -0.2, color: color);
  TextStyle get headline => TextStyle(
      fontFamily: body, fontSize: 17, height: 22 / 17, fontWeight: FontWeight.w600, letterSpacing: -0.2, color: color);
  TextStyle get bodyStyle => TextStyle(
      fontFamily: body, fontSize: 17, height: 24 / 17, fontWeight: FontWeight.w400, letterSpacing: -0.2, color: color);
  TextStyle get callout => TextStyle(
      fontFamily: body, fontSize: 15, height: 21 / 15, fontWeight: FontWeight.w400, letterSpacing: -0.1, color: color);
  TextStyle get calloutStrong => callout.copyWith(fontWeight: FontWeight.w600);
  TextStyle get subhead => TextStyle(
      fontFamily: body, fontSize: 15, height: 20 / 15, fontWeight: FontWeight.w500, color: color);
  TextStyle get caption => TextStyle(
      fontFamily: body, fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w400, color: secondary);
  TextStyle get captionStrong =>
      caption.copyWith(fontWeight: FontWeight.w500);
  TextStyle get micro => TextStyle(
      fontFamily: body, fontSize: 11, height: 14 / 11, fontWeight: FontWeight.w500, letterSpacing: 0.1, color: secondary);

  /// Section header above inset grouped lists.
  TextStyle get sectionHeader => TextStyle(
      fontFamily: body, fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w500, letterSpacing: 0.1, color: secondary);

  /// Numbers in tables and measurements.
  TextStyle get numeric => callout.copyWith(fontFeatures: tabular);

  @override
  KType copyWith({Color? color, Color? secondary}) =>
      KType._(color ?? this.color, secondary ?? this.secondary);

  @override
  KType lerp(ThemeExtension<KType>? other, double t) {
    if (other is! KType) return this;
    return KType._(Color.lerp(color, other.color, t)!,
        Color.lerp(secondary, other.secondary, t)!);
  }
}
