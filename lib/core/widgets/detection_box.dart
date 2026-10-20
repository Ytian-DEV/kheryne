import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/theme.dart';
import 'confidence_pill.dart';
import 'k_icons.dart';

extension BoxKindStyle on BoxKind {
  Color color(KheryneColors k) => switch (this) {
        BoxKind.ai => k.accent,
        BoxKind.user => k.userBox,
        BoxKind.confirmed => k.success,
        BoxKind.rejected => k.notNematode,
      };
}

String boxLabel(Detection d, {bool long = false}) {
  if (d.checking) return 'Checking';
  return switch (d.kind) {
    BoxKind.ai => long ? 'Candidate ${percent(d.confidence ?? 0)}' : percent(d.confidence ?? 0),
    BoxKind.user => 'Marked by you',
    BoxKind.confirmed => 'Nematode',
    BoxKind.rejected => 'Not a nematode',
  };
}

String boxSemantics(Detection d) => switch (d.kind) {
      BoxKind.ai => 'Candidate nematode, ${percent(d.confidence ?? 0)} confidence',
      BoxKind.user => 'Box you drew, not checked yet',
      BoxKind.confirmed => 'Confirmed nematode',
      BoxKind.rejected => 'Not a nematode${d.rejectReason != null ? ': ${d.rejectReason}' : ''}',
    };

/// A detection box drawn in viewport coordinates: 2 px stroke, 6 px corners,
/// label pill outside the top-left, handles when a user box is selected,
/// and a 20% outer glow in its own colour when selected.
class DetectionBox extends StatelessWidget {
  const DetectionBox({super.key, required this.detection, this.selected = false, this.longLabel = true, this.showHandles = true});

  final Detection detection;
  final bool selected;
  final bool longLabel;
  final bool showHandles;

  static const double pillHeight = 20;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final t = context.t;
    final c = detection.kind.color(k);
    final d = KMotion.of(context, KMotion.base);
    final fg = onFill(c);
    final icon = detection.checking
        ? null
        : switch (detection.kind) {
            BoxKind.confirmed => KIcons.check,
            BoxKind.rejected => KIcons.close,
            _ => null,
          };

    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (selected)
          Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _GlowPainter(c)))),
        Positioned.fill(
          child: AnimatedContainer(
            duration: d,
            curve: KMotion.ease,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(KRadius.box),
              border: Border.all(color: c, width: KSize.boxStroke),
            ),
          ),
        ),
        Positioned(
          left: -1,
          top: -pillHeight - 3,
          child: AnimatedContainer(
            duration: d,
            curve: KMotion.ease,
            height: pillHeight,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(KRadius.box)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (detection.checking) ...[
                  SizedBox.square(dimension: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: fg, backgroundColor: Colors.transparent)),
                  const SizedBox(width: 4),
                ] else if (icon != null) ...[
                  TweenAnimationBuilder<double>(
                    key: ValueKey(detection.kind),
                    tween: Tween(begin: 0.4, end: 1),
                    duration: KMotion.of(context, KMotion.slow),
                    curve: KMotion.spring,
                    builder: (context, v, child) => Transform.scale(scale: v, child: child),
                    child: Icon(icon, size: 12, color: fg),
                  ),
                  const SizedBox(width: 3),
                ],
                Text(boxLabel(detection, long: longLabel),
                    style: t.micro.copyWith(color: fg, fontWeight: FontWeight.w600, fontFeatures: KType.tabular)),
              ],
            ),
          ),
        ),
        if (selected && showHandles && detection.kind == BoxKind.user)
          for (final a in const [Alignment.topLeft, Alignment.topRight, Alignment.bottomLeft, Alignment.bottomRight])
            Positioned.fill(
              child: Align(
                alignment: a,
                child: FractionalTranslation(
                  translation: Offset(a.x * 0.5, a.y * 0.5),
                  child: Container(
                    width: KSize.handle,
                    height: KSize.handle,
                    decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: k.surface, width: 2)),
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

/// Soft outer glow in the box colour at 20% opacity: a blurred stroke
/// along the edge, so the inside of the box stays clear.
class _GlowPainter extends CustomPainter {
  _GlowPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius((Offset.zero & size).inflate(3), const Radius.circular(KRadius.box + 3));
    canvas.drawRRect(
      r,
      Paint()
        ..color = color.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }

  @override
  bool shouldRepaint(_GlowPainter old) => old.color != color;
}
