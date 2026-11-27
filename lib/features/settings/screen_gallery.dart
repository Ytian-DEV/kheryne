import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import '../../core/layout/form_factor.dart';
import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/router/routes.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import '../batch/batch_controller.dart';
import '../batch/batch_screen.dart';
import '../home/onboarding_screen.dart';
import '../identify/analysis_screen.dart';
import '../identify/identification_screen.dart';
import '../identify/identify_controller.dart';
import '../pairing/desktop_live_screen.dart';
import '../pairing/phone_pair_screen.dart';
import '../report/trait_sheet.dart';
import '../scan/capture_review_screen.dart';
import '../scan/live_scan_screen.dart';
import '../workspace/workspace_controller.dart';

typedef Reader = T Function<T>(ProviderListenable<T> provider);

enum GalleryPlatform { phone, desktop, both }

/// One screen (and the states it supports) in the hidden screen gallery.
/// Also drives the screenshot tests.
@immutable
class GalleryEntry {
  const GalleryEntry(
    this.id,
    this.title,
    this.group, {
    this.location,
    this.platform = GalleryPlatform.phone,
    this.states = const [ViewState.content],
    this.setup,
  });

  final String id;
  final String title;
  final String group;

  /// Route to open; null means `/dev/preview/<id>` (see [previewBuilders]).
  final String? location;
  final GalleryPlatform platform;
  final List<ViewState> states;
  final Future<void> Function(Reader read)? setup;

  String get route => location ?? '/dev/preview/$id';
  bool supports(bool desktop) => platform == GalleryPlatform.both || (platform == GalleryPlatform.desktop) == desktop;
}

const _all = [ViewState.content, ViewState.loading, ViewState.empty, ViewState.error, ViewState.offline];
const _cle = [ViewState.content, ViewState.loading, ViewState.error];

Future<void> _seedIdentify(Reader read) async {
  final repo = read(identificationRepositoryProvider);
  final s = (await repo.specimen('sp-39'))!;
  final d = await repo.detect(s);
  final boxes = <Detection>[
    Detection(id: d[0].id, rect: d[0].rect, kind: BoxKind.confirmed, confidence: 0.91),
    ...d.skip(1),
    const Detection(id: 'd9', rect: Rect.fromLTRB(0.17, 0.24, 0.29, 0.36), kind: BoxKind.rejected, confidence: 0.82, rejectReason: 'Debris'),
    const Detection(id: 'u1', rect: Rect.fromLTRB(0.56, 0.6, 0.76, 0.74), kind: BoxKind.user),
  ];
  read(identifyControllerProvider(s.id).notifier).seed(IdentifyState(specimen: s, detections: boxes, selectedId: 'u1', loading: false));
}

Future<void> _seedBatch(Reader read) async {
  final repo = read(identificationRepositoryProvider);
  final specimens = await repo.specimens();
  final history = await repo.history();
  read(batchProvider.notifier).seed(BatchState(items: demoBatch(specimens, history)));
}

Future<void> _seedBatchRunning(Reader read) async {
  final repo = read(identificationRepositoryProvider);
  final specimens = await repo.specimens();
  final history = await repo.history();
  final items = demoBatch(specimens, history);
  read(batchProvider.notifier).seed(BatchState(running: true, items: [
    for (var i = 0; i < items.length; i++)
      i < 3 ? items[i] : (i == 3 ? BatchItem(specimen: items[i].specimen, status: BatchStatus.running, progress: 0.45) : BatchItem(specimen: items[i].specimen)),
  ]));
}

Future<void> _seedWorkspace(Reader read, {bool running = false}) async {
  final repo = read(identificationRepositoryProvider);
  final specimens = (await repo.specimens()).take(8).toList();
  final s = specimens[2];
  final d = await repo.detect(s);
  final report = (await repo.history()).first;
  read(pendingReportsProvider.notifier).put(report);
  read(identifyControllerProvider(s.id).notifier).seed(IdentifyState(
    specimen: s,
    detections: [
      for (var i = 0; i < d.length; i++)
        i == 0 ? Detection(id: d[i].id, rect: d[i].rect, kind: BoxKind.confirmed, confidence: 0.9) : d[i],
      const Detection(id: 'u1', rect: Rect.fromLTRB(0.62, 0.2, 0.8, 0.34), kind: BoxKind.user),
    ],
    selectedId: d.isEmpty ? null : d.first.id,
    loading: false,
  ));
  read(workspaceProvider.notifier).seed(WorkspaceState(
    images: specimens,
    selectedId: s.id,
    loading: false,
    tab: InspectorTab.report,
    runs: {
      s.id: running
          ? WorkspaceRun(detectionId: d.first.id, stage: AnalysisStage.family, progress: 0.5)
          : WorkspaceRun(detectionId: d.first.id, stage: AnalysisStage.done, progress: 1, reportId: report.id),
    },
  ));
}

