import 'dart:math' as math;

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

enum MeasureTool { length, width, stylet }

/// Polyline along the body for length, two-point width and stylet, and the
/// de Man ratios computed from them.
class MeasureScreen extends ConsumerStatefulWidget {
  const MeasureScreen({super.key, required this.specimenId, this.reportId});
  final String specimenId;
  final String? reportId;

  @override
  ConsumerState<MeasureScreen> createState() => _MeasureScreenState();
}

/// Virtual image the portrait is drawn into.
const _vw = 780.0, _vh = 300.0;

class _MeasureScreenState extends ConsumerState<MeasureScreen> {
  MeasureTool _tool = MeasureTool.length;
  final Map<MeasureTool, List<Offset>> _pts = {for (final t in MeasureTool.values) t: []};
  bool _seeded = false;

  void _autoTrace() {
    setState(() {
      _pts[MeasureTool.length] = [
        for (var i = 0; i <= 8; i++) Offset(_vw * (0.03 + 0.94 * i / 8), _vh * 0.5 + math.sin(i / 8 * math.pi * 1.4 + 0.3) * _vh * 0.05),
      ];
      _pts[MeasureTool.width] = [const Offset(_vw * 0.5, _vh * 0.5 - 39), const Offset(_vw * 0.5, _vh * 0.5 + 39)];
      _pts[MeasureTool.stylet] = [const Offset(_vw * 0.039, _vh * 0.5), const Offset(_vw * 0.095, _vh * 0.5)];
    });
  }

  double _len(List<Offset> p) {
    var d = 0.0;
    for (var i = 1; i < p.length; i++) {
      d += (p[i] - p[i - 1]).distance;
    }
    return d;
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final t = context.t;
    final report = widget.reportId == null ? null : ref.watch(reportProvider(widget.reportId!)).value;
    final specimen = ref.watch(specimenProvider(widget.specimenId)).value;
    final settings = ref.watch(settingsProvider);
    final objective = specimen?.objective ?? 40;
    final cal = settings.calibrationFor(objective);
    final genus = report?.genus ?? 'Pratylenchus';
    final ref0 = report?.morphometrics;
    if (!_seeded && report != null) {
      _seeded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? _autoTrace() : null);
    }

    // µm per virtual pixel: from the profile, scaled so the mock body
    // matches the reference length when one exists.
    final umPerPx = ref0 != null ? ref0.bodyLength / (_vw * 0.94) : (cal?.micrometresPerPixel ?? 0.405) * 1.8;
    final lengthUm = _len(_pts[MeasureTool.length]!) * umPerPx;
    final widthUm = _len(_pts[MeasureTool.width]!) * umPerPx;
    final styletUm = _len(_pts[MeasureTool.stylet]!) * umPerPx;
    final m = lengthUm > 0 && widthUm > 0
        ? Morphometrics(
            bodyLength: lengthUm,
            maxWidth: widthUm,
            styletLength: styletUm > 0 ? styletUm : (ref0?.styletLength ?? 0),
            esophagusLength: ref0 != null ? ref0.esophagusLength * lengthUm / ref0.bodyLength : lengthUm / 6.4,
            tailLength: ref0 != null ? ref0.tailLength * lengthUm / ref0.bodyLength : lengthUm / 19,
            vulvaFromHead: ref0 != null ? ref0.vulvaFromHead * lengthUm / ref0.bodyLength : lengthUm * 0.8,
          )
        : null;
    final desktop = FormFactor.of(context).isDesktop;

