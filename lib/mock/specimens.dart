import 'dart:math' as math;
import 'dart:ui';

import '../core/models/models.dart';

/// Deterministic mock specimen for a seed. Bodies are placed inside the
/// eyepiece circle (centre 0.5, radius ~0.42) so boxes line up with the
/// rendered micrograph.
Specimen makeSpecimen(
  int seed, {
  required DateTime capturedAt,
  String? fileName,
  int objective = 40,
  CaptureSource source = CaptureSource.upload,
  int? nematodes,
  bool withDebrisBody = true,
  bool blurry = false,
  bool dark = false,
}) {
  final r = math.Random(seed);
  final count = nematodes ?? 1 + r.nextInt(3);
  final worms = <WormShape>[];
  var attempts = 0;
  while (worms.length < count && attempts < 40) {
    attempts++;
    final w = _worm(r, isNematode: true);
    if (worms.any((o) => o.bounds.overlaps(w.bounds.deflate(0.03)))) continue;
    worms.add(w);
  }
  if (withDebrisBody && r.nextDouble() < 0.7) {
    final d = _worm(r, isNematode: false);
    if (!worms.any((o) => o.bounds.overlaps(d.bounds))) worms.add(d);
  }
  return Specimen(
    id: 'sp-$seed',
    seed: seed,
    fileName: fileName ?? 'IMG_${(2000 + seed % 7000).toString().padLeft(4, '0')}.jpg',
    objective: objective,
    worms: worms,
    capturedAt: capturedAt,
    source: source,
    blurry: blurry,
    dark: dark,
  );
}

WormShape _worm(math.Random r, {required bool isNematode}) {
  // Start inside the field, pick a direction that keeps the body inside.
  final len = isNematode ? 0.30 + r.nextDouble() * 0.22 : 0.18 + r.nextDouble() * 0.12;
  final ang = r.nextDouble() * math.pi;
  final dir = Offset(math.cos(ang), math.sin(ang) * 0.75);
  final centre = Offset(0.5 + (r.nextDouble() - 0.5) * 0.36, 0.5 + (r.nextDouble() - 0.5) * 0.36);
  final start = centre - dir * (len / 2);
  final perp = Offset(-dir.dy, dir.dx);
  final amp = (isNematode ? 0.025 : 0.012) + r.nextDouble() * 0.025;
  final phase = r.nextDouble() * math.pi * 2;
  final freq = 0.9 + r.nextDouble() * 0.9;
  const n = 9;
  final spine = <Offset>[
    for (var i = 0; i < n; i++)
      start + dir * (len * i / (n - 1)) + perp * (amp * math.sin(phase + i * freq * math.pi / (n - 1) * 2)),
  ];
  return WormShape(
    spine: spine,
    width: isNematode ? 0.016 + r.nextDouble() * 0.01 : 0.02 + r.nextDouble() * 0.014,
    isNematode: isNematode,
  );
}

/// Normalised rect helper used by mocks.
Rect normRect(double l, double t, double r, double b) => Rect.fromLTRB(l, t, r, b);