Future<void> Function(Reader) _pair(PairStep s) => (read) async => read(pairingProvider.notifier).set(s);

final galleryEntries = <GalleryEntry>[
  // Android
  const GalleryEntry('onboarding-1', 'Onboarding · What it does', 'Android'),
  const GalleryEntry('onboarding-2', 'Onboarding · Clip to eyepiece', 'Android'),
  const GalleryEntry('onboarding-3', 'Onboarding · Offline models', 'Android'),
  const GalleryEntry('auth', 'Sign in & cloud sync', 'Both', location: Routes.auth, platform: GalleryPlatform.both),
  const GalleryEntry('home', 'Home', 'Android', location: Routes.home, states: _all),
  const GalleryEntry('live-scan', 'Live Scan', 'Android'),
  const GalleryEntry('live-blurry', 'Live Scan · Blurry', 'Android'),
  const GalleryEntry('live-dark', 'Live Scan · Too dark', 'Android'),
  GalleryEntry('zoom', 'Zoomed specimen', 'Android', location: Routes.zoom('sp-77', 'ai-0')),
  GalleryEntry('capture-review', 'Capture review', 'Android', location: Routes.captureReview('sp-11'), states: _cle),
  const GalleryEntry('capture-issues', 'Capture review · Issues', 'Android'),
  GalleryEntry('editor', 'Image editor', 'Android', location: Routes.editor('sp-25')),
  GalleryEntry('identify', 'Identification mode', 'Android', location: Routes.identify('sp-25'), states: _cle),
  const GalleryEntry('identify-states', 'Identification · All box states', 'Android', setup: _seedIdentify),
  const GalleryEntry('analysis', 'Analysis in progress', 'Android', states: [ViewState.content, ViewState.error]),
  GalleryEntry('report', 'Report', 'Android', location: Routes.report('r-100'), states: [ViewState.content, ViewState.loading, ViewState.empty, ViewState.error, ViewState.offline]),
  GalleryEntry('report-uncertain', 'Report · Uncertain', 'Android', location: Routes.report('r-107')),
  const GalleryEntry('trait-sheet', 'Trait detail sheet', 'Android'),
  const GalleryEntry('calibration', 'Calibration', 'Both', location: Routes.calibrate, platform: GalleryPlatform.both),
  GalleryEntry('measure', 'Measure', 'Both', location: Routes.measure('sp-500', reportId: 'r-100'), platform: GalleryPlatform.both),
  GalleryEntry('key', 'Dichotomous key', 'Android', location: Routes.key()),
  GalleryEntry('key-prefilled', 'Key · From report', 'Android', location: Routes.key(fromReport: 'r-100')),
  const GalleryEntry('batch-empty', 'Batch · Pick images', 'Android', location: Routes.batch),
  const GalleryEntry('batch-running', 'Batch · Queue', 'Android', location: Routes.batch, setup: _seedBatchRunning),
  const GalleryEntry('batch-done', 'Batch · Summary', 'Android', location: Routes.batch, setup: _seedBatch),
  const GalleryEntry('history', 'History', 'Android', location: Routes.history, states: _all),
  GalleryEntry('history-detail', 'History detail', 'Android', location: Routes.historyDetail('r-100'), states: _cle),
  const GalleryEntry('gallery', 'Reference gallery', 'Android', location: Routes.gallery, states: _all),
  GalleryEntry('genus', 'Genus detail', 'Android', location: Routes.genus('Pratylenchus'), states: [ViewState.content, ViewState.offline]),
  GalleryEntry('genus-reference', 'Genus detail · Reference only', 'Android', location: Routes.genus('Meloidoderella')),
  GalleryEntry('pdf', 'PDF export preview', 'Both', location: Routes.reportPdf('r-100'), platform: GalleryPlatform.both),
  const GalleryEntry('settings', 'Settings', 'Both', location: Routes.settings, platform: GalleryPlatform.both, states: [ViewState.content, ViewState.offline]),
  const GalleryEntry('settings-models', 'Offline models', 'Both', location: Routes.settingsModels, platform: GalleryPlatform.both, states: [ViewState.content, ViewState.offline]),
  const GalleryEntry('settings-calibration', 'Calibration profiles', 'Both', location: Routes.settingsCalibration, platform: GalleryPlatform.both, states: [ViewState.content, ViewState.empty]),
  const GalleryEntry('settings-privacy', 'Privacy', 'Both', location: Routes.settingsPrivacy, platform: GalleryPlatform.both),
  const GalleryEntry('settings-about', 'About', 'Both', location: Routes.settingsAbout, platform: GalleryPlatform.both),
  const GalleryEntry('pair-phone', 'Pair with computer · Scan', 'Android', location: Routes.pairPhone),
  const GalleryEntry('pair-phone-streaming', 'Pair with computer · Streaming', 'Android'),
  // Windows
  const GalleryEntry('workspace', 'Workspace', 'Windows', location: Routes.workspace, platform: GalleryPlatform.desktop, states: [ViewState.content, ViewState.loading, ViewState.empty]),
  const GalleryEntry('workspace-report', 'Workspace · Report', 'Windows', location: Routes.workspace, platform: GalleryPlatform.desktop, setup: _seedWorkspace),
  GalleryEntry('workspace-running', 'Workspace · Analyzing', 'Windows', location: Routes.workspace, platform: GalleryPlatform.desktop, setup: (r) => _seedWorkspace(r, running: true)),
  const GalleryEntry('import', 'Import', 'Windows', location: Routes.import, platform: GalleryPlatform.desktop),
  GalleryEntry('live-code', 'Live · Pairing code', 'Windows', location: Routes.live, platform: GalleryPlatform.desktop, setup: _pair(PairStep.code)),
  GalleryEntry('live-connecting', 'Live · Connecting', 'Windows', location: Routes.live, platform: GalleryPlatform.desktop, setup: _pair(PairStep.connecting)),
  GalleryEntry('live-connected', 'Live · Streaming', 'Windows', location: Routes.live, platform: GalleryPlatform.desktop, setup: _pair(PairStep.connected)),
  GalleryEntry('live-error', 'Live · Couldn’t reach phone', 'Windows', location: Routes.live, platform: GalleryPlatform.desktop, setup: _pair(PairStep.error)),
  GalleryEntry('compare', 'Compare', 'Windows', location: Routes.compare('sp-25', 'Pratylenchus'), platform: GalleryPlatform.desktop),
  const GalleryEntry('batch-desktop', 'Batch · Empty', 'Windows', location: Routes.batchDesktop, platform: GalleryPlatform.desktop),
  const GalleryEntry('batch-desktop-done', 'Batch · Results', 'Windows', location: Routes.batchDesktop, platform: GalleryPlatform.desktop, setup: _seedBatch),
  const GalleryEntry('history-desktop', 'History', 'Windows', location: Routes.history, platform: GalleryPlatform.desktop, states: _all),
  const GalleryEntry('gallery-desktop', 'Reference gallery', 'Windows', location: Routes.gallery, platform: GalleryPlatform.desktop, states: _cle),
  const GalleryEntry('key-desktop', 'Dichotomous key', 'Windows', location: Routes.keyDesktop, platform: GalleryPlatform.desktop),
  GalleryEntry('report-full', 'Full report', 'Windows', location: Routes.reportFull('r-100'), platform: GalleryPlatform.desktop, states: _cle),
];

