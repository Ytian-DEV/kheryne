import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'k_button.dart';
import 'k_icons.dart';
import 'illustrations.dart';
import 'pressable.dart';

/// Toggle chip for region overlays, filters and quick choices.
class TraitChip extends StatelessWidget {
  const TraitChip({super.key, required this.label, this.selected = false, this.onTap, this.color, this.icon});

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final t = context.t;
    final c = color ?? k.primaryStrong;
    return Pressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: label,
      borderRadius: KRadius.pill,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 36),
        child: AnimatedContainer(
          duration: KMotion.of(context, KMotion.fast),
          padding: const EdgeInsets.symmetric(horizontal: KSpace.s12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? (color == null ? k.container : c.withValues(alpha: 0.16)) : k.surface,
            borderRadius: KRadius.pill,
            border: Border.all(color: selected ? Colors.transparent : k.separator),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected || icon != null) ...[
                Icon(selected ? KIcons.check : icon, size: 14, color: selected ? c : k.textSecondary),
                const SizedBox(width: KSpace.s4),
              ],
              Text(label, style: t.captionStrong.copyWith(color: selected ? (color == null ? k.primaryStrong : k.text) : k.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

enum BannerTone { warning, error, info, success }

/// Inline guidance or status banner: tone colour + icon + text, never colour
/// alone.
class StatusBanner extends StatelessWidget {
  const StatusBanner({
    super.key,
    required this.title,
    this.message,
    this.tone = BannerTone.warning,
    this.icon,
    this.action,
    this.onAction,
    this.onDark = false,
  });

  final String title;
  final String? message;
  final BannerTone tone;
  final IconData? icon;
  final String? action;
  final VoidCallback? onAction;

  /// Over images or the dark camera view.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final t = context.t;
    final c = switch (tone) {
      BannerTone.warning => k.warning,
      BannerTone.error => k.error,
      BannerTone.info => k.textSecondary,
      BannerTone.success => k.success,
    };
    final ic = icon ??
        switch (tone) {
          BannerTone.warning => KIcons.warning,
          BannerTone.error => KIcons.xCircle,
          BannerTone.info => KIcons.info,
          BannerTone.success => KIcons.checkCircle,
        };
    final fg = onDark ? k.overlayText : k.text;
    return Semantics(
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: onDark ? k.canvas.withValues(alpha: 0.78) : c.withValues(alpha: context.isDark ? 0.14 : 0.09),
          borderRadius: KRadius.cardAll,
          border: Border.all(color: c.withValues(alpha: onDark ? 0.7 : 0.35)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(KSpace.s12, KSpace.s12, KSpace.s12, KSpace.s12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(padding: const EdgeInsets.only(top: 1), child: Icon(ic, size: KSize.icon, color: c)),
              const SizedBox(width: KSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: t.calloutStrong.copyWith(color: fg)),
                    if (message != null) ...[
                      const SizedBox(height: 2),
                      Text(message!, style: t.caption.copyWith(color: onDark ? k.overlayText.withValues(alpha: 0.75) : k.textSecondary)),
                    ],
                  ],
                ),
              ),
              if (action != null) ...[
                const SizedBox(width: KSpace.s8),
                KButton(label: action!, onPressed: onAction, variant: onDark ? KButtonVariant.overlay : KButtonVariant.tertiary, size: KButtonSize.compact),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Live Scan capture guidance (warning colour + icon).
class CaptureGuidanceBanner extends StatelessWidget {
  const CaptureGuidanceBanner({super.key, required this.guidance});
  final CaptureGuidance guidance;

  @override
  Widget build(BuildContext context) =>
      StatusBanner(title: guidance.title, message: guidance.detail, tone: BannerTone.warning, onDark: true, icon: guidance.icon);
}

enum CaptureGuidance { blurry, dark, magnification }

extension CaptureGuidanceText on CaptureGuidance {
  String get title => switch (this) {
        CaptureGuidance.blurry => 'Image is blurry, adjust focus',
        CaptureGuidance.dark => 'Too dark, increase light',
        CaptureGuidance.magnification => 'Switch to 40× for genus-level detail',
      };
  String get detail => switch (this) {
        CaptureGuidance.blurry => 'Turn the fine focus knob slowly until the body outline is sharp.',
        CaptureGuidance.dark => 'Open the condenser diaphragm or raise the lamp brightness.',
        CaptureGuidance.magnification => 'Head and tail shapes are hard to read at 10×.',
      };
  IconData get icon => switch (this) {
        CaptureGuidance.blurry => KIcons.aperture,
        CaptureGuidance.dark => KIcons.light,
        CaptureGuidance.magnification => KIcons.warning,
      };
}

/// Empty state: small line illustration, one sentence, one action.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.art, required this.message, this.detail, this.action, this.onAction});

  final LineArt art;
  final String message;
  final String? detail;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(KSpace.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LineArtView(art, size: 88),
              const SizedBox(height: KSpace.s16),
              Text(message, style: t.headline, textAlign: TextAlign.center),
              if (detail != null) ...[
                const SizedBox(height: KSpace.s4),
                Text(detail!, style: t.caption, textAlign: TextAlign.center),
              ],
              if (action != null) ...[
                const SizedBox(height: KSpace.s20),
                KButton.secondary(label: action!, onPressed: onAction),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton placeholder with a soft shimmer; disabled with reduce motion.
class SkeletonBlock extends StatefulWidget {
  const SkeletonBlock({super.key, this.width, this.height = 16, this.radius = KRadius.sm});
  final double? width;
  final double height;
  final double radius;

  @override
  State<SkeletonBlock> createState() => _SkeletonBlockState();
}

class _SkeletonBlockState extends State<SkeletonBlock> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduce || !TickerMode.valuesOf(context).enabled) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final base = k.text.withValues(alpha: context.isDark ? 0.08 : 0.06);
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final v = _c.isAnimating ? (0.5 - (_c.value - 0.5).abs()) * 2 : 0.0;
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: Color.lerp(base, k.text.withValues(alpha: context.isDark ? 0.13 : 0.1), v),
              borderRadius: BorderRadius.circular(widget.radius),
            ),
          );
        },
      ),
    );
  }
}

