import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/layout/form_factor.dart';
import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/router/routes.dart';
import '../../core/theme/theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import '../report/report_parts.dart';

enum MeasureTool { length, width, stylet, esophagus, tail, vulva }

/// Real morphometrics measurement directly on the user's specimen micrograph,
/// computing de Man ratios (L, a, b, c, V%, stylet) from calibrated µm/px
/// and saving directly to Supabase (`public.reports.morphometrics`).
class MeasureScreen extends ConsumerStatefulWidget {
  const MeasureScreen({super.key, required this.specimenId, this.reportId});
  final String specimenId;
  final String? reportId;

  @override
  ConsumerState<MeasureScreen> createState() => _MeasureScreenState();
}

class _MeasureScreenState extends ConsumerState<MeasureScreen> {
  MeasureTool _tool = MeasureTool.length;
  final Map<MeasureTool, List<Offset>> _pts = {for (final t in MeasureTool.values) t: []};
  double? _decodedWidthPx;
  double? _decodedHeightPx;
  String? _decodedForId;
  bool _saving = false;

  Future<void> _ensureDimensions(Specimen s) async {
    if (_decodedForId == s.id) return;
    _decodedForId = s.id;
    final path = s.localPath;
    if (path != null && path.isNotEmpty) {
      final f = File(path);
      if (await f.exists()) {
        try {
          final bytes = await f.readAsBytes();
          final codec = await ui.instantiateImageCodec(bytes);
          final frame = await codec.getNextFrame();
          final w = frame.image.width.toDouble();
          final h = frame.image.height.toDouble();
          frame.image.dispose();
          if (mounted) {
            setState(() {
              _decodedWidthPx = w;
              _decodedHeightPx = h;
            });
          }
        } catch (_) {}
      }
    }
  }

  double _normLen(List<Offset> p, double imgW, double imgH) {
    var d = 0.0;
    for (var i = 1; i < p.length; i++) {
      final dx = (p[i].dx - p[i - 1].dx) * imgW;
      final dy = (p[i].dy - p[i - 1].dy) * imgH;
      d += Offset(dx, dy).distance;
    }
    return d;
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final t = context.t;
    final report = widget.reportId == null ? null : ref.watch(reportProvider(widget.reportId!)).value;
    final specimen = ref.watch(specimenProvider(widget.specimenId)).value ?? report?.specimen;
    if (specimen != null) {
      _ensureDimensions(specimen);
    }

    final settings = ref.watch(settingsProvider);
    final objective = specimen?.objective ?? 40;
    final cal = settings.calibrationFor(objective);
    final imgW = _decodedWidthPx ?? 1200.0;
    final imgH = _decodedHeightPx ?? 1200.0;
    final aspect = (imgW / imgH).clamp(0.65, 2.2);

    final umPerPx = cal?.micrometresPerPixel;
    final lengthPx = _normLen(_pts[MeasureTool.length]!, imgW, imgH);
    final widthPx = _normLen(_pts[MeasureTool.width]!, imgW, imgH);
    final styletPx = _normLen(_pts[MeasureTool.stylet]!, imgW, imgH);
    final esoPx = _normLen(_pts[MeasureTool.esophagus]!, imgW, imgH);
    final tailPx = _normLen(_pts[MeasureTool.tail]!, imgW, imgH);
    final vulvaPx = _normLen(_pts[MeasureTool.vulva]!, imgW, imgH);

    final scale = umPerPx ?? 0;
    final lengthUm = lengthPx * scale;
    final widthUm = widthPx * scale;
    final styletUm = styletPx * scale;
    final esoUm = esoPx > 0 ? esoPx * scale : (lengthUm > 0 ? lengthUm / 6.5 : 0.0);
    final tailUm = tailPx > 0 ? tailPx * scale : (lengthUm > 0 ? lengthUm / 18.0 : 0.0);
    final vulvaUm = vulvaPx > 0 ? vulvaPx * scale : (lengthUm > 0 ? lengthUm * 0.75 : 0.0);

    final m = (umPerPx != null && lengthUm > 0 && widthUm > 0)
        ? Morphometrics(
            bodyLength: lengthUm,
            maxWidth: widthUm,
            styletLength: styletUm,
            esophagusLength: esoUm,
            tailLength: tailUm,
            vulvaFromHead: vulvaUm,
          )
        : report?.morphometrics;

    final desktop = FormFactor.of(context).isDesktop;

    final canvas = ClipRRect(
      borderRadius: KRadius.sheetAll,
      child: AspectRatio(
        aspectRatio: aspect,
        child: LayoutBuilder(builder: (context, c) {
          final boxSize = Size(c.maxWidth, c.maxHeight);
          return GestureDetector(
            onTapUp: (d) {
              final norm = Offset(
                (d.localPosition.dx / boxSize.width).clamp(0.0, 1.0),
                (d.localPosition.dy / boxSize.height).clamp(0.0, 1.0),
              );
              setState(() {
                final list = _pts[_tool]!;
                if (_tool != MeasureTool.length && _tool != MeasureTool.esophagus && _tool != MeasureTool.vulva && list.length >= 2) {
                  list.clear();
                }
                list.add(norm);
              });
            },
            child: Stack(children: [
              Positioned.fill(
                child: specimen != null
                    ? Micrograph(specimen: specimen, fit: BoxFit.fill)
                    : ColoredBox(color: k.canvas),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: _MeasurePainter(
                    points: {
                      for (final e in _pts.entries)
                        e.key: [for (final p in e.value) Offset(p.dx * boxSize.width, p.dy * boxSize.height)],
                    },
                    active: _tool,
                    colors: {
                      MeasureTool.length: k.userBox,
                      MeasureTool.width: k.accent,
                      MeasureTool.stylet: k.success,
                      MeasureTool.esophagus: k.primary,
                      MeasureTool.tail: k.warning,
                      MeasureTool.vulva: k.primaryStrong,
                    },
                    handleBorder: k.surface,
                  ),
                ),
              ),
            ]),
          );
        }),
      ),
    );

