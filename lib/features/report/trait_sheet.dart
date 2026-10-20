import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';

Future<void> showTraitSheet(BuildContext context, Report report, Trait trait) => showKBottomSheet<void>(
      context,
      title: trait.name,
      initial: 0.62,
      detents: const [0.62, 0.92],
      builder: (ctx, controller) => TraitDetail(report: report, trait: trait, controller: controller),
    );

/// Zoomed crop of the region, explanation, and the reference drawing.
class TraitDetail extends StatelessWidget {
  const TraitDetail({super.key, required this.report, required this.trait, this.controller});
  final Report report;
  final Trait trait;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final t = context.t;
    final region = report.regions[trait.region] ?? const Rect.fromLTRB(0, 0.2, 0.2, 0.8);
    Widget panel(String label, Widget child) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: t.captionStrong),
              const SizedBox(height: KSpace.s8),
              AspectRatio(
                aspectRatio: 1.2,
                child: ClipRRect(borderRadius: KRadius.cardAll, child: child),
              ),
            ],
          ),
        );
    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(KSpace.s20, KSpace.s8, KSpace.s20, KSpace.s32),
      children: [
        Text(trait.value, style: t.title2),
        const SizedBox(height: KSpace.s16),
        Row(
          children: [
            panel('This specimen', SpecimenPortrait(genus: report.genus, seed: report.specimen.seed, crop: region.inflate(0.03))),
            const SizedBox(width: KSpace.s12),
            panel(
              'Reference drawing',
              ColoredBox(
                color: k.background,
                child: Center(child: TraitIllustration(trait.illustration, height: 84)),
              ),
            ),
          ],
        ),
        const SizedBox(height: KSpace.s4),
        Text.rich(
          TextSpan(style: t.micro, children: [
            const TextSpan(text: 'Reference from the gallery entry for '),
            genusSpan(report.genus),
            const TextSpan(text: '.'),
          ]),
        ),
        const SizedBox(height: KSpace.s20),
        Text('Why this matters', style: t.headline),
        const SizedBox(height: KSpace.s4),
        Text(trait.why, style: t.callout.copyWith(color: k.textSecondary)),
        const SizedBox(height: KSpace.s16),
        KListSection(children: [
          KListRow(title: 'Region', value: trait.region.label),
          KListRow(title: 'Read at', value: '${report.specimen.objective}× objective'),
        ]),
      ],
    );
  }
}
