import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Phone layout (bottom tabs) or desktop layout (sidebar + inspector).
///
/// Decided by platform, not width: Windows is always desktop (min window
/// 1024×700); Android is always phone. Tests and the screen gallery
/// override it with [FormFactorScope].
@immutable
class FormFactor {
  const FormFactor({required this.isDesktop});

  final bool isDesktop;
  bool get isPhone => !isDesktop;

  /// Take Photo exists only where a camera sits on the eyepiece.
  bool get canTakePhoto => !isDesktop;

  static FormFactor fromPlatform() => FormFactor(
        isDesktop: !kIsWeb &&
            (defaultTargetPlatform == TargetPlatform.windows ||
                defaultTargetPlatform == TargetPlatform.macOS ||
                defaultTargetPlatform == TargetPlatform.linux),
      );

  static FormFactor of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FormFactorScope>()?.value ?? fromPlatform();

  @override
  bool operator ==(Object other) => other is FormFactor && other.isDesktop == isDesktop;

  @override
  int get hashCode => isDesktop.hashCode;
}

class FormFactorScope extends InheritedWidget {
  const FormFactorScope({super.key, required this.value, required super.child});
  final FormFactor value;

  @override
  bool updateShouldNotify(FormFactorScope oldWidget) => oldWidget.value != value;
}

/// Desktop sidebar collapses to icons below this width.
const double kSidebarCollapseWidth = 1200;
