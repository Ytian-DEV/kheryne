import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/layout/app_shell.dart';
import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/router/routes.dart';
import '../../core/theme/theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import '../../mock/specimens.dart';
import '../scan/photo_picker_sheet.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider)();
    final settings = ref.watch(settingsProvider);
    final history = ref.watch(historyProvider);
    final online = ref.watch(onlineProvider) && ViewStateScope.of(context) != ViewState.offline;

    return LargeTitleScaffold(
      title: '${greeting(now)}, ${settings.firstName}',
      subtitle: longDate(now),
      showBack: false,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: KSpace.s8),
          child: StatusChip(
            label: online ? 'Offline ready' : 'Offline · models on device',
            icon: online ? KIcons.offlineReady : KIcons.offline,
            color: online ? context.k.success : context.k.textSecondary,
          ),
        ),
      ],
      slivers: [
        const SliverToBoxAdapter(child: OfflineNotice()),
        SliverToBoxAdapter(child: _ScanHero(now: now)),
        const SliverToBoxAdapter(child: SizedBox(height: KSpace.s12)),
        SliverToBoxAdapter(
          child: Row(
            children: [
              Expanded(
                child: _ActionCard(
                  icon: KIcons.upload,
                  title: 'Upload photo',
                  subtitle: 'From your gallery',
                  onTap: () async {
                    final s = await pickPhoto(context);
                    if (s != null && context.mounted) context.pushTo(Routes.identify(s.id));
                  },
                ),
              ),
              const SizedBox(width: KSpace.s12),
              Expanded(
                child: _ActionCard(
                  icon: KIcons.batch,
                  title: 'Batch',
                  subtitle: 'Several slides at once',
                  onTap: () => context.pushTo(Routes.batch),
                ),
              ),
            ],
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: KSpace.s32)),
        SliverToBoxAdapter(
          child: SectionTitle('Recent identifications',
              action: 'See all', onAction: () => StatefulNavigationShell.maybeOf(context)?.goBranch(Branch.history)),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: KSpace.s12)),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 212,
            child: AsyncView<List<Report>>(
              value: history,
              onRetry: () => ref.invalidate(historyProvider),
              error: KCard(
                child: Row(children: [
                  const LineArtView(LineArt.brokenSlide, size: 56),
                  const SizedBox(width: KSpace.s16),
                  Expanded(child: Text('Couldn’t load recent identifications.', style: context.t.callout)),
                  KButton.tertiary(label: 'Try again', onPressed: () => ref.invalidate(historyProvider), size: KButtonSize.compact),
                ]),
              ),
              loading: ListView(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                children: List.generate(
                    3,
                    (_) => const Padding(
                          padding: EdgeInsets.only(right: KSpace.s12),
                          child: SizedBox(
                            width: 156,
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              SkeletonBlock(height: 104, radius: KRadius.card),
                              SizedBox(height: KSpace.s12),
                              SkeletonBlock(width: 110, height: 14),
                              SizedBox(height: KSpace.s8),
                              SkeletonBlock(width: 80, height: 12),
                              SizedBox(height: KSpace.s8),
                              SkeletonBlock(width: 52, height: 20, radius: KRadius.full),
                            ]),
                          ),
                        )),
              ),
              isEmpty: (l) => l.isEmpty,
              empty: KCard(
                child: Row(children: [
                  const LineArtView(LineArt.emptySlide, size: 56),
                  const SizedBox(width: KSpace.s16),
                  Expanded(child: Text('No identifications yet.', style: context.t.callout)),
                  KButton.tertiary(label: 'Start a scan', onPressed: () => context.pushTo(Routes.scan), size: KButtonSize.compact),
                ]),
              ),
              data: (list) => ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: list.length.clamp(0, 8),
                separatorBuilder: (_, _) => const SizedBox(width: KSpace.s12),
                itemBuilder: (context, i) => _RecentCard(report: list[i]),
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: KSpace.s24)),
        SliverToBoxAdapter(
          child: KListSection(header: 'TOOLS', children: [
            KListRow(title: 'Dichotomous key', leading: KIcons.key, onTap: () => context.pushTo(Routes.key())),
            KListRow(title: 'Calibrate magnification', leading: KIcons.ruler, onTap: () => context.pushTo(Routes.calibrate)),
            KListRow(title: 'Pair with computer', leading: KIcons.pair, onTap: () => context.pushTo(Routes.pairPhone)),
          ]),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 96)),
      ],
    );
  }
}

class _ScanHero extends StatelessWidget {
  const _ScanHero({required this.now});
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final k = context.k;
    return KCard(
      padding: EdgeInsets.zero,
      radius: KRadius.hero,
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 168,
            child: Micrograph(specimen: makeSpecimen(29, capturedAt: now, nematodes: 2), semanticLabel: 'Sample micrograph'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(KSpace.s20, KSpace.s16, KSpace.s20, KSpace.s20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Start live scan', style: t.title2),
                const SizedBox(height: KSpace.s8),
                Text('Clip your phone to the eyepiece. Kheryne marks likely nematodes while you move the slide.',
                    style: t.callout.copyWith(color: k.textSecondary)),
                const SizedBox(height: KSpace.s16),
                KButton(label: 'Start live scan', icon: KIcons.scan, expand: true, onPressed: () => context.pushTo(Routes.scan)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final t = context.t;
    return KCard(
      onTap: onTap,
      semanticLabel: '$title. $subtitle',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: k.container, borderRadius: KRadius.smAll),
            child: Icon(icon, size: KSize.icon, color: k.primaryStrong),
          ),
          const SizedBox(height: KSpace.s12),
          Text(title, style: t.headline),
          const SizedBox(height: 2),
          Text(subtitle, style: t.caption),
        ],
      ),
    );
  }
}

class _RecentCard extends ConsumerWidget {
  const _RecentCard({required this.report});
  final Report report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    return SizedBox(
      width: 156,
      child: KCard(
        padding: EdgeInsets.zero,
        clip: true,
        onTap: () => context.pushTo(Routes.report(report.id)),
        semanticLabel: '${report.genus}, ${percent(report.classification.genus.confidence)}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 104, width: double.infinity, child: Micrograph(specimen: report.specimen)),
            Padding(
              padding: const EdgeInsets.fromLTRB(KSpace.s12, 10, KSpace.s12, KSpace.s12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GenusName(report.genus, style: t.calloutStrong),
                  Text(report.classification.family.name, style: t.caption.copyWith(fontSize: 12), maxLines: 1),
                  const SizedBox(height: 6),
                  ConfidencePill(report.classification.genus.confidence, compact: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
