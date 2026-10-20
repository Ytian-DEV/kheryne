import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/router/routes.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';

/// Analysis in progress: live step list, cancel.
class AnalysisScreen extends ConsumerStatefulWidget {
  const AnalysisScreen({super.key, required this.specimenId, required this.detectionId, this.freezeAt});
  final String specimenId;
  final String detectionId;

  /// Screen gallery: show a fixed step instead of running.
  final AnalysisStage? freezeAt;

  @override
  ConsumerState<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends ConsumerState<AnalysisScreen> {
  StreamSubscription<AnalysisProgress>? _sub;
  AnalysisProgress _p = const AnalysisProgress(AnalysisStage.regions, 0);
  Specimen? _specimen;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    if (widget.freezeAt != null) {
      _p = AnalysisProgress(widget.freezeAt!, 0.5);
      ref.read(identificationRepositoryProvider).specimen(widget.specimenId).then((s) => mounted ? setState(() => _specimen = s) : null);
    } else {
      unawaited(_start());
    }
  }

  Future<void> _start() async {
    setState(() => _failed = false);
    final repo = ref.read(identificationRepositoryProvider);
    try {
      final s = await repo.specimen(widget.specimenId);
      if (s == null) throw StateError('missing');
      final dets = await repo.detect(s);
      final d = dets.where((d) => d.id == widget.detectionId).firstOrNull ??
          Detection(id: widget.detectionId, rect: s.worms.first.bounds, kind: BoxKind.confirmed);
      if (!mounted) return;
      setState(() => _specimen = s);
      _sub = repo.analyze(s, d).listen((p) {
        if (!mounted) return;
        setState(() => _p = p);
        if (p.report != null) {
          ref.read(pendingReportsProvider.notifier).put(p.report!);
          context.pushReplacement(Routes.report(p.report!.id));
        }
      }, onError: (_) => mounted ? setState(() => _failed = true) : null);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final t = context.t;
    const stages = [
      AnalysisStage.regions,
      AnalysisStage.head,
      AnalysisStage.tail,
      AnalysisStage.order,
      AnalysisStage.family,
      AnalysisStage.genus,
    ];
    final current = stages.indexOf(_p.stage);
    final overall = _p.stage == AnalysisStage.done ? 1.0 : (current + _p.stageProgress) / stages.length;
    final failed = _failed || ViewStateScope.of(context) == ViewState.error;

    return Scaffold(
      appBar: const KNavBar(title: 'Analyzing', showBack: false),
      body: failed
          ? ErrorState(
              title: 'Analysis stopped',
              message: 'Kheryne couldn’t read this specimen. Try again, or draw a tighter box around the body.',
              onRetry: _start,
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(KSpace.s16, KSpace.s8, KSpace.s16, KSpace.s24),
              children: [
                ClipRRect(
                  borderRadius: KRadius.heroAll,
                  child: SizedBox(
                    height: 180,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (_specimen != null || widget.freezeAt != null)
                          Micrograph(specimen: _specimen ?? _placeholderSpecimen(ref))
                        else
                          const SkeletonBlock(height: 180, radius: 0),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: LinearProgressIndicator(value: overall, minHeight: 4, color: k.accent, backgroundColor: k.container),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: KSpace.s20),
                Semantics(
                  liveRegion: true,
                  child: Text(_p.stage.label, style: t.title2),
                ),
                const SizedBox(height: KSpace.s4),
                Text('This takes a few seconds and runs on this device.', style: t.caption),
                const SizedBox(height: KSpace.s20),
                KListSection(
                  children: [
                    for (var i = 0; i < stages.length; i++)
                      _StepRow(label: stages[i].label, state: i < current || _p.stage == AnalysisStage.done ? 2 : (i == current ? 1 : 0), progress: _p.stageProgress),
                  ],
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(KSpace.s16, KSpace.s8, KSpace.s16, KSpace.s12),
          child: KButton.secondary(
            label: 'Cancel',
            expand: true,
            onPressed: () {
              _sub?.cancel();
              Navigator.of(context).maybePop();
            },
          ),
        ),
      ),
    );
  }

  Specimen _placeholderSpecimen(WidgetRef ref) => Specimen(
        id: 'placeholder',
        seed: 3,
        fileName: '',
        objective: 40,
        worms: const [],
        capturedAt: ref.read(clockProvider)(),
      );
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.label, required this.state, required this.progress});
  final String label;

  /// 0 pending, 1 running, 2 done.
  final int state;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final t = context.t;
    final icon = switch (state) {
      2 => Icon(KIcons.checkCircle, color: k.success, size: KSize.iconLg),
      1 => SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(strokeWidth: 2.2, value: progress == 0 ? null : progress, color: k.accent),
        ),
      _ => Icon(KIcons.pending, color: k.textSecondary.withValues(alpha: 0.5), size: KSize.iconLg),
    };
    return Semantics(
      label: '$label, ${switch (state) { 2 => 'done', 1 => 'in progress', _ => 'waiting' }}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: KSpace.s16, vertical: 14),
        child: Row(
          children: [
            SizedBox(width: 24, child: Center(child: icon)),
            const SizedBox(width: KSpace.s12),
            Expanded(
              child: Text(label,
                  style: t.bodyStyle.copyWith(
                      color: state == 0 ? k.textSecondary : k.text, fontWeight: state == 1 ? FontWeight.w600 : FontWeight.w400)),
            ),
          ],
        ),
      ),
    );
  }
}
