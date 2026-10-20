import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/theme.dart';

/// Reference line drawing of one trait (key choices, trait sheets, gallery).
class TraitIllustration extends StatelessWidget {
  const TraitIllustration(this.kind, {super.key, this.color, this.accent, this.height = 72});

  final Illustration kind;
  final Color? color;
  final Color? accent;
  final double height;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Semantics(
      label: 'Reference drawing',
      child: SizedBox(
        height: height,
        child: AspectRatio(
          aspectRatio: 5 / 3,
          child: CustomPaint(painter: _TraitPainter(kind, color ?? k.textSecondary, accent ?? k.primary)),
        ),
      ),
    );
  }
}

class _TraitPainter extends CustomPainter {
  _TraitPainter(this.kind, this.color, this.accent);
  final Illustration kind;
  final Color color;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final a = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final af = Paint()..color = accent;

    // Head-end body outline used by several drawings.
    Path headBody({double half = 0.22}) => Path()
      ..moveTo(w, h * (0.5 - half))
      ..lineTo(w * 0.12, h * (0.5 - half))
      ..quadraticBezierTo(0, h * (0.5 - half), 0, h * 0.5)
      ..quadraticBezierTo(0, h * (0.5 + half), w * 0.12, h * (0.5 + half))
      ..lineTo(w, h * (0.5 + half));

    Path tailBody(Path Function() tip) {
      final path = Path()..moveTo(0, h * 0.28)..lineTo(w * 0.55, h * 0.28);
      path.addPath(tip(), Offset.zero);
      return path;
    }

