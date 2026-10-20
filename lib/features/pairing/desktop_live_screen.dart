import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/layout/app_shell.dart';
import '../../core/layout/scan_theme.dart';
import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../mock/specimens.dart';
import '../workspace/workspace_controller.dart';
import 'pairing_widgets.dart';
import 'package:go_router/go_router.dart';

enum PairStep { code, connecting, connected, error }

class PairingController extends Notifier<PairStep> {
  Timer? _t;

  @override
  PairStep build() {
    ref.onDispose(() => _t?.cancel());
    return PairStep.code;
  }

  /// Mock: the phone "scans" the code a moment after it is shown.
  void simulateScan() {
    state = PairStep.connecting;
    _t?.cancel();
    _t = Timer(const Duration(milliseconds: 1600), () => state = ref.read(onlineProvider) ? PairStep.connected : PairStep.error);
  }

  void set(PairStep s) => state = s;
  void disconnect() => state = PairStep.code;
}

final pairingProvider = NotifierProvider<PairingController, PairStep>(PairingController.new);

const phoneName = 'Ana’s Pixel 8';
const laptopName = 'LAPTOP-VSU-NEMA';

/// Windows: pair the phone on the eyepiece and stream its view here.
class DesktopLiveScreen extends ConsumerWidget {
  const DesktopLiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final step = ref.watch(pairingProvider);
    final c = ref.read(pairingProvider.notifier);
    if (step == PairStep.connected) return const ScanTheme(child: _Stream());
    final t = context.t;
    final k = context.k;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(KSpace.s40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StepDots(step: step == PairStep.code ? 0 : 1, labels: const ['Scan code', 'Connect', 'Stream']),
                const SizedBox(height: KSpace.s32),
                if (step == PairStep.code) ...[
                  Text('Live view from your phone', style: t.title1, textAlign: TextAlign.center),
                  const SizedBox(height: KSpace.s8),
                  Text('Open Kheryne on your phone → Settings → Pair with computer, then scan this code.',
                      style: t.callout.copyWith(color: k.textSecondary), textAlign: TextAlign.center),
                  const SizedBox(height: KSpace.s24),
                  Pressable(
                    onTap: c.simulateScan,
                    semanticLabel: 'Pairing code. Activate to simulate a scan',
                    child: const PairingCode(seed: 2026, size: 240),
                  ),
                  const SizedBox(height: KSpace.s16),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(KIcons.wifi, size: 16, color: k.textSecondary),
                    const SizedBox(width: KSpace.s8),
                    Text('Both devices must be on the same Wi-Fi network.', style: t.caption),
                  ]),
                  const SizedBox(height: KSpace.s8),
                  Text('Code refreshes every 5 minutes · $laptopName', style: t.micro),
                ] else if (step == PairStep.connecting) ...[
                  const LineArtView(LineArt.pairing, size: 120),
                  const SizedBox(height: KSpace.s24),
                  SizedBox.square(dimension: 28, child: CircularProgressIndicator(strokeWidth: 2.5, color: k.accent)),
                  const SizedBox(height: KSpace.s16),
                  Semantics(liveRegion: true, child: Text('Connecting to $phoneName…', style: t.title2)),
                  const SizedBox(height: KSpace.s8),
                  Text('Keep Kheryne open on your phone.', style: t.callout.copyWith(color: k.textSecondary)),
                  const SizedBox(height: KSpace.s24),
                  KButton.secondary(label: 'Cancel', onPressed: c.disconnect),
                ] else ...[
                  const LineArtView(LineArt.offline, size: 120),
                  const SizedBox(height: KSpace.s24),
                  Text('Couldn’t reach your phone', style: t.title2),
                  const SizedBox(height: KSpace.s8),
                  Text('Check that both are on the same Wi-Fi, and that Kheryne is open on the phone.',
                      style: t.callout.copyWith(color: k.textSecondary), textAlign: TextAlign.center),
                  const SizedBox(height: KSpace.s24),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    KButton.secondary(label: 'Show code again', onPressed: c.disconnect),
                    const SizedBox(width: KSpace.s12),
                    KButton(label: 'Try again', icon: KIcons.retry, onPressed: c.simulateScan),
                  ]),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Stream extends ConsumerStatefulWidget {
  const _Stream();

  @override
  ConsumerState<_Stream> createState() => _StreamState();
}