/// Segmented control (iOS-style), keyboard and screen-reader friendly.
class KSegmentedControl<T> extends StatelessWidget {
  const KSegmentedControl({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
    this.onDark = false,
    this.expand = true,
  });

  final List<(T, String, IconData?)> segments;
  final T value;
  final ValueChanged<T> onChanged;
  final bool onDark;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final t = context.t;
    final track = onDark ? k.overlayText.withValues(alpha: 0.14) : k.text.withValues(alpha: context.isDark ? 0.08 : 0.05);
    final thumb = onDark ? k.primary : k.surface;
    Widget seg((T, String, IconData?) s) {
      final selected = s.$1 == value;
      final fg = onDark ? (selected ? k.onPrimary : k.overlayText) : (selected ? k.text : k.textSecondary);
      final child = Pressable(
        onTap: () => onChanged(s.$1),
        selected: selected,
        semanticLabel: s.$2,
        borderRadius: KRadius.smAll,
        pressScale: 1,
        child: AnimatedContainer(
          duration: KMotion.of(context, KMotion.base),
          curve: KMotion.spring,
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: KSpace.s8, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? thumb : Colors.transparent,
            borderRadius: BorderRadius.circular(onDark ? KRadius.full : 7),
            border: selected && !onDark && !context.isDark ? Border.all(color: k.separator) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (s.$3 != null) ...[Icon(s.$3, size: KSize.iconSm + 2, color: fg), const SizedBox(width: 6)],
              Flexible(child: Text(s.$2, style: t.subhead.copyWith(color: fg, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      );
      return expand ? Expanded(child: child) : child;
    }

    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(color: track, borderRadius: BorderRadius.circular(onDark ? KRadius.full : 9)),
        child: Row(mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min, children: [for (final s in segments) seg(s)]),
      ),
    );
  }
}

/// Section title with optional trailing action ("See all").
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Row(
      children: [
        Expanded(child: Semantics(header: true, child: Text(title, style: t.title2.copyWith(fontSize: 20)))),
        if (action != null) KButton.tertiary(label: action!, onPressed: onAction, size: KButtonSize.compact),
      ],
    );
  }
}

/// Small status chip ("Offline ready", "Recorded in the Philippines").
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.icon, this.color, this.filled = false});
  final String label;
  final IconData icon;
  final Color? color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final t = context.t;
    final c = color ?? k.success;
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(KSpace.s8, 4, 10, 4),
        decoration: BoxDecoration(
          color: filled ? c.withValues(alpha: 0.13) : k.surface,
          borderRadius: KRadius.pill,
          border: filled ? null : Border.all(color: k.separator),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: c),
          const SizedBox(width: KSpace.s4),
          Text(label, style: t.captionStrong.copyWith(fontSize: 12)),
        ]),
      ),
    );
  }
}

/// Hairline divider.
class Hairline extends StatelessWidget {
  const Hairline({super.key, this.vertical = false});
  final bool vertical;

  @override
  Widget build(BuildContext context) => vertical
      ? VerticalDivider(width: 1, thickness: 1, color: context.k.separator)
      : Divider(height: 1, thickness: 1, color: context.k.separator);
}
