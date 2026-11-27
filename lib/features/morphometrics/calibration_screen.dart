import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/layout/form_factor.dart';
import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/theme/theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';

const _micrometerGroup = XTypeGroup(
  label: 'Micrometer images',
  extensions: ['jpg', 'jpeg', 'png', 'webp', 'tif', 'tiff'],
);

/// Photograph or import a real stage micrometer slide, drag two handles across
/// a known graduation distance in µm, and save the exact µm/px scale for that
/// microscope objective to Supabase.
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

  Uint8List? _imageBytes;
  String? _imageName;
  double? _realWidthPx;
  double? _realHeightPx;

  @override
  void dispose() {
    _known.dispose();
    super.dispose();
  }

  Future<void> _pickMicrometerPhoto() async {
    try {
      final xFile = await openFile(acceptedTypeGroups: const [_micrometerGroup]);
      if (xFile == null) return;
      final bytes = await xFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final w = frame.image.width.toDouble();
      final h = frame.image.height.toDouble();
      frame.image.dispose();
      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _imageName = xFile.name;
        _realWidthPx = w;
        _realHeightPx = h;
      });
    } catch (_) {
      if (mounted) showToast(context, 'Could not decode that micrometer image.');
    }
  }

  bool get _hasPhoto => _imageBytes != null && _realWidthPx != null;
  double get _effectiveWidthPx => _realWidthPx ?? 1600.0;
  double get _px => (_b - _a).abs() * _effectiveWidthPx;
  double? get _um => double.tryParse(_known.text.replaceAll(',', '.'));
  double? get _umPerPx => _um == null || _px < 1 ? null : _um! / _px;
  bool get _canSave => _umPerPx != null && (_hasPhoto || !AppConfig.supabaseReady);

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final t = context.t;
    final settings = ref.watch(settingsProvider);
    final existing = settings.calibrationFor(_objective);
    final now = ref.watch(clockProvider)();
    final desktop = FormFactor.of(context).isDesktop;
    final aspect = (_realWidthPx != null && _realHeightPx != null && _realHeightPx! > 0)
        ? (_realWidthPx! / _realHeightPx!).clamp(0.8, 2.2)
        : 1.5;

    final content = <Widget>[
      KSegmentedControl<int>(
        segments: const [(10, '10×', null), (40, '40×', null), (100, '100×', null)],
        value: _objective,
        onChanged: (v) => setState(() => _objective = v),
      ),
      const SizedBox(height: KSpace.s12),
      Row(
        children: [
          Expanded(
            child: Text(
              _hasPhoto
                  ? '$_imageName · ${_realWidthPx!.round()}×${_realHeightPx!.round()} px'
                  : 'Import a photo of your stage micrometer at $_objective× to measure exact pixels.',
              style: t.caption,
            ),
          ),
          const SizedBox(width: KSpace.s8),
          KButton.secondary(
            label: _hasPhoto ? 'Change photo' : 'Import micrometer photo',
            icon: KIcons.upload,
            size: KButtonSize.compact,
            onPressed: _pickMicrometerPhoto,
          ),
        ],
      ),
      const SizedBox(height: KSpace.s12),
      ClipRRect(
        borderRadius: KRadius.sheetAll,
        child: AspectRatio(
          aspectRatio: aspect,
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
              Positioned.fill(
                child: _hasPhoto
                    ? Image.memory(_imageBytes!, fit: BoxFit.fill)
                    : CustomPaint(painter: _MicrometerPainter(objective: _objective, lineColor: k.canvas)),
              ),
              Positioned(
                left: math.min(_a, _b) * w,
                width: (_b - _a).abs() * w,
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
                    child: Text(
                      '${_px.round()} px',
                      style: t.micro.copyWith(color: onFill(k.userBox), fontWeight: FontWeight.w600, fontFeatures: KType.tabular),
                    ),
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
      Text('Drag the purple handles to two graduations on your stage micrometer.', style: t.caption),
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
        KListRow(
          title: 'Computed scale',
          value: !_hasPhoto && AppConfig.supabaseReady
              ? 'Import micrometer photo first'
              : (_umPerPx == null ? '—' : '${_umPerPx!.toStringAsFixed(4)} µm/px'),
        ),
        KListRow(
          title: 'Saved for $_objective×',
          value: existing == null
              ? 'None yet'
              : '${existing.micrometresPerPixel.toStringAsFixed(4)} µm/px · ${relative(existing.savedAt, now)}',
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
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: content),
            ),
          ),
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
                label: !_hasPhoto && AppConfig.supabaseReady
                    ? 'Import micrometer photo to save'
                    : (existing == null ? 'Save for $_objective×' : 'Replace $_objective× profile'),
                expand: true,
                onPressed: !_canSave
                    ? (AppConfig.supabaseReady && !_hasPhoto ? _pickMicrometerPhoto : null)
                    : () {
                        ref.read(settingsProvider.notifier).saveCalibration(CalibrationProfile(
                              objective: _objective,
                              micrometresPerPixel: _umPerPx!,
                              savedAt: now,
                              referenceMicrometres: _um!,
                            ));
                        showToast(context, 'Saved calibration for $_objective×.');
                        if (Platform.isWindows || Platform.isAndroid) {
                          Navigator.of(context).maybePop();
                        }
                      },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MicrometerPainter extends CustomPainter {
  _MicrometerPainter({required this.objective, required this.lineColor});
  final int objective;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const RadialGradient(
          colors: [MicrographPalette.field, MicrographPalette.fieldMid, MicrographPalette.fieldEdge],
          stops: [0, 0.7, 1],
        ).createShader(Offset.zero & size),
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
