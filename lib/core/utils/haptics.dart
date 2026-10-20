import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Light haptic on Android; a no-op on desktop.
abstract final class Haptics {
  static bool get _supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static void light() {
    if (_supported) HapticFeedback.lightImpact();
  }

  static void selection() {
    if (_supported) HapticFeedback.selectionClick();
  }

  static void success() {
    if (_supported) HapticFeedback.mediumImpact();
  }
}
