import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';

/// QR-style pairing code. Mock: a deterministic module pattern with finder
/// squares; the real build encodes the pairing URL with a QR library.
class PairingCode extends StatelessWidget {
  const PairingCode({super.key, required this.seed, this.size = 220});
  final int seed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Semantics(
      label: 'Pairing code',
      image: true,
      child: Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(KSpace.s16),
        decoration: BoxDecoration(color: KheryneColors.light.surface, borderRadius: KRadius.cardAll, border: Border.all(color: k.separator)),
        child: CustomPaint(painter: _QrPainter(seed, KheryneColors.light.text)),
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  _QrPainter(this.seed, this.color);
  final int seed;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const n = 29;
    final m = size.width / n;
    final r = math.Random(seed);
    final p = Paint()..color = color;
    bool finder(int x, int y) => (x < 8 && y < 8) || (x > n - 9 && y < 8) || (x < 8 && y > n - 9);
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        if (finder(x, y)) continue;
        if (r.nextDouble() < 0.48) {
          canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x * m, y * m, m, m), Radius.circular(m * 0.2)), p);
        }
      }
    }
    void eye(double ox, double oy) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(ox, oy, 7 * m, 7 * m), Radius.circular(m * 1.6)), p);
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(ox + m, oy + m, 5 * m, 5 * m), Radius.circular(m * 1.1)), Paint()..color = KheryneColors.light.surface);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(ox + 2 * m, oy + 2 * m, 3 * m, 3 * m), Radius.circular(m * 0.7)), p);
    }

    eye(0, 0);
    eye((n - 7) * m, 0);
    eye(0, (n - 7) * m);
  }

  @override
  bool shouldRepaint(_QrPainter old) => old.seed != seed || old.color != color;
}

/// Numbered step header used by the pairing flow.
class StepDots extends StatelessWidget {
  const StepDots({super.key, required this.step, required this.labels});
  final int step;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final t = context.t;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: i <= step ? k.primary : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(color: i <= step ? k.primary : k.separator, width: 1.5),
            ),
            child: Text('${i + 1}', style: t.micro.copyWith(color: i <= step ? k.onPrimary : k.textSecondary, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: KSpace.s8),
          Text(labels[i], style: t.captionStrong.copyWith(color: i == step ? k.text : k.textSecondary)),
          if (i < labels.length - 1)
            Container(width: 32, height: 1, margin: const EdgeInsets.symmetric(horizontal: KSpace.s12), color: k.separator),
        ],
      ],
    );
  }
}
