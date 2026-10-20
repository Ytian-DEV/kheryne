import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'pressable.dart';

enum KButtonVariant { primary, secondary, tertiary, destructive, overlay }

enum KButtonSize { regular, compact }

/// Buttons. One primary per screen; verbs in sentence case.
class KButton extends StatelessWidget {
  const KButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = KButtonVariant.primary,
    this.size = KButtonSize.regular,
    this.icon,
    this.expand = false,
    this.loading = false,
    this.semanticLabel,
    this.tooltip,
  });

  const KButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = KButtonSize.regular,
    this.icon,
    this.expand = false,
    this.loading = false,
    this.semanticLabel,
    this.tooltip,
  }) : variant = KButtonVariant.secondary;

  const KButton.tertiary({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = KButtonSize.regular,
    this.icon,
    this.expand = false,
    this.loading = false,
    this.semanticLabel,
    this.tooltip,
  }) : variant = KButtonVariant.tertiary;

  final String label;
  final VoidCallback? onPressed;
  final KButtonVariant variant;
  final KButtonSize size;
  final IconData? icon;
  final bool expand;
  final bool loading;
  final String? semanticLabel;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final t = context.t;
    final enabled = onPressed != null && !loading;
    final (Color bg, Color fg) = switch (variant) {
      KButtonVariant.primary => (k.primary, k.onPrimary),
      KButtonVariant.secondary => (k.container, context.isDark ? k.primaryStrong : k.primaryStrong),
      KButtonVariant.tertiary => (Colors.transparent, k.primary),
      KButtonVariant.destructive => (Colors.transparent, k.error),
      KButtonVariant.overlay => (k.overlayText.withValues(alpha: 0.14), k.overlayText),
    };
    final compact = size == KButtonSize.compact;
    final height = compact ? 40.0 : KSize.hit;
    final style = (compact ? t.subhead : t.headline).copyWith(color: fg);

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox.square(
            dimension: KSize.iconSm,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg, backgroundColor: Colors.transparent),
          )
        else if (icon != null)
          Icon(icon, size: compact ? KSize.iconSm + 2 : KSize.icon, color: fg),
        if (loading || icon != null) const SizedBox(width: KSpace.s8),
        Flexible(child: Text(label, style: style, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis)),
      ],
    );

    return Opacity(
      opacity: enabled || loading ? 1 : 0.4,
      child: Pressable(
        onTap: enabled ? onPressed : null,
        semanticLabel: semanticLabel ?? label,
        tooltip: tooltip,
        borderRadius: KRadius.cardAll,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: height, minWidth: compact ? 64 : 88),
          child: DecoratedBox(
            decoration: BoxDecoration(color: bg, borderRadius: KRadius.cardAll),
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: variant == KButtonVariant.tertiary ? KSpace.s12 : (compact ? KSpace.s12 : KSpace.s20),
                  vertical: compact ? KSpace.s8 : KSpace.s12),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

/// Icon-only button with a 48 px hit area and a required semantic label.
class KIconButton extends StatelessWidget {
  const KIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
    this.background,
    this.size = KSize.iconLg,
    this.selected = false,
    this.dimension = KSize.hit,
  }) : overlay = false;

  /// Translucent circular button for controls floating over images.
  const KIconButton.overlay({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.size = 22,
    this.selected = false,
    this.dimension = 44,
  })  : color = null,
        background = null,
        overlay = true;

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final Color? background;
  final double size;
  final bool selected;
  final double dimension;

  /// Translucent style for controls over images.
  final bool overlay;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final isOverlay = overlay;
    final fg = isOverlay ? (selected ? k.canvas : k.overlayText) : (color ?? k.text);
    final bg = isOverlay
        ? (selected ? k.overlayText : k.overlayText.withValues(alpha: 0.14))
        : (selected ? k.container : background ?? Colors.transparent);
    final radius = BorderRadius.circular(isOverlay ? KRadius.full : KRadius.sm);
    return Pressable(
      onTap: onPressed,
      semanticLabel: label,
      tooltip: label,
      selected: selected,
      borderRadius: radius,
      pressScale: 0.94,
      child: SizedBox.square(
        dimension: dimension,
        child: DecoratedBox(
          decoration: BoxDecoration(color: bg, borderRadius: radius),
          child: Center(child: Icon(icon, size: size, color: onPressed == null ? fg.withValues(alpha: 0.4) : fg)),
        ),
      ),
    );
  }
}