    switch (kind) {
      case Illustration.styletKnobbed:
      case Illustration.styletSmall:
      case Illustration.styletMassive:
        canvas.drawPath(headBody(), p);
        final len = kind == Illustration.styletSmall ? 0.18 : (kind == Illustration.styletMassive ? 0.55 : 0.34);
        final r = kind == Illustration.styletMassive ? 5.0 : (kind == Illustration.styletSmall ? 2.0 : 3.2);
        final end = Offset(w * (0.04 + len), h * 0.5);
        canvas.drawLine(Offset(w * 0.04, h * 0.5), end, a);
        canvas.drawCircle(end + Offset(0, -r), r, af);
        canvas.drawCircle(end + Offset(0, r), r, af);
        canvas.drawCircle(end + Offset(r * 0.9, 0), r, af);
      case Illustration.styletNeedle:
      case Illustration.styletFlanged:
        canvas.drawPath(headBody(half: 0.16), p);
        canvas.drawLine(Offset(w * 0.04, h * 0.5), Offset(w * 0.8, h * 0.5), a);
        canvas.drawCircle(Offset(w * (kind == Illustration.styletFlanged ? 0.5 : 0.16), h * 0.5), 5, p);
        if (kind == Illustration.styletFlanged) {
          canvas.drawLine(Offset(w * 0.8, h * 0.36), Offset(w * 0.8, h * 0.64), a..strokeWidth = 3);
        }
      case Illustration.bulbLarge:
      case Illustration.bulbOval:
        canvas.drawPath(headBody(half: 0.28), p);
        canvas.drawLine(Offset(w * 0.04, h * 0.5), Offset(w * 0.9, h * 0.5), p);
        final big = kind == Illustration.bulbLarge;
        final rect = Rect.fromCenter(center: Offset(w * 0.5, h * 0.5), width: big ? w * 0.26 : w * 0.16, height: big ? h * 0.52 : h * 0.26);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(big ? 6 : 20)), a);
        canvas.drawOval(Rect.fromCenter(center: rect.center, width: 6, height: 4), af);
      case Illustration.annulated:
      case Illustration.annulatedRetrorse:
      case Illustration.sheath:
        final body = RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.06, h * 0.26, w * 0.88, h * 0.48), Radius.circular(h * 0.24));
        if (kind == Illustration.sheath) {
          canvas.drawRRect(body.inflate(6), a);
        }
        canvas.drawRRect(body, p);
        for (var x = w * 0.14; x < w * 0.88; x += w * 0.06) {
          if (kind == Illustration.annulatedRetrorse) {
            canvas.drawLine(Offset(x, h * 0.26), Offset(x + 5, h * 0.2), a);
            canvas.drawLine(Offset(x, h * 0.74), Offset(x + 5, h * 0.8), a);
          }
          canvas.drawLine(Offset(x, h * 0.26), Offset(x, h * 0.74), kind == Illustration.sheath ? p : a);
        }
      case Illustration.swollenPear:
        final path = Path()
          ..moveTo(w * 0.12, h * 0.46)
          ..lineTo(w * 0.3, h * 0.42)
          ..cubicTo(w * 0.42, h * 0.05, w * 0.92, h * 0.08, w * 0.9, h * 0.5)
          ..cubicTo(w * 0.92, h * 0.92, w * 0.42, h * 0.95, w * 0.3, h * 0.58)
          ..lineTo(w * 0.12, h * 0.54)
          ..close();
        canvas.drawPath(path, a);
      case Illustration.cystRound:
        canvas.drawCircle(Offset(w * 0.5, h * 0.5), h * 0.38, a);
        canvas.drawCircle(Offset(w * 0.5, h * 0.5), h * 0.3, p);
      case Illustration.kidney:
        final path = Path()
          ..moveTo(w * 0.15, h * 0.55)
          ..cubicTo(w * 0.1, h * 0.05, w * 0.9, h * 0.05, w * 0.85, h * 0.55)
          ..cubicTo(w * 0.8, h * 0.9, w * 0.6, h * 0.75, w * 0.5, h * 0.62)
          ..cubicTo(w * 0.4, h * 0.75, w * 0.2, h * 0.9, w * 0.15, h * 0.55);
        canvas.drawPath(path, a);
      case Illustration.swollenPosterior:
        final path = Path()
          ..moveTo(w * 0.04, h * 0.46)
          ..lineTo(w * 0.42, h * 0.44)
          ..cubicTo(w * 0.62, h * 0.1, w * 0.96, h * 0.2, w * 0.94, h * 0.5)
          ..cubicTo(w * 0.96, h * 0.8, w * 0.62, h * 0.9, w * 0.42, h * 0.56)
          ..lineTo(w * 0.04, h * 0.54);
        canvas.drawPath(path, a);
      case Illustration.spiral:
        final path = Path();
        for (var i = 0; i <= 80; i++) {
          final t = i / 80 * math.pi * 3.2;
          final r = h * 0.08 + t * h * 0.035;
          final pt = Offset(w * 0.5 + math.cos(t) * r * 1.2, h * 0.5 + math.sin(t) * r);
          i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
        }
        canvas.drawPath(path, a..strokeWidth = 5);
      case Illustration.straight:
      case Illustration.slender:
        final path = Path()
          ..moveTo(w * 0.05, h * 0.55)
          ..cubicTo(w * 0.35, h * 0.35, w * 0.6, h * 0.7, w * 0.95, h * 0.45);
        canvas.drawPath(path, a..strokeWidth = kind == Illustration.slender ? 3 : 7);
      case Illustration.tailConoid:
        canvas.drawPath(tailBody(() => Path()
          ..moveTo(w * 0.55, h * 0.28)
          ..quadraticBezierTo(w * 0.8, h * 0.32, w * 0.94, h * 0.5)
          ..quadraticBezierTo(w * 0.8, h * 0.7, w * 0.55, h * 0.72)
          ..lineTo(0, h * 0.72)), p);
        canvas.drawLine(Offset(w * 0.86, h * 0.44), Offset(w * 0.93, h * 0.5), a);
      case Illustration.tailRounded:
        canvas.drawPath(tailBody(() => Path()
          ..moveTo(w * 0.55, h * 0.28)
          ..arcToPoint(Offset(w * 0.55, h * 0.72), radius: Radius.circular(h * 0.22))
          ..lineTo(0, h * 0.72)), p);
        canvas.drawArc(Rect.fromCircle(center: Offset(w * 0.55, h * 0.5), radius: h * 0.22), -0.6, 1.2, false, a);
      case Illustration.tailPointed:
      case Illustration.tailMucro:
        canvas.drawPath(tailBody(() => Path()
          ..moveTo(w * 0.55, h * 0.28)
          ..lineTo(w * 0.86, h * 0.5)
          ..lineTo(w * 0.55, h * 0.72)
          ..lineTo(0, h * 0.72)), p);
        if (kind == Illustration.tailMucro) {
          canvas.drawLine(Offset(w * 0.86, h * 0.5), Offset(w * 0.97, h * 0.5), a..strokeWidth = 2.5);
        } else {
          canvas.drawLine(Offset(w * 0.76, h * 0.43), Offset(w * 0.86, h * 0.5), a);
        }
      case Illustration.glandsOverlap:
      case Illustration.glandsAbutting:
        canvas.drawRect(Rect.fromLTWH(0, h * 0.22, w, h * 0.56), p);
        canvas.drawLine(Offset(0, h * 0.5), Offset(w * 0.3, h * 0.5), p);
        final overlap = kind == Illustration.glandsOverlap;
        canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.28, h * 0.32, overlap ? w * 0.48 : w * 0.18, overlap ? h * 0.4 : h * 0.36),
                const Radius.circular(10)),
            a);
        canvas.drawLine(Offset(w * 0.46, h * 0.24), Offset(w * 0.46, h * 0.76), p..strokeWidth = 1);
      case Illustration.lipFlat:
      case Illustration.lipOffset:
        canvas.drawPath(headBody(half: 0.26), p);
        if (kind == Illustration.lipOffset) {
          canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-2, h * 0.2, w * 0.16, h * 0.6), const Radius.circular(10)), a);
        } else {
          canvas.drawLine(Offset(w * 0.02, h * 0.3), Offset(w * 0.02, h * 0.7), a..strokeWidth = 3);
        }
      case Illustration.vulvaPosterior:
      case Illustration.vulvaMid:
        final body = RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.04, h * 0.36, w * 0.92, h * 0.28), Radius.circular(h * 0.14));
        canvas.drawRRect(body, p);
        final x = w * (kind == Illustration.vulvaPosterior ? 0.78 : 0.52);
        canvas.drawLine(Offset(x - 4, h * 0.64), Offset(x + 4, h * 0.54), a..strokeWidth = 2.5);
        canvas.drawLine(Offset(w * 0.04, h * 0.84), Offset(x, h * 0.84), p..strokeWidth = 1);
        canvas.drawLine(Offset(x, h * 0.8), Offset(x, h * 0.88), p);
    }
  }

  @override
  bool shouldRepaint(_TraitPainter old) => old.kind != kind || old.color != color || old.accent != accent;
}