    final canvas = ClipRRect(
      borderRadius: KRadius.sheetAll,
      child: AspectRatio(
        aspectRatio: _vw / _vh,
        child: LayoutBuilder(builder: (context, c) {
          final s = c.maxWidth / _vw;
          return GestureDetector(
            onTapUp: (d) {
              final p = d.localPosition / s;
              setState(() {
                final list = _pts[_tool]!;
                if (_tool != MeasureTool.length && list.length >= 2) list.clear();
                list.add(p);
              });
            },
            child: Stack(children: [
              Positioned.fill(child: SpecimenPortrait(genus: genus, seed: specimen?.seed ?? 1)),
              Positioned.fill(
                child: CustomPaint(
                  painter: _MeasurePainter(
                    points: {for (final e in _pts.entries) e.key: [for (final p in e.value) p * s]},
                    active: _tool,
                    colors: {MeasureTool.length: k.userBox, MeasureTool.width: k.accent, MeasureTool.stylet: k.success},
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
        KListSection(
          header: 'MEASUREMENTS',
          children: [
            KListRow(title: 'Body length', leading: KIcons.line, leadingColor: k.userBox, value: lengthUm > 0 ? um(lengthUm) : 'Tap along the body'),
            KListRow(title: 'Max width', leading: KIcons.width, leadingColor: k.accent, value: widthUm > 0 ? um(widthUm) : '—'),
            KListRow(title: 'Stylet', leading: KIcons.crosshair, leadingColor: k.success, value: styletUm > 0 ? um(styletUm) : '—'),
          ],
        ),
        const SizedBox(height: KSpace.s20),
        Text('DE MAN INDICES', style: t.sectionHeader),
        const SizedBox(height: KSpace.s8),
        if (m == null)
          KCard(child: Text('Measure the body length and width to compute a, b, c and V%.', style: t.caption))
        else
          MorphometricsTable(m: m),
        const SizedBox(height: KSpace.s8),
        Text(
          cal == null
              ? 'No calibration for $objective×. Values use a default scale.'
              : 'Using the $objective× profile (${cal.micrometresPerPixel.toStringAsFixed(3)} µm/px). b, c and V% use landmarks from the report.',
          style: t.caption.copyWith(color: cal == null ? k.warning : k.textSecondary),
        ),
        if (cal == null) ...[
          const SizedBox(height: KSpace.s8),
          Align(alignment: Alignment.centerLeft, child: KButton.tertiary(label: 'Calibrate $objective×', size: KButtonSize.compact, onPressed: () => context.pushTo(Routes.calibrate))),
        ],
      ],
    );

    final tools = Row(
      children: [
        Expanded(
          child: KSegmentedControl<MeasureTool>(
            segments: const [
              (MeasureTool.length, 'Length', KIcons.line),
              (MeasureTool.width, 'Width', KIcons.width),
              (MeasureTool.stylet, 'Stylet', KIcons.crosshair),
            ],
            value: _tool,
            onChanged: (v) => setState(() => _tool = v),
          ),
        ),
        const SizedBox(width: KSpace.s8),
        KIconButton(
          icon: KIcons.reset,
          label: 'Clear ${_tool.name}',
          onPressed: _pts[_tool]!.isEmpty ? null : () => setState(() => _pts[_tool]!.clear()),
        ),
      ],
    );

    return Scaffold(
      appBar: KNavBar(title: 'Measure', subtitle: '$objective× objective', actions: [
        KButton.tertiary(label: 'Auto-trace', size: KButtonSize.compact, onPressed: _autoTrace),
      ]),
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
                MeasureTool.length => 'Tap from head to tail to trace the body. Each tap adds a point.',
                MeasureTool.width => 'Tap both edges at the widest point.',
                MeasureTool.stylet => 'Tap the stylet tip, then the base of the knobs.',
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
                  label: 'Save to report',
                  expand: true,
                  onPressed: m == null || report == null
                      ? null
                      : () {
                          ref.read(pendingReportsProvider.notifier).put(report.copyWith(morphometrics: m));
                          showToast(context, 'Measurements added to the report.');
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
        canvas.drawCircle(p, 6, Paint()
          ..color = handleBorder
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
      }
    }
  }

  @override
  bool shouldRepaint(_MeasurePainter old) => true;
}
