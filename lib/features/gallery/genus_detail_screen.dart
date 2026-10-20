import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/layout/form_factor.dart';
import '../../core/providers.dart';
import '../../core/router/routes.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../mock/taxonomy.dart';
import '../../mock/specimens.dart';

/// Genus detail: images, key diagnostic traits, "often confused with",
/// crops, and a NeMys link.
class GenusDetailScreen extends ConsumerStatefulWidget {
  const GenusDetailScreen({super.key, required this.name, this.embedded = false});
  final String name;
  final bool embedded;

  @override
  ConsumerState<GenusDetailScreen> createState() => _GenusDetailScreenState();
}

class _GenusDetailScreenState extends ConsumerState<GenusDetailScreen> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final t = context.t;
    final repo = ref.watch(referenceRepositoryProvider);
    final info = repo.genus(widget.name);
    final online = ref.watch(onlineProvider) && ViewStateScope.of(context) != ViewState.offline;
    final now = ref.watch(clockProvider)();
    final system = ref.watch(settingsProvider).system;
    final desktop = FormFactor.of(context).isDesktop;

    final images = <Widget>[
      SpecimenPortrait(genus: info.name, seed: info.imageSeeds.first),
      for (final s in info.imageSeeds) Micrograph(specimen: makeSpecimen(s, capturedAt: now, nematodes: 1, withDebrisBody: false)),
    ];

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: KRadius.heroAll,
          child: SizedBox(
            height: desktop ? 300 : 220,
            child: Stack(children: [
              PageView(
                onPageChanged: (p) => setState(() => _page = p),
                children: [for (final i in images) Semantics(label: 'Reference image of ${info.name}', child: i)],
              ),
              Positioned(
                bottom: KSpace.s12,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < images.length; i++)
                      AnimatedContainer(
                        duration: KMotion.of(context, KMotion.fast),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _page ? 16 : 6,
                        height: 6,
                        decoration: BoxDecoration(color: k.overlayText.withValues(alpha: i == _page ? 0.95 : 0.5), borderRadius: KRadius.pill),
                      ),
                  ],
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: KSpace.s20),
        GenusName(info.name, style: t.largeTitle),
        const SizedBox(height: KSpace.s4),
        Text('${info.commonName} · ${info.family} · ${system.orderFor(info.order, info.family)}', style: t.callout.copyWith(color: k.textSecondary)),
        const SizedBox(height: KSpace.s12),
        Wrap(spacing: KSpace.s8, runSpacing: KSpace.s8, children: [
          if (info.recordedInPhilippines)
            StatusChip(label: 'Recorded in the Philippines', icon: KIcons.leaf, color: k.success, filled: true)
          else
            StatusChip(label: 'Reference only', icon: KIcons.info, color: k.textSecondary, filled: true),
        ]),
        const SizedBox(height: KSpace.s16),
        Text(info.summary, style: t.callout),
        if (info.hasDetails) ...[
          const SizedBox(height: KSpace.s24),
          Text('KEY DIAGNOSTIC TRAITS', style: t.sectionHeader),
          const SizedBox(height: KSpace.s8),
          for (final tr in info.traits)
            Padding(
              padding: const EdgeInsets.only(bottom: KSpace.s8),
              child: KCard(
                padding: const EdgeInsets.all(KSpace.s12),
                child: Row(children: [
                  Container(
                    width: 96,
                    height: 64,
                    decoration: BoxDecoration(color: k.background, borderRadius: KRadius.smAll),
                    child: Center(child: TraitIllustration(tr.illustration, height: 52)),
                  ),
                  const SizedBox(width: KSpace.s12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(tr.name, style: t.captionStrong),
                      Text(tr.value, style: t.headline),
                      const SizedBox(height: 2),
                      Text(tr.why, style: t.caption),
                    ]),
                  ),
                ]),
              ),
            ),
          const SizedBox(height: KSpace.s16),
          KListSection(
            header: 'OFTEN CONFUSED WITH',
            children: [
              for (final s in info.similar)
                KListRow(
                  title: s.name,
                  titleWidget: GenusName(s.name, style: t.bodyStyle),
                  subtitle: s.howToTell,
                  onTap: () => context.pushTo(Routes.genus(s.name)),
                ),
            ],
          ),
          const SizedBox(height: KSpace.s24),
          Text('CROPS IN THE PHILIPPINES', style: t.sectionHeader),
          const SizedBox(height: KSpace.s8),
          Wrap(spacing: KSpace.s8, runSpacing: KSpace.s8, children: [
            for (final c in info.crops) TraitChip(label: c, icon: KIcons.plant),
          ]),
        ],
        const SizedBox(height: KSpace.s24),
        KListSection(
          footer: online ? null : 'NeMys needs an internet connection.',
          children: [
            KListRow(
              title: 'View on NeMys',
              subtitle: 'Nematode species database',
              leading: KIcons.globe,
              trailing: Icon(KIcons.external, size: 16, color: k.textSecondary),
              onTap: online ? () => launchUrl(info.nemysUrl, mode: LaunchMode.externalApplication) : null,
            ),
            if (desktop)
              KListRow(
                title: 'Open the key here',
                leading: KIcons.key,
                onTap: () => context.pushTo(Routes.key()),
              ),
          ],
        ),
      ],
    );

    if (widget.embedded) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(KSpace.s32, KSpace.s24, KSpace.s32, KSpace.s40),
        children: [Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: content))],
      );
    }
    return LargeTitleScaffold(
      title: info.name,
      italicTitle: true,
      largeTitle: false,
      maxContentWidth: 760,
      slivers: [SliverToBoxAdapter(child: content)],
    );
  }
}
