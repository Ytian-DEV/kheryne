import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/layout/form_factor.dart';
import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/theme/theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';

/// Photograph a stage micrometer, drag two handles across a known
/// distance, enter it in µm, and save it for the objective.
class CalibrationScreen extends ConsumerStatefulWidget {
  const CalibrationScreen({super.key});

  @override
  ConsumerState<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends ConsumerState<CalibrationScreen> {
  int _objective = 40;
  double _a = 0.18;
  double _b = 0.78;
  final _known = TextEditingController(text: '100');

  /// Width of the mock micrometer photo in pixels.
  static const _photoPx = 1600.0;

  @override
  void dispose() {
    _known.dispose();
    super.dispose();
  }

  double get _px => ((_b - _a).abs() * _photoPx);
  double? get _um => double.tryParse(_known.text.replaceAll(',', '.'));
  double? get _umPerPx => _um == null || _px < 1 ? null : _um! / _px;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final t = context.t;
    final settings = ref.watch(settingsProvider);
    final existing = settings.calibrationFor(_objective);
    final now = ref.watch(clockProvider)();
    final desktop = FormFactor.of(context).isDesktop;

    final content = <Widget>[
      KSegmentedControl<int>(
        segments: const [(10, '10×', null), (40, '40×', null), (100, '100×', null)],
        value: _objective,
        onChanged: (v) => setState(() => _objective = v),
      ),
      const SizedBox(height: KSpace.s16),
      ClipRRect(
        borderRadius: KRadius.sheetAll,
        child: AspectRatio(
          aspectRatio: 1.5,
          child: LayoutBuilder(builder: (context, c) {
            final w = c.maxWidth;
            final y = c.maxHeight * 0.5;
            Widget handle(double v, String label, ValueChanged<double> set) => Positioned(
                  left: v * w - 22,
                  top: y - 22,
                  child: Semantics(
                    slider: true,
                    label: 'Handle $label',
                    value: '${(v * 100).round()}%',
                    increasedValue: '${((v + 0.01).clamp(0, 1) * 100).round()}%',
                    decreasedValue: '${((v - 0.01).clamp(0, 1) * 100).round()}%',
                    onIncrease: () => setState(() => set((v + 0.01).clamp(0, 1))),
                    onDecrease: () => setState(() => set((v - 0.01).clamp(0, 1))),
                    child: GestureDetector(
                      onHorizontalDragUpdate: (d) => setState(() => set(((v * w + d.delta.dx) / w).clamp(0.02, 0.98))),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.resizeLeftRight,
                        child: SizedBox.square(
                          dimension: 44,
                          child: Center(
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: k.userBox,
                                shape: BoxShape.circle,
                                border: Border.all(color: k.surface, width: 3),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
            return Stack(children: [
              Positioned.fill(child: CustomPaint(painter: _MicrometerPainter(objective: _objective, lineColor: k.canvas))),
              Positioned(
                left: _a * w,
                width: (_b - _a) * w,
                top: y - 1,
                child: Container(height: 2, color: k.userBox),
              ),
              Positioned(
                left: (_a + _b) / 2 * w - 60,
                top: y - 44,
                width: 120,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: KSpace.s8, vertical: 3),
                    decoration: BoxDecoration(color: k.userBox, borderRadius: BorderRadius.circular(KRadius.box)),
                    child: Text('${_px.round()} px',
                        style: t.micro.copyWith(color: onFill(k.userBox), fontWeight: FontWeight.w600, fontFeatures: KType.tabular)),
                  ),
                ),
              ),
              handle(_a, 'A', (v) => _a = v),
              handle(_b, 'B', (v) => _b = v),
            ]);
          }),
        ),
      ),
      const SizedBox(height: KSpace.s8),
      Text('Drag the purple handles to two graduations on the stage micrometer.', style: t.caption),
      const SizedBox(height: KSpace.s20),
      TextField(
        controller: _known,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(labelText: 'Known distance', suffixText: 'µm'),
      ),
      const SizedBox(height: KSpace.s16),
      KListSection(children: [
        KListRow(title: 'Scale', value: _umPerPx == null ? '—' : '${_umPerPx!.toStringAsFixed(3)} µm/px'),
        KListRow(
          title: 'Saved for $_objective×',
          value: existing == null ? 'None yet' : '${existing.micrometresPerPixel.toStringAsFixed(3)} µm/px · ${relative(existing.savedAt, now)}',
        ),
      ]),
      if (_umPerPx == null) ...[
        const SizedBox(height: KSpace.s8),
        Text('Enter the distance between the handles in micrometres.', style: t.caption.copyWith(color: k.error)),
      ],
    ];

    return Scaffold(
      appBar: const KNavBar(title: 'Calibrate', subtitle: 'Stage micrometer'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(desktop ? KSpace.s32 : KSpace.s16, KSpace.s8, desktop ? KSpace.s32 : KSpace.s16, KSpace.s24),
        children: [
          Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: content))),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(KSpace.s16, KSpace.s8, KSpace.s16, KSpace.s12),
          child: Align(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: KButton(
                label: existing == null ? 'Save for $_objective×' : 'Replace $_objective× profile',
                expand: true,
                onPressed: _umPerPx == null
                    ? null
                    : () {
                        ref.read(settingsProvider.notifier).saveCalibration(CalibrationProfile(
                              objective: _objective,
                              micrometresPerPixel: _umPerPx!,
                              savedAt: now,
                              referenceMicrometres: _um!,
                            ));
                        showToast(context, 'Saved calibration for $_objective×.');
                      },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Mock photo of a stage micrometer: bright field with a graduated scale.
class _MicrometerPainter extends CustomPainter {
  _MicrometerPainter({required this.objective, required this.lineColor});
  final int objective;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const RadialGradient(colors: [MicrographPalette.field, MicrographPalette.fieldMid, MicrographPalette.fieldEdge], stops: [0, 0.7, 1])
            .createShader(Offset.zero & size),
    );
    final y = size.height * 0.5;
    final spacing = size.width / (objective == 10 ? 50 : (objective == 40 ? 20 : 8));
    final p = Paint()
      ..color = lineColor.withValues(alpha: 0.75)
      ..strokeWidth = 1.4;
    canvas.drawLine(Offset(0, y + 14), Offset(size.width, y + 14), p);
    var i = 0;
    for (var x = 0.0; x <= size.width; x += spacing, i++) {
      final h = i % 10 == 0 ? 34.0 : (i % 5 == 0 ? 24.0 : 14.0);
      canvas.drawLine(Offset(x, y + 14), Offset(x, y + 14 - h), p);
    }
  }

  @override
  bool shouldRepaint(_MicrometerPainter old) => old.objective != objective || old.lineColor != lineColor;
}
