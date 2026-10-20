import 'package:flutter/material.dart';

import 'colors.dart';
import 'typography.dart';

extension KheryneThemeX on BuildContext {
  /// Colour tokens.
  KheryneColors get k => Theme.of(this).extension<KheryneColors>()!;

  /// Type scale.
  KType get t => Theme.of(this).extension<KType>()!;

  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
