import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/layout/scan_theme.dart';
import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/router/routes.dart';
import '../../core/theme/theme.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/widgets.dart';
import '../../mock/specimens.dart';
import 'photo_picker_sheet.dart';

const liveDemoSeed = 77;

final liveDetectionsProvider = FutureProvider.family<List<Detection>, String>((ref, specimenId) async {
  final repo = ref.watch(identificationRepositoryProvider);
  final s = await repo.specimen(specimenId);
  return s == null ? const [] : repo.detect(s);
});

class LiveScanScreen extends ConsumerStatefulWidget {
  const LiveScanScreen({super.key, this.guidance, this.animate = true});

  /// Forces a guidance banner (screen gallery).
  final CaptureGuidance? guidance;
  final bool animate;

  @override
  ConsumerState<LiveScanScreen> createState() => _LiveScanScreenState();
}

class _LiveScanScreenState extends ConsumerState<LiveScanScreen> with TickerProviderStateMixin {
  final _cameraKey = GlobalKey<_CameraFeedState>();
  late final AnimationController _drift =
      AnimationController(vsync: this, duration: const Duration(seconds: 14));
  late final AnimationController _zoomIn = AnimationController(vsync: this, duration: KMotion.slow);
  late final AnimationController _flash = AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
  double _digitalZoom = 1;
  bool _light = true;
  bool _filter = false;
  bool _capturing = false;
  int _objective = 40;
  Rect? _zoomTarget;
  Specimen? _lastCapture;
  late final Specimen _demoSpecimen = makeSpecimen(liveDemoSeed, capturedAt: ref.read(clockProvider)(), objective: 10);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final useDemo = ref.read(settingsProvider).demoFeed || !AppConfig.supabaseReady;
    if (useDemo && widget.animate && !reduce && !_drift.isAnimating) _drift.repeat();
    if (!useDemo || reduce) _drift.stop();
  }

  @override
  void dispose() {
    _drift.dispose();
    _zoomIn.dispose();
    _flash.dispose();
    super.dispose();
  }

  Offset get _driftOffset {
    final v = _drift.value * 2 * math.pi;
    return Offset(math.sin(v) * 0.012, math.cos(v) * 0.008);
  }

  CaptureGuidance? get _guidance {
    if (widget.guidance != null) return widget.guidance;
    if (!_light) return CaptureGuidance.dark;
    if (_objective < 40) return CaptureGuidance.magnification;
    return null;
  }

  Future<void> _openBox(Detection d) async {
    Haptics.light();
    setState(() => _zoomTarget = d.rect);
    await _zoomIn.forward(from: 0);
    if (!mounted) return;
    final targetId = _lastCapture?.id ?? _demoSpecimen.id;
    await context.pushTo(Routes.zoom(targetId, d.id));
    if (!mounted) return;
    _zoomIn.value = 0;
    setState(() => _zoomTarget = null);
  }

  Future<void> _takePhoto() async {
    if (_capturing) return;
    final settings = ref.read(settingsProvider);
    final useDemo = settings.demoFeed || !AppConfig.supabaseReady;

    if (useDemo) {
      Haptics.success();
      await _flash.forward(from: 0);
      _flash.reverse();
      if (mounted) context.pushTo(Routes.captureReview(_demoSpecimen.id));
      return;
    }

    final camState = _cameraKey.currentState;
    if (camState == null || !camState.isReady) {
      final picked = await pickPhoto(context, title: 'Import microscope photo');
      if (picked != null && mounted) {
        setState(() => _lastCapture = picked);
        context.pushTo(Routes.captureReview(picked.id));
      }
      return;
    }

    setState(() => _capturing = true);
    try {
      Haptics.success();
      await _flash.forward(from: 0);
      _flash.reverse();
      final xFile = await camState.takePicture();
      if (xFile == null) {
        if (mounted) showToast(context, 'Could not capture frame from camera.');
        return;
      }
      final bytes = await xFile.readAsBytes();
      final hybrid = ref.read(hybridRepositoryProvider);
      if (hybrid != null) {
        final imported = await hybrid.importImageBytes(
          fileName: 'scan_${DateTime.now().millisecondsSinceEpoch}.jpg',
          bytes: bytes,
          objective: _objective,
          source: CaptureSource.camera,
        );
        ref.invalidate(specimensProvider);
        if (!mounted) return;
        setState(() => _lastCapture = imported);
        context.pushTo(Routes.captureReview(imported.id));
      }
    } catch (_) {
      if (mounted) showToast(context, 'Camera capture failed. Try importing from gallery.');
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _toggleTorch() async {
    final next = !_light;
    setState(() => _light = next);
    await _cameraKey.currentState?.setTorch(next);
  }

  Future<void> _setZoom(double zoom) async {
    setState(() => _digitalZoom = zoom);
    await _cameraKey.currentState?.setZoom(zoom);
  }

  Future<void> _pickObjective() async {
    final picked = await showKBottomSheet<int>(
      context,
      title: 'Objective lens',
      initial: 0.42,
      detents: const [0.42],
      builder: (ctx, c) => ListView(
        controller: c,
        padding: const EdgeInsets.fromLTRB(KSpace.s16, KSpace.s8, KSpace.s16, KSpace.s24),
        children: [
          KListSection(
            footer: 'Kheryne uses the objective to pick a calibration profile and record slide metadata.',
            children: [
              for (final o in const [4, 10, 40, 100])
                KListRow(
                  title: '$o×',
                  subtitle: switch (o) {
                    4 => 'Scanning the whole slide',
                    10 => 'Finding nematodes',
                    40 => 'Genus-level detail',
                    _ => 'Oil immersion, fine structures',
                  },
                  trailing: o == _objective ? Icon(KIcons.check, color: context.k.primary, size: KSize.icon) : null,
                  chevron: false,
                  onTap: () => Navigator.of(ctx).pop(o),
                ),
            ],
          ),
        ],
      ),
    );
    if (picked != null) setState(() => _objective = picked);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final useDemo = settings.demoFeed || !AppConfig.supabaseReady || widget.guidance != null;
    final detections = useDemo
        ? (ref.watch(liveDetectionsProvider(_demoSpecimen.id)).value ?? const <Detection>[])
        : const <Detection>[];

    return ScanTheme(
      child: Builder(builder: (context) {
        final k = context.k;
        final t = context.t;
        final guidance = _guidance;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Scaffold(
            backgroundColor: k.canvas,
            body: LayoutBuilder(builder: (context, c) {
              final size = c.biggest;
              return Stack(
                children: [
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_drift, _zoomIn]),
                      builder: (context, _) {
                        final side = math.min(size.width * 1.12, size.height) * (useDemo ? _digitalZoom : 1.0);
                        final origin = Offset((size.width - side) / 2, (size.height - side) / 2);
                        final drift = useDemo ? _driftOffset : Offset.zero;
                        Rect toScreen(Rect r) => Rect.fromLTRB(
                              origin.dx + (r.left + drift.dx) * side,
                              origin.dy + (r.top + drift.dy) * side,
                              origin.dx + (r.right + drift.dx) * side,
                              origin.dy + (r.bottom + drift.dy) * side,
                            );
                        var m = Matrix4.identity();
                        if (_zoomTarget != null) {
                          final r = toScreen(_zoomTarget!);
                          final s = 1 +
                              (math.min(size.width / (r.width * 1.3), size.height / (r.height * 1.3)) - 1) *
                                  Curves.easeOutCubic.transform(_zoomIn.value);
                          final f = Curves.easeOutCubic.transform(_zoomIn.value);
                          final dx = (size.width / 2 - r.center.dx) * f;
                          final dy = (size.height / 2 - r.center.dy) * f;
                          m = Matrix4.identity()
                            ..translateByDouble(size.width / 2 + dx, size.height / 2 + dy, 0, 1)
                            ..scaleByDouble(s, s, 1, 1)
                            ..translateByDouble(-size.width / 2, -size.height / 2, 0, 1);
                        }
                        return Transform(
                          transform: m,
                          child: Stack(children: [
                            Positioned(
                              left: origin.dx,
                              top: origin.dy,
                              width: side,
                              height: side,
                              child: useDemo
                                  ? _mock(drift)
                                  : _CameraFeed(
                                      key: _cameraKey,
                                      adjustments: _filter ? ImageAdjustments.highlightNematodes : ImageAdjustments.none,
                                      onImportFallback: () async {
                                        final picked = await pickPhoto(context, title: 'Import microscope photo');
                                        if (picked != null && context.mounted) {
                                          setState(() => _lastCapture = picked);
                                          context.pushTo(Routes.captureReview(picked.id));
                                        }
                                      },
                                    ),
                            ),
                            if (!_light && useDemo)
                              Positioned.fill(child: ColoredBox(color: k.canvas.withValues(alpha: 0.55))),
                            Positioned(
                              left: origin.dx + side * 0.03,
                              top: origin.dy + side * 0.03,
                              width: side * 0.94,
                              height: side * 0.94,
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: k.overlayText.withValues(alpha: 0.18)),
                                  ),
                                ),
                              ),
                            ),
                            if (useDemo && _zoomTarget == null)
                              for (final d in detections)
                                Positioned.fromRect(
                                  rect: toScreen(d.rect),
                                  child: Semantics(
                                    button: true,
                                    label: '${boxSemantics(d)}. Zoom in',
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => _openBox(d),
                                      child: DetectionBox(detection: d, longLabel: false),
                                    ),
                                  ),
                                ),
                          ]),
                        );
                      },
                    ),
                  ),
                  IgnorePointer(
                    child: FadeTransition(opacity: _flash, child: ColoredBox(color: k.overlayText, child: const SizedBox.expand())),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    child: _Bar(
                      top: true,
                      child: Column(
                        children: [
                          Row(
                            children: [
                              KIconButton.overlay(icon: KIcons.close, label: 'Close live scan', onPressed: () => Navigator.of(context).maybePop()),
                              const Spacer(),
                              SizedBox(
                                width: 152,
                                child: KSegmentedControl<double>(
                                  onDark: true,
                                  segments: const [(1.0, '1×', null), (2.0, '2×', null), (4.0, '4×', null)],
                                  value: _digitalZoom,
                                  onChanged: _setZoom,
                                ),
                              ),
                              const Spacer(),
                              KIconButton.overlay(
                                icon: KIcons.light,
                                label: _light ? 'Turn light off' : 'Turn light on',
                                selected: _light,
                                onPressed: _toggleTorch,
                              ),
                            ],
                          ),
                          const SizedBox(height: KSpace.s8),
                          _FocusMeter(level: widget.guidance == CaptureGuidance.blurry ? 2 : (_light ? 4 : 3)),
                        ],
                      ),
                    ),
                  ),
                  if (guidance != null)
                    Positioned(
                      left: KSpace.s16,
                      right: KSpace.s16,
                      top: MediaQuery.paddingOf(context).top + 116,
                      child: AnimatedSwitcher(
                        duration: KMotion.of(context, KMotion.base),
                        child: CaptureGuidanceBanner(key: ValueKey(guidance), guidance: guidance),
                      ),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _Bar(
                      top: false,
                      child: Column(
                        children: [
                          Pressable(
                            onTap: _pickObjective,
                            semanticLabel: 'Objective $_objective×. Change objective',
                            borderRadius: KRadius.pill,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: KSpace.s12, vertical: KSpace.s8),
                              child: Text(
                                'Objective $_objective× · Tap shutter to capture slide',
                                style: t.captionStrong.copyWith(color: k.overlayText.withValues(alpha: 0.8)),
                              ),
                            ),
                          ),
                          const SizedBox(height: KSpace.s8),
                          Row(
                            children: [
                              if (_lastCapture != null || useDemo)
                                Pressable(
                                  onTap: () => context.pushTo(Routes.captureReview((_lastCapture ?? _demoSpecimen).id)),
                                  semanticLabel: 'Last capture',
                                  borderRadius: KRadius.cardAll,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: SizedBox.square(
                                      dimension: 48,
                                      child: Micrograph(specimen: _lastCapture ?? _demoSpecimen),
                                    ),
                                  ),
                                )
                              else
                                KIconButton.overlay(
                                  icon: KIcons.images,
                                  label: 'Import image from device',
                                  onPressed: () async {
                                    final picked = await pickPhoto(context);
                                    if (picked != null && context.mounted) {
                                      setState(() => _lastCapture = picked);
                                      context.pushTo(Routes.identify(picked.id));
                                    }
                                  },
                                ),
                              const Spacer(),
                              _Shutter(onTap: _takePhoto),
                              const Spacer(),
                              KIconButton.overlay(
                                icon: KIcons.adjust,
                                label: _filter ? 'Turn off highlight filter' : 'Highlight nematodes filter',
                                selected: _filter,
                                onPressed: () => setState(() => _filter = !_filter),
                              ),
                            ],
                          ),
                          if (_lastCapture != null || useDemo) ...[
                            const SizedBox(height: KSpace.s16),
                            SizedBox(
                              width: 240,
                              child: KSegmentedControl<int>(
                                onDark: true,
                                segments: const [(0, 'Live', null), (1, 'Identification', null)],
                                value: 0,
                                onChanged: (v) {
                                  if (v == 1) context.pushTo(Routes.identify((_lastCapture ?? _demoSpecimen).id));
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
        );
      }),
    );
  }

  Widget _mock(Offset drift) => Micrograph(
        specimen: _demoSpecimen,
        fit: BoxFit.fill,
        drift: drift,
        adjustments: _filter ? ImageAdjustments.highlightNematodes : ImageAdjustments.none,
        semanticLabel: 'Live microscope view',
      );
}

class _Bar extends StatelessWidget {
  const _Bar({required this.top, required this.child});
  final bool top;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final pad = MediaQuery.paddingOf(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: top ? Alignment.topCenter : Alignment.bottomCenter,
          end: top ? Alignment.bottomCenter : Alignment.topCenter,
          colors: [k.canvas.withValues(alpha: 0.75), k.canvas.withValues(alpha: 0)],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(KSpace.s16, top ? pad.top + KSpace.s8 : KSpace.s24, KSpace.s16, top ? KSpace.s24 : pad.bottom + KSpace.s16),
        child: child,
      ),
    );
  }
}

