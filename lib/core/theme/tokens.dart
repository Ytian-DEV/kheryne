import 'package:flutter/widgets.dart';

/// Spacing scale: 4, 8, 12, 16, 20, 24, 32, 40.
abstract final class KSpace {
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s40 = 40;

  /// Side gutter on phones.
  static const double gutter = s16;
}

/// Radius scale: 8 small, 12 cards, 16 sheets, 24 hero, full pills.
abstract final class KRadius {
  static const double sm = 8;
  static const double card = 12;
  static const double sheet = 16;
  static const double hero = 24;
  static const double full = 999;

  /// Detection box corners (section 7 of the brief).
  static const double box = 6;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius cardAll = BorderRadius.all(Radius.circular(card));
  static const BorderRadius sheetAll = BorderRadius.all(Radius.circular(sheet));
  static const BorderRadius heroAll = BorderRadius.all(Radius.circular(hero));
  static const BorderRadius pill = BorderRadius.all(Radius.circular(full));
  static const BorderRadius sheetTop =
      BorderRadius.vertical(top: Radius.circular(sheet));
}

/// Sizes that are not spacing: hit targets, icon grid, hairline.
abstract final class KSize {
  static const double hit = 48; // Android 48 dp minimum, also used on Windows
  static const double iconSm = 16;
  static const double icon = 20;
  static const double iconLg = 24;
  static const double hairline = 0.5;
  static const double handle = 12;
  static const double boxStroke = 2;
}

/// Motion: 200 to 300 ms, ease-out and soft spring curves.
abstract final class KMotion {
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration base = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 300);

  static const Curve ease = Curves.easeOutCubic;

  /// Gentle spring with a hint of overshoot, used for sheets and box state
  /// changes.
  static const Curve spring = Cubic(0.2, 0.9, 0.3, 1.08);

  /// Returns [d], or zero when the user asked the OS to reduce motion.
  static Duration of(BuildContext context, Duration d) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false ? Duration.zero : d;
}
