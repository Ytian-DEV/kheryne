import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/colors.dart';

/// Image adjustments shared by the editor, live scan quick toggle and the
/// Workspace "Adjust" tab.
@immutable
class ImageAdjustments {
  const ImageAdjustments({
    this.brightness = 0,
    this.contrast = 0,
    this.clahe = 0,
    this.sharpen = 0,
    this.edge = 0,
    this.grayscale = false,
    this.invert = false,
  });

  /// -1..1
  final double brightness;

  /// -1..1
  final double contrast;

  /// 0..1 local contrast (mocked as body emphasis).
  final double clahe;

  /// 0..1
  final double sharpen;

  /// 0..1
  final double edge;
  final bool grayscale;
  final bool invert;

  static const none = ImageAdjustments();

  /// One-tap preset that makes bodies stand out from debris.
  static const highlightNematodes =
      ImageAdjustments(brightness: 0.08, contrast: 0.35, clahe: 0.7, sharpen: 0.4, edge: 0.3, grayscale: true);

  bool get isNone =>
      brightness == 0 && contrast == 0 && clahe == 0 && sharpen == 0 && edge == 0 && !grayscale && !invert;

  /// How strongly bodies are emphasised over debris (0..1).
  double get emphasis => (clahe * 0.5 + sharpen * 0.25 + edge * 0.45).clamp(0.0, 1.0);

  ImageAdjustments copyWith({
    double? brightness,
    double? contrast,
    double? clahe,
    double? sharpen,
    double? edge,
    bool? grayscale,
    bool? invert,
  }) =>
      ImageAdjustments(
        brightness: brightness ?? this.brightness,
        contrast: contrast ?? this.contrast,
        clahe: clahe ?? this.clahe,
        sharpen: sharpen ?? this.sharpen,
        edge: edge ?? this.edge,
        grayscale: grayscale ?? this.grayscale,
        invert: invert ?? this.invert,
      );

  List<double> get colorMatrix {
    var m = _identity;
    if (grayscale) m = _mul(m, _gray);
    final c = 1 + contrast;
    final b = brightness * 255 + (1 - c) * 128;
    m = _mul(m, [c, 0, 0, 0, b, 0, c, 0, 0, b, 0, 0, c, 0, b, 0, 0, 0, 1, 0]);
    if (invert) m = _mul(m, _invert);
    return m;
  }

  static const _identity = <double>[1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0];
  static const _gray = <double>[
    0.2126, 0.7152, 0.0722, 0, 0, 0.2126, 0.7152, 0.0722, 0, 0, 0.2126, 0.7152, 0.0722, 0, 0, 0, 0, 0, 1, 0,
  ];
  static const _invert = <double>[-1, 0, 0, 0, 255, 0, -1, 0, 0, 255, 0, 0, -1, 0, 255, 0, 0, 0, 1, 0];

  /// a ∘ b for 4x5 colour matrices (apply b, then a).
  static List<double> _mul(List<double> a, List<double> b) {
    final out = List<double>.filled(20, 0);
    for (var r = 0; r < 4; r++) {
      for (var c = 0; c < 5; c++) {
        var v = c == 4 ? a[r * 5 + 4] : 0.0;
        for (var k = 0; k < 4; k++) {
          v += a[r * 5 + k] * b[k * 5 + c];
        }
        out[r * 5 + c] = v;
      }
    }
    return out;
  }
}

/// A realistic-looking mock brightfield micrograph for a [Specimen].
///
/// The image is square in image space; [fit] decides how it fills the box.
/// Replace with real dataset images (see README).
class Micrograph extends StatelessWidget {
  const Micrograph({
    super.key,
    required this.specimen,
    this.fit = BoxFit.cover,
    this.adjustments = ImageAdjustments.none,
    this.drift = Offset.zero,
    this.semanticLabel,
  });

  final Specimen specimen;
  final BoxFit fit;
  final ImageAdjustments adjustments;