class _FocusMeter extends StatelessWidget {
  const _FocusMeter({required this.level});
  final int level;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final t = context.t;
    final good = level >= 4;
    final c = good ? k.success : k.warning;
    final label = good ? 'Sharp' : (level >= 3 ? 'Almost' : 'Soft');
    return Semantics(
      label: 'Focus quality: $label',
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Focus', style: t.captionStrong.copyWith(color: k.overlayText.withValues(alpha: 0.8), fontSize: 12)),
          const SizedBox(width: KSpace.s8),
          for (var i = 0; i < 5; i++)
            Container(
              margin: const EdgeInsets.only(right: 3),
              width: 4,
              height: 6 + i * 2.5,
              decoration: BoxDecoration(
                color: i < level ? c : k.overlayText.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          const SizedBox(width: KSpace.s4),
          Text(label, style: t.captionStrong.copyWith(color: c, fontSize: 12)),
        ],
      ),
    );
  }
}

class _Shutter extends StatelessWidget {
  const _Shutter({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Pressable(
      onTap: onTap,
      semanticLabel: 'Take photo',
      borderRadius: KRadius.pill,
      pressScale: 0.92,
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: k.overlayText, width: 4)),
        padding: const EdgeInsets.all(5),
        child: DecoratedBox(decoration: BoxDecoration(color: k.overlayText, shape: BoxShape.circle)),
      ),
    );
  }
}