enum LineArt { microscope, phoneOnEyepiece, offlineModels, emptySlide, noResults, offline, brokenSlide, slides, pairing, camera }

/// Small line illustration for empty states and onboarding.
class LineArtView extends StatelessWidget {
  const LineArtView(this.kind, {super.key, this.size = 96});
  final LineArt kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _LineArtPainter(kind, k.textSecondary, k.primary)),
      ),
    );
  }
}

class _LineArtPainter extends CustomPainter {
  _LineArtPainter(this.kind, this.color, this.accent);
  final LineArt kind;
  final Color color;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final a = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    Offset o(double x, double y) => Offset(x * s, y * s);
    RRect rr(double l, double t, double w, double h, double r) =>
        RRect.fromRectAndRadius(Rect.fromLTWH(l * s, t * s, w * s, h * s), Radius.circular(r * s));

    void microscope() {
      canvas.drawLine(o(0.25, 0.86), o(0.78, 0.86), p);
      canvas.drawLine(o(0.5, 0.86), o(0.5, 0.74), p);
      canvas.drawRRect(rr(0.36, 0.66, 0.36, 0.08, 0.02), p);
      canvas.drawLine(o(0.68, 0.66), o(0.68, 0.36), p);
      canvas.drawArc(Rect.fromCircle(center: o(0.6, 0.36), radius: 0.08 * s), math.pi * 1.5, math.pi / 2, false, p);
      final tube = Path()
        ..moveTo(0.36 * s, 0.14 * s)
        ..lineTo(0.48 * s, 0.1 * s)
        ..lineTo(0.6 * s, 0.5 * s)
        ..lineTo(0.5 * s, 0.54 * s)
        ..close();
      canvas.drawPath(tube, p);
      canvas.drawLine(o(0.52, 0.56), o(0.54, 0.62), a);
    }

