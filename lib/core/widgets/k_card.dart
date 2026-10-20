import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'pressable.dart';

/// Surface card: 12 px radius, hairline border, no drop shadow.
class KCard extends StatelessWidget {
  const KCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(KSpace.s16),
    this.onTap,
    this.onSecondaryTapDown,
    this.radius = KRadius.card,
    this.color,
    this.semanticLabel,
    this.clip = false,
    this.border = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final void Function(TapDownDetails)? onSecondaryTapDown;
  final double radius;
  final Color? color;
  final String? semanticLabel;
  final bool clip;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final br = BorderRadius.circular(radius);
    Widget card = DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? k.surface,
        borderRadius: br,
        border: border ? Border.all(color: k.separator, width: 1) : null,
      ),
      child: clip ? ClipRRect(borderRadius: br, child: Padding(padding: padding, child: child)) : Padding(padding: padding, child: child),
    );
    if (onTap != null || onSecondaryTapDown != null) {
      card = Pressable(
        onTap: onTap,
        onSecondaryTapDown: onSecondaryTapDown,
        borderRadius: br,
        semanticLabel: semanticLabel,
        child: card,
      );
    }
    return card;
  }
}
