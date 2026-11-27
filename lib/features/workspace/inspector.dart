import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/router/routes.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import '../identify/box_actions.dart';
import '../identify/identify_controller.dart';
import '../report/report_parts.dart';
import '../scan/adjust_panel.dart';
import '../scan/filters.dart';
import 'workspace_controller.dart';

/// Right-hand inspector: Adjust, Detections, Report, Measure.
class Inspector extends ConsumerWidget {
  const Inspector({super.key, required this.specimen});
  final Specimen? specimen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = context.k;
    final t = context.t;
    final ws = ref.watch(workspaceProvider);
    final c = ref.read(workspaceProvider.notifier);
    final s = specimen;
    Widget body;
    if (s == null) {
      body = Padding(
        padding: const EdgeInsets.only(top: KSpace.s40),
        child: Text('Import or select an image to inspect it.', style: t.caption, textAlign: TextAlign.center),
      );
    } else {
      body = switch (ws.tab) {
        InspectorTab.adjust => AdjustPanel(
            dense: true,
            value: ref.watch(adjustmentsProvider)[s.id] ?? ImageAdjustments.none,
            onChanged: (a) => ref.read(adjustmentsProvider.notifier).set(s.id, a),
          ),
        InspectorTab.detections => _Detections(specimen: s),
        InspectorTab.report => _ReportTab(specimen: s),
        InspectorTab.measure => _MeasureTab(specimen: s),
      };
    }
    return ColoredBox(
      color: k.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(KSpace.s12, KSpace.s12, KSpace.s12, 0),
            child: KSegmentedControl<InspectorTab>(
              segments: const [
                (InspectorTab.adjust, 'Adjust', null),
                (InspectorTab.detections, 'Detections', null),
                (InspectorTab.report, 'Report', null),
                (InspectorTab.measure, 'Measure', null),
              ],
              value: ws.tab,
              onChanged: c.setTab,
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(KSpace.s16, KSpace.s16, KSpace.s16, KSpace.s24),
              children: [body],
            ),
          ),
        ],
      ),
    );
  }
}

class _Detections extends ConsumerWidget {
  const _Detections({required this.specimen});
  final Specimen specimen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = context.k;
    final t = context.t;
    final st = ref.watch(identifyControllerProvider(specimen.id));
    final c = ref.read(identifyControllerProvider(specimen.id).notifier);
    if (st.loading) {
      return Column(children: [for (var i = 0; i < 3; i++) const Padding(padding: EdgeInsets.only(bottom: KSpace.s8), child: SkeletonBlock(height: 52, radius: KRadius.card))]);
    }
    final pending = st.detections.where((d) => d.kind == BoxKind.ai || d.kind == BoxKind.user).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(st.summary, style: t.captionStrong),
        const SizedBox(height: KSpace.s8),
        if (st.detections.isEmpty)
          Text('No candidates found. Draw a box (B) around anything you think is a nematode.', style: t.caption)
        else
          ClipRRect(
            borderRadius: KRadius.cardAll,
            child: ColoredBox(
              color: k.background,
              child: Column(children: [
                for (final d in st.detections)
                  KListRow(
                    title: boxLabel(d, long: true),
                    subtitle: d.kind == BoxKind.rejected ? d.rejectReason : (d.id.startsWith('u') ? 'Drawn by you' : 'Found by Kheryne'),
                    leading: switch (d.kind) {
                      BoxKind.confirmed => KIcons.checkCircle,
                      BoxKind.rejected => KIcons.xCircle,
                      BoxKind.user => KIcons.drawBox,
                      BoxKind.ai => KIcons.crosshair,
                    },
                    leadingColor: d.kind.color(k),
                    selected: d.id == st.selectedId,
                    chevron: false,
                    onTap: () => c.select(d.id),
                  ),
              ]),
            ),
          ),
        const SizedBox(height: KSpace.s12),
        if (st.selected != null) ...[
          for (final a in boxActions(
            st.selected!,
            onCheck: () => c.check(st.selected!.id),
            onAnalyze: () => ref.read(workspaceProvider.notifier).analyze(specimen, st.selected!),
            onRemove: () => c.remove(st.selected!.id),
          ))
            Padding(
              padding: const EdgeInsets.only(bottom: KSpace.s8),
              child: KButton(
                label: a.label,
                icon: a.icon,
                expand: true,
                size: KButtonSize.compact,
                variant: a.destructive ? KButtonVariant.destructive : (a.primary ? KButtonVariant.primary : KButtonVariant.secondary),
                onPressed: a.onTap,
              ),
            ),
        ] else if (pending.isNotEmpty)
          KButton.secondary(
            label: 'Check all ${pending.length} candidates',
            icon: KIcons.checkCircle,
            expand: true,
            size: KButtonSize.compact,
            onPressed: () {
              for (final d in pending) {
                c.check(d.id);
              }
            },
          ),
      ],
    );
  }
}

