import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/colors.dart';

enum _Tail { conoid, rounded, pointed, mucro }

enum _Stylet { knobbed, small, massive, needle, flanged }

class _Look {
  const _Look({
    this.tail = _Tail.conoid,
    this.stylet = _Stylet.knobbed,
    this.vulva = 0.75,
    this.rings = false,
    this.sheath = false,
    this.bigBulb = false,
    this.overlap = true,
  });
  final _Tail tail;
  final _Stylet stylet;
  final double vulva;
  final bool rings;
  final bool sheath;
  final bool bigBulb;
  final bool overlap;
}

const _looks = <String, _Look>{
  'Pratylenchus': _Look(tail: _Tail.rounded, vulva: 0.80),
  'Radopholus': _Look(tail: _Tail.conoid, vulva: 0.56),
  'Hirschmanniella': _Look(tail: _Tail.mucro, vulva: 0.52),
  'Helicotylenchus': _Look(tail: _Tail.conoid, vulva: 0.62),
  'Hoplolaimus': _Look(tail: _Tail.rounded, stylet: _Stylet.massive, vulva: 0.55),
  'Rotylenchus': _Look(tail: _Tail.rounded, vulva: 0.58),
  'Rotylenchulus': _Look(tail: _Tail.conoid, vulva: 0.70),
  'Tylenchorhynchus': _Look(tail: _Tail.rounded, vulva: 0.56, overlap: false),
  'Criconemoides': _Look(tail: _Tail.conoid, stylet: _Stylet.massive, vulva: 0.90, rings: true),
  'Mesocriconema': _Look(tail: _Tail.rounded, stylet: _Stylet.massive, vulva: 0.92, rings: true),
  'Hemicriconemoides': _Look(tail: _Tail.conoid, stylet: _Stylet.massive, vulva: 0.92, rings: true, sheath: true),
  'Hemicycliophora': _Look(tail: _Tail.pointed, stylet: _Stylet.massive, vulva: 0.85, rings: true, sheath: true),
  'Tylenchulus': _Look(tail: _Tail.conoid, stylet: _Stylet.small, vulva: 0.80),
  'Ditylenchus': _Look(tail: _Tail.pointed, stylet: _Stylet.small, vulva: 0.80, overlap: false),
  'Aphelenchoides': _Look(tail: _Tail.mucro, stylet: _Stylet.small, vulva: 0.68, bigBulb: true),
  'Xiphinema': _Look(tail: _Tail.rounded, stylet: _Stylet.flanged, vulva: 0.45),
  'Longidorus': _Look(tail: _Tail.rounded, stylet: _Stylet.needle, vulva: 0.50),
  'Meloidogyne': _Look(tail: _Tail.conoid, vulva: 0.85),
  'Globodera': _Look(tail: _Tail.conoid, vulva: 0.88),
};

/// A straightened, high-magnification rendering of one specimen, used in the
/// report header, zoomed specimen view and trait crops. Mock imagery.
class SpecimenPortrait extends StatelessWidget {
  const SpecimenPortrait({
    super.key,
    required this.genus,
    this.seed = 1,
    this.crop,
    this.localPath,
    this.imageUrl,
  });

  final String genus;
  final int seed;

  /// Optional normalised crop (0..1) to zoom into one region.
  final Rect? crop;
  final String? localPath;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final fallback = CustomPaint(painter: _PortraitPainter(_looks[genus] ?? const _Look(), seed));
    Widget base = fallback;
    if (localPath != null && localPath!.isNotEmpty && File(localPath!).existsSync()) {
      base = Image.file(File(localPath!), fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback);
    } else if (imageUrl != null && imageUrl!.isNotEmpty) {
      base = Image.network(imageUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback);
    }
    return ClipRect(
      child: LayoutBuilder(builder: (context, c) {
        if (crop == null) return SizedBox.expand(child: base);
        final r = crop!;
        final scale = math.max(c.maxWidth / (780 * r.width), c.maxHeight / (300 * r.height));
        return OverflowBox(
          alignment: Alignment.topLeft,
          maxWidth: double.infinity,
          maxHeight: double.infinity,
          child: Transform.translate(
            offset: Offset(-r.left * 780 * scale + (c.maxWidth - r.width * 780 * scale) / 2,
                -r.top * 300 * scale + (c.maxHeight - r.height * 300 * scale) / 2),
            child: SizedBox(width: 780 * scale, height: 300 * scale, child: base),
          ),
        );
      }),
    );
  }
}