class _CameraFeed extends StatefulWidget {
  const _CameraFeed({super.key, required this.adjustments, required this.onImportFallback});
  final ImageAdjustments adjustments;
  final VoidCallback onImportFallback;

  @override
  State<_CameraFeed> createState() => _CameraFeedState();
}

class _CameraFeedState extends State<_CameraFeed> {
  CameraController? _controller;
  bool _failed = false;

  bool get isReady => _controller != null && _controller!.value.isInitialized;

  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  Future<void> _init() async {
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) throw StateError('no camera');
      final c = CameraController(cams.first, ResolutionPreset.high, enableAudio: false);
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() => _controller = c);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<XFile?> takePicture() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || c.value.isTakingPicture) return null;
    return c.takePicture();
  }

  Future<void> setTorch(bool on) async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    try {
      await c.setFlashMode(on ? FlashMode.torch : FlashMode.off);
    } catch (_) {}
  }

  Future<void> setZoom(double zoom) async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    try {
      final maxZ = await c.getMaxZoomLevel();
      final minZ = await c.getMinZoomLevel();
      await c.setZoomLevel(zoom.clamp(minZ, maxZ));
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (_failed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(KSpace.s32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(KIcons.camera, size: 42, color: context.k.overlayText.withValues(alpha: 0.7)),
                const SizedBox(height: KSpace.s12),
                Text(
                  'Camera not available on this device',
                  style: context.t.headline.copyWith(color: context.k.overlayText),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: KSpace.s8),
                Text(
                  'Import a saved microscope photo from your files, or open Kheryne on an Android phone clipped to the eyepiece.',
                  style: context.t.caption.copyWith(color: context.k.overlayText.withValues(alpha: 0.75)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: KSpace.s16),
                KButton(
                  label: 'Import microscope photo',
                  icon: KIcons.upload,
                  variant: KButtonVariant.overlay,
                  onPressed: widget.onImportFallback,
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (c == null || !c.value.isInitialized) {
      return Center(
        child: CircularProgressIndicator(strokeWidth: 2.5, color: context.k.accent),
      );
    }
    Widget preview = ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: c.value.previewSize?.height ?? 1080,
          height: c.value.previewSize?.width ?? 1920,
          child: CameraPreview(c),
        ),
      ),
    );
    if (!widget.adjustments.isNone) {
      preview = ColorFiltered(
        colorFilter: ColorFilter.matrix(widget.adjustments.colorMatrix),
        child: preview,
      );
    }
    return preview;
  }
}