class _ReportTab extends ConsumerWidget {
  const _ReportTab({required this.specimen});
  final Specimen specimen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = context.k;
    final t = context.t;
    final ws = ref.watch(workspaceProvider);
    final run = ws.runs[specimen.id];
    if (ws.lastError != null && run == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StatusBanner(
            title: 'Model or ML server required',
            message: ws.lastError,
            tone: BannerTone.warning,
            icon: KIcons.warning,
          ),
          const SizedBox(height: KSpace.s12),
          KButton.secondary(
            label: 'Submit slide to Scientist Review Queue',
            icon: KIcons.flask,
            expand: true,
            size: KButtonSize.compact,
            onPressed: () async {
              final dets = ref.read(identifyControllerProvider(specimen.id)).detections;
              try {
                await ref.read(trainingRepositoryProvider).submitUserDetectionSample(
                      specimen: specimen,
                      detections: dets,
                    );
                if (context.mounted) showToast(context, 'Submitted slide to Scientist Review Queue.');
              } catch (_) {
                if (context.mounted) showToast(context, 'Sign in first to submit slides.');
              }
            },
          ),
          const SizedBox(height: KSpace.s8),
          KButton.tertiary(
            label: 'Open Lab Dataset & Review Queue',
            icon: KIcons.external,
            expand: true,
            size: KButtonSize.compact,
            onPressed: () => context.pushTo(Routes.training),
          ),
        ],
      );
    }
    if (run == null) {
      return Column(children: [
        const SizedBox(height: KSpace.s24),
        const LineArtView(LineArt.microscope, size: 72),
        const SizedBox(height: KSpace.s12),
        Text('No report yet', style: t.headline),
        const SizedBox(height: KSpace.s4),
        Text('Check a candidate, then select the green box and press Identify.', style: t.caption, textAlign: TextAlign.center),
      ]);
    }
    if (run.running) {
      const stages = [AnalysisStage.regions, AnalysisStage.head, AnalysisStage.tail, AnalysisStage.order, AnalysisStage.family, AnalysisStage.genus];
      final i = stages.indexOf(run.stage);
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Semantics(liveRegion: true, child: Text(run.stage.label, style: t.headline)),
        const SizedBox(height: KSpace.s8),
        ClipRRect(borderRadius: KRadius.pill, child: LinearProgressIndicator(value: (i + run.progress) / stages.length, minHeight: 4, color: k.accent)),
        const SizedBox(height: KSpace.s12),
        for (var j = 0; j < stages.length; j++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              Icon(j < i ? KIcons.checkCircle : (j == i ? KIcons.scan : KIcons.pending), size: 18, color: j < i ? k.success : (j == i ? k.accent : k.textSecondary)),
              const SizedBox(width: KSpace.s8),
              Text(stages[j].label, style: t.caption.copyWith(color: j <= i ? k.text : k.textSecondary)),
            ]),
          ),
      ]);
    }
    final report = ref.watch(reportProvider(run.reportId!)).value;
    if (report == null) return const SkeletonBlock(height: 300, radius: KRadius.card);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReportHeadline(report: report, large: false),
        if (report.classification.isUncertain) ...[
          const SizedBox(height: KSpace.s12),
          UncertainCard(onOpenKey: () => context.pushTo(Routes.key(fromReport: report.id))),
        ],
        const SizedBox(height: KSpace.s16),
        LadderFor(report: report, dense: true, background: k.background),
        const SizedBox(height: KSpace.s16),
        Text('TRAITS FOUND', style: t.sectionHeader),
        const SizedBox(height: KSpace.s8),
        TraitsList(report: report, dense: true),
        const SizedBox(height: KSpace.s16),
        KButton.secondary(label: 'Open full report', icon: KIcons.external, expand: true, size: KButtonSize.compact, onPressed: () => context.pushTo(Routes.reportFull(report.id))),
        const SizedBox(height: KSpace.s8),
        Row(children: [
          Expanded(child: KButton.tertiary(label: 'Export PDF', icon: KIcons.pdf, size: KButtonSize.compact, onPressed: () => context.pushTo(Routes.reportPdf(report.id)))),
          Expanded(
            child: KButton.tertiary(
              label: 'Save',
              icon: KIcons.save,
              size: KButtonSize.compact,
              onPressed: () async {
                await ref.read(identificationRepositoryProvider).save(report);
                ref.invalidate(historyProvider);
                if (context.mounted) showToast(context, 'Saved to History.');
              },
            ),
          ),
        ]),
        const SizedBox(height: KSpace.s12),
        Text(disclaimer, style: t.micro),
      ],
    );
  }
}

class _MeasureTab extends ConsumerWidget {
  const _MeasureTab({required this.specimen});
  final Specimen specimen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = context.k;
    final t = context.t;
    final cal = ref.watch(settingsProvider).calibrationFor(specimen.objective);
    final run = ref.watch(workspaceProvider).runs[specimen.id];
    final report = run?.reportId == null ? null : ref.watch(reportProvider(run!.reportId!)).value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: KRadius.cardAll,
          child: ColoredBox(
            color: k.background,
            child: Column(children: [
              KListRow(title: 'Objective', value: '${specimen.objective}×'),
              KListRow(
                title: 'Calibration',
                value: cal == null ? 'Not set' : '${cal.micrometresPerPixel.toStringAsFixed(3)} µm/px',
                onTap: () => context.pushTo(Routes.calibrate),
              ),
            ]),
          ),
        ),
        const SizedBox(height: KSpace.s16),
        if (report?.morphometrics != null) ...[
          Text('DE MAN INDICES', style: t.sectionHeader),
          const SizedBox(height: KSpace.s8),
          MorphometricsTable(m: report!.morphometrics!, dense: true),
          const SizedBox(height: KSpace.s16),
        ] else
          Padding(
            padding: const EdgeInsets.only(bottom: KSpace.s16),
            child: Text('Measure body length, width and stylet to compute a, b, c and V%.', style: t.caption),
          ),
        KButton(
          label: 'Open measure tool',
          icon: KIcons.ruler,
          expand: true,
          size: KButtonSize.compact,
          onPressed: () => context.pushTo(Routes.measure(specimen.id, reportId: report?.id)),
        ),
      ],
    );
  }
}