    final side = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (cal == null) ...[
          StatusBanner(
            title: 'Calibration required for $objective×',
            message: 'Calibrate your $objective× objective with a stage micrometer first so pixel distances convert accurately into µm.',
            tone: BannerTone.warning,
            icon: KIcons.ruler,
          ),
          const SizedBox(height: KSpace.s12),
          KButton.secondary(
            label: 'Calibrate $objective× objective',
            icon: KIcons.ruler,
            expand: true,
            onPressed: () => context.pushTo(Routes.calibrate),
          ),
          const SizedBox(height: KSpace.s16),
        ],
        KListSection(
          header: 'MEASUREMENTS',
          children: [
            KListRow(
              title: 'Body length (L)',
              leading: KIcons.line,
              leadingColor: k.userBox,
              value: lengthUm > 0 ? um(lengthUm) : (lengthPx > 0 ? '${lengthPx.round()} px' : 'Tap along spine'),
            ),
            KListRow(
              title: 'Max width',
              leading: KIcons.width,
              leadingColor: k.accent,
              value: widthUm > 0 ? um(widthUm) : (widthPx > 0 ? '${widthPx.round()} px' : '—'),
            ),
            KListRow(
              title: 'Stylet',
              leading: KIcons.crosshair,
              leadingColor: k.success,
              value: styletUm > 0 ? um(styletUm) : (styletPx > 0 ? '${styletPx.round()} px' : '—'),
            ),
            KListRow(
              title: 'Esophagus',
              leading: KIcons.line,
              leadingColor: k.primary,
              value: esoPx > 0 ? (umPerPx != null ? um(esoUm) : '${esoPx.round()} px') : 'Optional',
            ),
            KListRow(
              title: 'Tail',
              leading: KIcons.line,
              leadingColor: k.warning,
              value: tailPx > 0 ? (umPerPx != null ? um(tailUm) : '${tailPx.round()} px') : 'Optional',
            ),
            KListRow(
              title: 'Head to vulva',
              leading: KIcons.crosshair,
              leadingColor: k.primaryStrong,
              value: vulvaPx > 0 ? (umPerPx != null ? um(vulvaUm) : '${vulvaPx.round()} px') : 'Optional',
            ),
          ],
        ),
        const SizedBox(height: KSpace.s20),
        Text('DE MAN INDICES', style: t.sectionHeader),
        const SizedBox(height: KSpace.s8),
        if (m == null)
          KCard(
            child: Text(
              cal == null
                  ? 'Calibrate $objective×, then trace body length and width to compute a, b, c and V%.'
                  : 'Trace body length and max width on the image to compute a, b, c and V%.',
              style: t.caption,
            ),
          )
        else
          MorphometricsTable(m: m),
        if (cal != null) ...[
          const SizedBox(height: KSpace.s8),
          Text(
            'Using calibrated $objective× scale (${cal.micrometresPerPixel.toStringAsFixed(4)} µm/px · image ${imgW.round()}×${imgH.round()} px).',
            style: t.caption,
          ),
        ],
      ],
    );

    final tools = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final entry in const [
            (MeasureTool.length, 'Length'),
            (MeasureTool.width, 'Width'),
            (MeasureTool.stylet, 'Stylet'),
            (MeasureTool.esophagus, 'Esophagus'),
            (MeasureTool.tail, 'Tail'),
            (MeasureTool.vulva, 'Vulva'),
          ])
            Padding(
              padding: const EdgeInsets.only(right: KSpace.s8),
              child: TraitChip(
                label: entry.$2,
                selected: _tool == entry.$1,
                onTap: () => setState(() => _tool = entry.$1),
              ),
            ),
          KIconButton(
            icon: KIcons.reset,
            label: 'Clear ${_tool.name}',
            onPressed: _pts[_tool]!.isEmpty ? null : () => setState(() => _pts[_tool]!.clear()),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: KNavBar(
        title: 'Measure',
        subtitle: '$objective× objective',
        actions: [
          KButton.tertiary(
            label: 'Clear all',
            size: KButtonSize.compact,
            onPressed: _pts.values.every((l) => l.isEmpty)
                ? null
                : () => setState(() {
                      for (final l in _pts.values) {
                        l.clear();
                      }
                    }),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(desktop ? KSpace.s32 : KSpace.s16, KSpace.s8, desktop ? KSpace.s32 : KSpace.s16, KSpace.s24),
        children: [
          tools,
          const SizedBox(height: KSpace.s12),
          if (desktop)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 3, child: canvas),
              const SizedBox(width: KSpace.s24),
              Expanded(flex: 2, child: side),
            ])
          else ...[
            canvas,
            const SizedBox(height: KSpace.s8),
            Text(
              switch (_tool) {
                MeasureTool.length => 'Tap points from head to tail along the body midline.',
                MeasureTool.width => 'Tap both body edges at the widest point.',
                MeasureTool.stylet => 'Tap the stylet tip, then the base of the knobs.',
                MeasureTool.esophagus => 'Tap along the esophagus from lips to intestinal junction.',
                MeasureTool.tail => 'Tap from anus/cloaca to the tail tip.',
                MeasureTool.vulva => 'Tap along the body from head to the vulva opening.',
              },
              style: t.caption,
            ),
            const SizedBox(height: KSpace.s20),
            side,
          ],
        ],
      ),
      bottomNavigationBar: widget.reportId == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(KSpace.s16, KSpace.s8, KSpace.s16, KSpace.s12),
                child: KButton(
                  label: 'Save measurements to report',
                  expand: true,
                  loading: _saving,
                  onPressed: m == null || report == null || _saving
                      ? null
                      : () async {
                          setState(() => _saving = true);
                          final updated = report.copyWith(morphometrics: m);
                          ref.read(pendingReportsProvider.notifier).put(updated);
                          await ref.read(identificationRepositoryProvider).save(updated);
                          ref.invalidate(historyProvider);
                          ref.invalidate(reportProvider(updated.id));
                          if (!context.mounted) return;
                          showToast(context, 'Measurements saved to report.');
                          Navigator.of(context).maybePop();
                        },
                ),
              ),
            ),
    );
  }
}

class _MeasurePainter extends CustomPainter {
  _MeasurePainter({required this.points, required this.active, required this.colors, required this.handleBorder});
  final Map<MeasureTool, List<Offset>> points;
  final MeasureTool active;
  final Map<MeasureTool, Color> colors;
  final Color handleBorder;

  @override
  void paint(Canvas canvas, Size size) {
    for (final e in points.entries) {
      final c = colors[e.key]!;
      final pts = e.value;
      final line = Paint()
        ..color = c.withValues(alpha: e.key == active ? 1 : 0.6)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      if (pts.length > 1) canvas.drawPath(Path()..addPolygon(pts, false), line);
      for (final p in pts) {
        canvas.drawCircle(p, 6, Paint()..color = c);
        canvas.drawCircle(
          p,
          6,
          Paint()
            ..color = handleBorder
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_MeasurePainter old) => true;
}