    switch (kind) {
      case LineArt.microscope:
        microscope();
      case LineArt.phoneOnEyepiece:
        canvas.drawRRect(rr(0.18, 0.14, 0.36, 0.64, 0.06), p);
        canvas.drawCircle(o(0.36, 0.28), 0.04 * s, a);
        canvas.drawRRect(rr(0.54, 0.24, 0.14, 0.12, 0.02), a);
        canvas.drawLine(o(0.62, 0.36), o(0.62, 0.88), p);
        canvas.drawRRect(rr(0.56, 0.42, 0.12, 0.1, 0.02), p);
        canvas.drawLine(o(0.5, 0.88), o(0.84, 0.88), p);
      case LineArt.offlineModels:
        canvas.drawRRect(rr(0.2, 0.2, 0.6, 0.6, 0.1), p);
        canvas.drawLine(o(0.5, 0.32), o(0.5, 0.6), a);
        canvas.drawLine(o(0.38, 0.5), o(0.5, 0.62), a);
        canvas.drawLine(o(0.62, 0.5), o(0.5, 0.62), a);
        canvas.drawLine(o(0.34, 0.7), o(0.66, 0.7), p);
      case LineArt.emptySlide:
        canvas.drawRRect(rr(0.1, 0.36, 0.8, 0.28, 0.03), p);
        canvas.drawRRect(rr(0.38, 0.4, 0.24, 0.2, 0.02), p);
        canvas.drawLine(o(0.16, 0.42), o(0.3, 0.42), a);
      case LineArt.noResults:
        canvas.drawCircle(o(0.44, 0.44), 0.2 * s, p);
        canvas.drawLine(o(0.59, 0.59), o(0.78, 0.78), p..strokeWidth = 2.4);
        canvas.drawLine(o(0.36, 0.44), o(0.52, 0.44), a);
      case LineArt.offline:
        final cloud = Path()
          ..moveTo(0.3 * s, 0.66 * s)
          ..arcToPoint(o(0.34, 0.44), radius: Radius.circular(0.12 * s))
          ..arcToPoint(o(0.66, 0.4), radius: Radius.circular(0.17 * s))
          ..arcToPoint(o(0.7, 0.66), radius: Radius.circular(0.13 * s))
          ..close();
        canvas.drawPath(cloud, p);
        canvas.drawLine(o(0.24, 0.24), o(0.78, 0.8), a);
      case LineArt.brokenSlide:
        canvas.drawRRect(rr(0.1, 0.36, 0.8, 0.28, 0.03), p);
        final crack = Path()
          ..moveTo(0.52 * s, 0.36 * s)
          ..lineTo(0.46 * s, 0.46 * s)
          ..lineTo(0.54 * s, 0.52 * s)
          ..lineTo(0.48 * s, 0.64 * s);
        canvas.drawPath(crack, a);
      case LineArt.slides:
        for (var i = 0; i < 3; i++) {
          canvas.drawRRect(rr(0.14 + i * 0.05, 0.26 + i * 0.12, 0.62, 0.2, 0.03), i == 2 ? a : p);
        }
      case LineArt.pairing:
        canvas.drawRRect(rr(0.08, 0.26, 0.5, 0.36, 0.03), p);
        canvas.drawLine(o(0.02, 0.68), o(0.64, 0.68), p);
        canvas.drawRRect(rr(0.68, 0.34, 0.22, 0.4, 0.04), p);
        canvas.drawArc(Rect.fromCircle(center: o(0.62, 0.3), radius: 0.08 * s), -2.4, 1.2, false, a);
        canvas.drawArc(Rect.fromCircle(center: o(0.62, 0.3), radius: 0.14 * s), -2.4, 1.2, false, a);
      case LineArt.camera:
        canvas.drawRRect(rr(0.14, 0.3, 0.72, 0.48, 0.08), p);
        canvas.drawCircle(o(0.5, 0.54), 0.14 * s, a);
        canvas.drawRRect(rr(0.36, 0.22, 0.2, 0.08, 0.02), p);
    }
  }

  @override
  bool shouldRepaint(_LineArtPainter old) => old.kind != kind || old.color != color;
}