/// Builders for entries that are not plain routes.
final Map<String, Widget Function()> previewBuilders = {
  'onboarding-1': () => const OnboardingScreen(),
  'onboarding-2': () => const OnboardingScreen(initialPage: 1),
  'onboarding-3': () => const OnboardingScreen(initialPage: 2),
  'live-scan': () => const LiveScanScreen(animate: false),
  'live-blurry': () => const LiveScanScreen(animate: false, guidance: CaptureGuidance.blurry),
  'live-dark': () => const LiveScanScreen(animate: false, guidance: CaptureGuidance.dark),
  'capture-issues': () => const CaptureReviewScreen(specimenId: 'sp-11', forceIssues: true),
  'identify-states': () => const IdentificationScreen(specimenId: 'sp-39', popoverFor: 'u1'),
  'analysis': () => const AnalysisScreen(specimenId: 'sp-25', detectionId: 'ai-0', freezeAt: AnalysisStage.tail),
  'trait-sheet': () => const _TraitSheetPreview(),
  'pair-phone-streaming': () => const PhonePairScreen(initial: PhonePairStep.streaming),
};

class _TraitSheetPreview extends ConsumerWidget {
  const _TraitSheetPreview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(reportProvider('r-100')).value;
    return Scaffold(
      backgroundColor: context.k.scrim,
      body: r == null
          ? const SizedBox.shrink()
          : Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: 0.78,
                child: Container(
                  decoration: BoxDecoration(color: context.k.surface, borderRadius: KRadius.sheetTop),
                  child: Column(children: [
                    const SizedBox(height: KSpace.s8),
                    Container(width: 36, height: 5, decoration: BoxDecoration(color: context.k.textSecondary.withValues(alpha: 0.35), borderRadius: KRadius.pill)),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(KSpace.s20, KSpace.s12, KSpace.s20, KSpace.s4),
                      child: Align(alignment: Alignment.centerLeft, child: Text(r.traits.first.name, style: context.t.headline)),
                    ),
                    Expanded(child: TraitDetail(report: r, trait: r.traits.first)),
                  ]),
                ),
              ),
            ),
    );
  }
}