  /// Small offset in image space, used to animate the live feed.
  final Offset drift;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    Widget img = CustomPaint(
      painter: MicrographPainter(specimen, emphasis: adjustments.emphasis, drift: drift),
      isComplex: true,
      willChange: drift != Offset.zero,
    );
    if (!adjustments.isNone) {
      img = ColorFiltered(colorFilter: ColorFilter.matrix(adjustments.colorMatrix), child: img);
    }
    return Semantics(
      label: semanticLabel ?? 'Micrograph ${specimen.fileName}',
      image: true,
      child: ClipRect(
        child: FittedBox(
          fit: fit,
          clipBehavior: Clip.hardEdge,
          child: SizedBox.square(dimension: 640, child: RepaintBoundary(child: img)),
        ),
      ),
    );
  }
}

class MicrographPainter extends CustomPainter {
  MicrographPainter(this.specimen, {this.emphasis = 0, this.drift = Offset.zero});

  final Specimen specimen;
  final double emphasis;
  final Offset drift;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final rnd = math.Random(specimen.seed * 7919);
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = s * 0.47;

    canvas.drawRect(Offset.zero & size, Paint()..color = MicrographPalette.outside);

    if (specimen.blurry) {
      canvas.saveLayer(Offset.zero & size, Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4));
    }

    // Field of view.
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: centre, radius: radius)));
    final field = Paint()
      ..shader = ui.Gradient.radial(
        centre + Offset(-s * 0.05, -s * 0.07),
        radius * 1.08,
        [MicrographPalette.field, MicrographPalette.fieldMid, MicrographPalette.fieldEdge],
        [0.0, 0.62, 1.0],
      );
    canvas.drawRect(Offset.zero & size, field);

    canvas.translate(drift.dx * s, drift.dy * s);

    // Out-of-focus debris and particles.
    final debrisAlpha = 1 - emphasis * 0.7;
    for (var i = 0; i < 46; i++) {
      final p = Offset(rnd.nextDouble() * s, rnd.nextDouble() * s);
      final r = 1.5 + rnd.nextDouble() * (i < 8 ? 9 : 4);
      final blur = 0.6 + rnd.nextDouble() * 2.4;
      canvas.drawOval(
        Rect.fromCenter(center: p, width: r * 2, height: r * (1.2 + rnd.nextDouble())),
        Paint()
          ..color = MicrographPalette.debris.withValues(alpha: (0.12 + rnd.nextDouble() * 0.3) * debrisAlpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
      );
    }
    // Fine grain.
    final grain = Paint()..strokeWidth = 1;
    for (var i = 0; i < 900; i++) {
      grain.color = (i.isEven ? MicrographPalette.debris : MicrographPalette.field)
          .withValues(alpha: 0.05 + rnd.nextDouble() * 0.07);
      canvas.drawCircle(Offset(rnd.nextDouble() * s, rnd.nextDouble() * s), 0.6 + rnd.nextDouble() * 0.6, grain);
    }

    for (final w in specimen.worms) {
      _drawBody(canvas, w, s, rnd);
    }
    canvas.restore();

    // Eyepiece vignette.
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..shader = ui.Gradient.radial(centre, radius, [
          MicrographPalette.outside.withValues(alpha: 0),
          MicrographPalette.outside.withValues(alpha: 0),
          MicrographPalette.outside.withValues(alpha: 0.55),
          MicrographPalette.outside.withValues(alpha: 0.95),
        ], [0, 0.72, 0.94, 1]),
    );

    if (specimen.blurry) canvas.restore();
    if (specimen.dark) {
      canvas.drawRect(Offset.zero & size, Paint()..color = MicrographPalette.outside.withValues(alpha: 0.5));
    }
  }

  void _drawBody(Canvas canvas, WormShape w, double s, math.Random rnd) {
    final pts = w.spine.map((p) => p * s).toList();
    final samples = _sample(pts, 60);
    final half = w.width * s / 2;
    final left = <Offset>[];
    final right = <Offset>[];
    for (var i = 0; i < samples.length; i++) {
      final t = i / (samples.length - 1);
      final a = samples[math.max(0, i - 1)];
      final b = samples[math.min(samples.length - 1, i + 1)];
      final d = b - a;
      final len = d.distance == 0 ? 1.0 : d.distance;
      final n = Offset(-d.dy / len, d.dx / len);
      double profile;
      if (w.isNematode) {
        profile = t < 0.08 ? 0.55 + t / 0.08 * 0.45 : (t > 0.78 ? math.max(0.06, (1 - t) / 0.22) : 1.0);
      } else {
        profile = 0.85 + 0.15 * math.sin(t * 9);
      }
      left.add(samples[i] + n * half * profile);
      right.add(samples[i] - n * half * profile);
    }
    final outline = Path()..moveTo(left.first.dx, left.first.dy);
    for (final p in left.skip(1)) {
      outline.lineTo(p.dx, p.dy);
    }
    for (final p in right.reversed) {
      outline.lineTo(p.dx, p.dy);
    }
    outline.close();

    final edgeAlpha = 0.55 + emphasis * 0.4;
    if (w.isNematode) {
      canvas.drawPath(
          outline,
          Paint()
            ..color = MicrographPalette.body.withValues(alpha: 0.42 + emphasis * 0.25)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.8));
      // Inner highlight along the body.
      final spine = Path()..moveTo(samples.first.dx, samples.first.dy);
      for (final p in samples.skip(1).take(samples.length - 8)) {
        spine.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
          spine,
          Paint()
            ..color = MicrographPalette.bodyHighlight.withValues(alpha: 0.55)
            ..style = PaintingStyle.stroke
            ..strokeWidth = half * 0.45
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2));
      // Intestine granules.
      for (var i = (samples.length * 0.32).round(); i < samples.length * 0.78; i += 2) {
        canvas.drawCircle(
            samples[i] + Offset((rnd.nextDouble() - 0.5) * half * 0.8, (rnd.nextDouble() - 0.5) * half * 0.8),
            0.8 + rnd.nextDouble() * 1.2,
            Paint()..color = MicrographPalette.debris.withValues(alpha: 0.35));
      }
      // Median bulb.
      final bulb = samples[(samples.length * 0.17).round()];
      canvas.drawOval(Rect.fromCenter(center: bulb, width: half * 1.3, height: half * 1.1),
          Paint()..color = MicrographPalette.body.withValues(alpha: 0.45));
      // Stylet.
      final h0 = samples[1], h1 = samples[(samples.length * 0.07).round()];
      canvas.drawLine(h0, h1, Paint()
        ..color = MicrographPalette.outside.withValues(alpha: 0.6)
        ..strokeWidth = 1.1);
    } else {
      canvas.drawPath(
          outline,
          Paint()
            ..color = MicrographPalette.debris.withValues(alpha: (0.35 + rnd.nextDouble() * 0.1) * (1 - emphasis * 0.6))
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5));
      // Cell walls in root fragments.
      for (var i = 4; i < samples.length - 4; i += 6) {
        canvas.drawLine(left[i], right[i], Paint()
          ..color = MicrographPalette.debris.withValues(alpha: 0.35 * (1 - emphasis * 0.6))
          ..strokeWidth = 1);
      }
    }
    canvas.drawPath(
        outline,
        Paint()
          ..color = (w.isNematode ? MicrographPalette.body : MicrographPalette.debris)
              .withValues(alpha: w.isNematode ? edgeAlpha : 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2 + emphasis * 1.4
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.5));
  }

  /// Catmull-Rom resample of control points.
  static List<Offset> _sample(List<Offset> pts, int n) {
    final out = <Offset>[];
    for (var i = 0; i < n; i++) {
      final t = i / (n - 1) * (pts.length - 1);
      final k = t.floor().clamp(0, pts.length - 2);
      final u = t - k;
      final p0 = pts[math.max(0, k - 1)], p1 = pts[k], p2 = pts[k + 1], p3 = pts[math.min(pts.length - 1, k + 2)];
      final u2 = u * u, u3 = u2 * u;
      out.add((p1 * 2 + (p2 - p0) * u + (p0 * 2 - p1 * 5 + p2 * 4 - p3) * u2 + (-p0 + p1 * 3 - p2 * 3 + p3) * u3) * 0.5);
    }
    return out;
  }

  @override
  bool shouldRepaint(MicrographPainter old) =>
      old.specimen.id != specimen.id || old.emphasis != emphasis || old.drift != drift;
}