class _StreamState extends ConsumerState<_Stream> with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(vsync: this, duration: const Duration(seconds: 14));
  late final Specimen _s = makeSpecimen(83, capturedAt: ref.read(clockProvider)(), source: CaptureSource.phone, nematodes: 2);
  List<Detection> _dets = const [];

  @override
  void initState() {
    super.initState();
    ref.read(identificationRepositoryProvider).detect(_s).then((d) => mounted ? setState(() => _dets = d) : null);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!reduce && !_drift.isAnimating) _drift.repeat();
    if (reduce) _drift.stop();
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  void _analyzeFrame() {
    ref.read(workspaceProvider.notifier).addFrozenFrame(_s);
    StatefulNavigationShell.maybeOf(context)?.goBranch(Branch.workspace);
    showToast(context, 'Frame added to the Workspace.');
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final t = context.t;
    return Scaffold(
      backgroundColor: k.canvas,
      body: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: KSpace.s16, vertical: KSpace.s12),
          decoration: BoxDecoration(color: k.background, border: Border(bottom: BorderSide(color: k.separator))),
          child: Row(children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: k.success, shape: BoxShape.circle)),
            const SizedBox(width: KSpace.s8),
            Text('Connected to $phoneName', style: t.subhead),
            const SizedBox(width: KSpace.s16),
            Icon(KIcons.wifi, size: 16, color: k.textSecondary),
            const SizedBox(width: KSpace.s4),
            Text('38 ms · 30 fps', style: t.caption.copyWith(fontFeatures: KType.tabular)),
            const Spacer(),
            KButton.tertiary(label: 'Disconnect', size: KButtonSize.compact, onPressed: ref.read(pairingProvider.notifier).disconnect),
            const SizedBox(width: KSpace.s8),
            KButton(label: 'Analyze this frame', icon: KIcons.frame, size: KButtonSize.compact, onPressed: _analyzeFrame),
          ]),
        ),
        Expanded(
          child: LayoutBuilder(builder: (context, c) {
            return AnimatedBuilder(
              animation: _drift,
              builder: (context, _) {
                final v = _drift.value * 2 * math.pi;
                final drift = Offset(math.sin(v) * 0.01, math.cos(v) * 0.007);
                final side = math.min(c.maxWidth, c.maxHeight);
                final o = Offset((c.maxWidth - side) / 2, (c.maxHeight - side) / 2);
                return Stack(children: [
                  Positioned(left: o.dx, top: o.dy, width: side, height: side, child: Micrograph(specimen: _s, fit: BoxFit.fill, drift: drift)),
                  for (final d in _dets)
                    Positioned.fromRect(
                      rect: Rect.fromLTRB(o.dx + (d.rect.left + drift.dx) * side, o.dy + (d.rect.top + drift.dy) * side,
                          o.dx + (d.rect.right + drift.dx) * side, o.dy + (d.rect.bottom + drift.dy) * side),
                      child: Semantics(label: boxSemantics(d), child: DetectionBox(detection: d, longLabel: false)),
                    ),
                  Positioned(
                    left: KSpace.s16,
                    bottom: KSpace.s16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: KSpace.s12, vertical: 6),
                      decoration: BoxDecoration(color: k.canvas.withValues(alpha: 0.7), borderRadius: KRadius.pill),
                      child: Text('${_dets.length} candidates · 40× objective', style: t.captionStrong.copyWith(color: k.overlayText)),
                    ),
                  ),
                ]);
              },
            );
          }),
        ),
      ]),
    );
  }
}