class _PortraitPainter extends CustomPainter {
  _PortraitPainter(this.look, this.seed);
  final _Look look;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rnd = math.Random(seed);
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = ui.Gradient.radial(Offset(w * 0.45, h * 0.4), w * 0.75,
              [MicrographPalette.field, MicrographPalette.fieldMid, MicrographPalette.fieldEdge], [0, 0.7, 1]));
    for (var i = 0; i < 260; i++) {
      canvas.drawCircle(Offset(rnd.nextDouble() * w, rnd.nextDouble() * h), 0.6 + rnd.nextDouble(),
          Paint()..color = MicrographPalette.debris.withValues(alpha: 0.06 + rnd.nextDouble() * 0.06));
    }

    double cy(double t) => h * 0.5 + math.sin(t * math.pi * 1.4 + 0.3) * h * 0.05;
    final maxHalf = math.min(h * 0.13, w * 0.05);
    double half(double t) {
      if (t < 0.035) return maxHalf * (0.55 + 0.45 * math.sqrt(t / 0.035));
      final tailStart = switch (look.tail) { _Tail.rounded => 0.93, _ => 0.86 };
      if (t > tailStart) {
        final u = (t - tailStart) / (1 - tailStart);
        return switch (look.tail) {
          _Tail.rounded => maxHalf * math.sqrt(math.max(0, 1 - u * u)),
          _Tail.conoid => maxHalf * (1 - u * 0.92),
          _Tail.pointed => maxHalf * math.pow(1 - u, 1.3).toDouble(),
          _Tail.mucro => maxHalf * (1 - u * 0.85),
        };
      }
      return maxHalf;
    }

    const n = 120;
    const x0 = 0.03, x1 = 0.97;
    final top = <Offset>[], bot = <Offset>[];
    for (var i = 0; i <= n; i++) {
      final t = i / n;
      final x = w * (x0 + (x1 - x0) * t);
      top.add(Offset(x, cy(t) - half(t)));
      bot.add(Offset(x, cy(t) + half(t)));
    }
    final body = Path()..moveTo(top.first.dx, top.first.dy);
    for (final p in top.skip(1)) {
      body.lineTo(p.dx, p.dy);
    }
    for (final p in bot.reversed) {
      body.lineTo(p.dx, p.dy);
    }
    body.close();

    Offset at(double t, [double off = 0]) => Offset(w * (x0 + (x1 - x0) * t), cy(t) + off * maxHalf);

    if (look.sheath) {
      canvas.drawPath(
          body.shift(Offset.zero),
          Paint()
            ..color = MicrographPalette.body.withValues(alpha: 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = maxHalf * 0.45
            ..strokeJoin = StrokeJoin.round);
    }
    canvas.drawPath(body, Paint()..color = MicrographPalette.bodyHighlight.withValues(alpha: 0.85));
    canvas.drawPath(
        body,
        Paint()
          ..shader = ui.Gradient.linear(Offset(0, h * 0.35), Offset(0, h * 0.65), [
            MicrographPalette.body.withValues(alpha: 0.55),
            MicrographPalette.body.withValues(alpha: 0.12),
            MicrographPalette.body.withValues(alpha: 0.55),
          ], [0, 0.5, 1]));

    final line = Paint()
      ..color = MicrographPalette.lineArt.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    if (look.rings) {
      for (var t = 0.02; t < 0.97; t += 0.012) {
        final p = at(t);
        final hh = half(t);
        canvas.drawLine(Offset(p.dx, p.dy - hh), Offset(p.dx + 2, p.dy + hh), line..strokeWidth = 1);
      }
    } else {
      // Lip annules.
      for (var k = 1; k <= 3; k++) {
        final p = at(0.006 * k);
        canvas.drawArc(Rect.fromCenter(center: p, width: 8, height: half(0.006 * k) * 2), -math.pi / 2, math.pi, false,
            line..strokeWidth = 1);
      }
    }

    // Stylet.
    line.strokeWidth = 1.6;
    final sLen = switch (look.stylet) {
      _Stylet.small => 0.035,
      _Stylet.knobbed => 0.06,
      _Stylet.massive => 0.1,
      _Stylet.needle => 0.2,
      _Stylet.flanged => 0.2,
    };
    final s0 = at(0.012), s1 = at(0.012 + sLen);
    canvas.drawLine(s0, s1, line);
    if (look.stylet == _Stylet.knobbed || look.stylet == _Stylet.massive || look.stylet == _Stylet.small) {
      final r = look.stylet == _Stylet.massive ? 4.5 : (look.stylet == _Stylet.small ? 2.0 : 3.0);
      final knob = Paint()..color = MicrographPalette.lineArt.withValues(alpha: 0.85);
      canvas.drawCircle(s1 + Offset(0, -r), r, knob);
      canvas.drawCircle(s1 + Offset(0, r), r, knob);
      canvas.drawCircle(s1 + Offset(r * 0.8, 0), r * 0.9, knob);
    }
    if (look.stylet == _Stylet.flanged) {
      final f = at(0.012 + sLen + 0.04);
      canvas.drawLine(s1, f, line);
      canvas.drawLine(f + const Offset(0, -6), f + const Offset(0, 6), line..strokeWidth = 2.5);
      canvas.drawCircle(at(0.012 + sLen * 0.8), 4, line..strokeWidth = 1);
    }
    if (look.stylet == _Stylet.needle) {
      canvas.drawCircle(at(0.03), 4, line..strokeWidth = 1);
    }

    // Esophagus and median bulb.
    final bulbT = look.stylet == _Stylet.needle || look.stylet == _Stylet.flanged ? 0.3 : 0.2;
    line.strokeWidth = 1.2;
    canvas.drawLine(at(0.012 + sLen), at(bulbT - 0.02), line);
    final bw = look.bigBulb ? maxHalf * 1.7 : maxHalf * 0.9;
    final bh = look.bigBulb ? maxHalf * 1.7 : maxHalf * 0.75;
    canvas.drawOval(Rect.fromCenter(center: at(bulbT), width: bw, height: bh),
        Paint()..color = MicrographPalette.body.withValues(alpha: 0.6));
    canvas.drawOval(Rect.fromCenter(center: at(bulbT), width: bw * 0.35, height: bh * 0.3),
        Paint()..color = MicrographPalette.lineArt.withValues(alpha: 0.7));
    canvas.drawLine(at(bulbT + 0.02), at(bulbT + 0.08), line);
    // Glands (overlapping lobe or abutting).
    final gEnd = look.overlap ? bulbT + 0.17 : bulbT + 0.1;
    final glands = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromPoints(at(bulbT + 0.08, -0.55), at(gEnd, look.overlap ? 0.75 : 0.55)), const Radius.circular(12)));
    canvas.drawPath(glands, Paint()..color = MicrographPalette.body.withValues(alpha: 0.32));

    // Intestine granules.
    for (var i = 0; i < 260; i++) {
      final t = bulbT + 0.12 + rnd.nextDouble() * (0.86 - bulbT - 0.12);
      final off = (rnd.nextDouble() - 0.5) * 1.2;
      canvas.drawCircle(at(t, off), 1 + rnd.nextDouble() * 1.8,
          Paint()..color = MicrographPalette.debris.withValues(alpha: 0.18 + rnd.nextDouble() * 0.25));
    }

    // Vulva on the ventral side.
    final v = at(x0 + (look.vulva) * (x1 - x0) - 0.03);
    final vt = look.vulva - 0.03;
    canvas.drawLine(Offset(v.dx - 5, cy(vt) + half(vt) - 1), Offset(v.dx + 3, cy(vt) + half(vt) * 0.45), line..strokeWidth = 1.8);

    // Tail tip.
    if (look.tail == _Tail.mucro) {
      final tip = at(1);
      canvas.drawLine(tip, tip + const Offset(7, 0), line..strokeWidth = 1.4);
    }

    canvas.drawPath(
        body,
        Paint()
          ..color = MicrographPalette.lineArt.withValues(alpha: 0.75)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6);
  }

  @override
  bool shouldRepaint(_PortraitPainter old) => old.look != look || old.seed != seed;
}