class PreviewScreen extends StatelessWidget {
  const PreviewScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) => previewBuilders[id]?.call() ?? Scaffold(body: Center(child: Text('Unknown preview “$id”')));
}

/// Hidden screen gallery: every screen and state, for review and thesis
/// screenshots. Settings → About → tap the version 5 times, or launch
/// with `--dart-define=GALLERY=true`.
class ScreenGalleryScreen extends ConsumerWidget {
  const ScreenGalleryScreen({super.key});

  Future<void> _open(BuildContext context, WidgetRef ref, GalleryEntry e, ViewState state) async {
    ref.read(forcedViewStateProvider.notifier).set(state == ViewState.content ? null : state);
    ref.read(onlineProvider.notifier).set(state != ViewState.offline);
    if (e.setup != null) await e.setup!(ref.read);
    if (context.mounted) await context.pushTo(e.route);
    ref.read(forcedViewStateProvider.notifier).set(null);
    ref.read(onlineProvider.notifier).set(true);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ff = ref.watch(formFactorProvider);
    final mode = ref.watch(settingsProvider).themeMode;
    final t = context.t;
    final k = context.k;
    final groups = <String, List<GalleryEntry>>{};
    for (final e in galleryEntries.where((e) => e.supports(ff.isDesktop))) {
      (groups[e.group] ??= []).add(e);
    }
    return LargeTitleScaffold(
      title: 'Screen gallery',
      maxContentWidth: 820,
      header: Column(children: [
        KSegmentedControl<bool>(
          segments: const [(false, 'Phone layout', KIcons.phone), (true, 'Desktop layout', KIcons.desktop)],
          value: ff.isDesktop,
          onChanged: (v) => ref.read(formFactorProvider.notifier).set(FormFactor(isDesktop: v)),
        ),
        const SizedBox(height: KSpace.s8),
        KSegmentedControl<ThemeMode>(
          segments: const [(ThemeMode.system, 'System', null), (ThemeMode.light, 'Light', null), (ThemeMode.dark, 'Dark', null)],
          value: mode,
          onChanged: (m) => ref.read(settingsProvider.notifier).update((s) => s.copyWith(themeMode: m)),
        ),
        const SizedBox(height: KSpace.s8),
        Row(children: [
          Expanded(child: Text('${galleryEntries.length} screens. Tap a state to open it.', style: t.caption)),
          KButton.tertiary(label: 'Component sheet', size: KButtonSize.compact, onPressed: () => context.pushTo(Routes.components)),
        ]),
      ]),
      slivers: [
        SliverList.list(children: [
          for (final g in groups.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(KSpace.s4, KSpace.s16, KSpace.s4, KSpace.s8),
              child: Text(g.key.toUpperCase(), style: t.sectionHeader),
            ),
            ClipRRect(
              borderRadius: KRadius.cardAll,
              child: ColoredBox(
                color: k.surface,
                child: Column(children: [
                  for (final e in g.value)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: KSpace.s16, vertical: KSpace.s12),
                      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: k.separator, width: KSize.hairline))),
                      child: Row(children: [
                        Expanded(child: Text(e.title, style: t.callout)),
                        Wrap(spacing: KSpace.s4, runSpacing: KSpace.s4, children: [
                          for (final s in e.states)
                            TraitChip(
                              label: switch (s) {
                                ViewState.content => 'Open',
                                ViewState.loading => 'Loading',
                                ViewState.empty => 'Empty',
                                ViewState.error => 'Error',
                                ViewState.offline => 'Offline',
                              },
                              selected: s == ViewState.content,
                              onTap: () => _open(context, ref, e, s),
                            ),
                        ]),
                      ]),
                    ),
                ]),
              ),
            ),
          ],
        ]),
      ],
    );
  }
}
