import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/router/routes.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import 'filters.dart';

/// Review a captured photo against a quality checklist before using it.
class CaptureReviewScreen extends ConsumerWidget {
  const CaptureReviewScreen({super.key, required this.specimenId, this.forceIssues = false});
  final String specimenId;

  /// Screen gallery: show the failing checklist.
  final bool forceIssues;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = context.k;
    final t = context.t;
    final specimen = ref.watch(specimenProvider(specimenId));
    final adjustments = ref.watch(adjustmentsProvider)[specimenId] ?? ImageAdjustments.none;
    return Scaffold(
      appBar: const KNavBar(title: 'Review photo'),
      body: AsyncView<Specimen?>(
        value: specimen,
        loading: const Padding(
          padding: EdgeInsets.all(KSpace.s16),
          child: Column(children: [
            AspectRatio(aspectRatio: 1, child: SkeletonBlock(height: double.infinity, radius: KRadius.hero)),
            SizedBox(height: KSpace.s16),
            SkeletonBlock(height: 140, radius: KRadius.card),
          ]),
        ),
        isEmpty: (s) => s == null,
        empty: const EmptyState(art: LineArt.camera, message: 'This photo is no longer on the device.'),
        data: (s) {
          final blurry = forceIssues || s!.blurry;
          final dark = forceIssues || s!.dark;
          final hasBody = !forceIssues && s!.worms.any((w) => w.isNematode);
          final checks = [
            (!blurry, 'Focus', blurry ? 'Outline is soft. Retake after adjusting the fine focus.' : 'Body outlines are sharp.'),
            (!dark, 'Lighting', dark ? 'The field is dim. Open the condenser or raise the lamp.' : 'Even, bright field.'),
            (hasBody, 'Nematode in frame', hasBody ? 'At least one body is fully inside the field.' : 'No complete body found. Move the slide.'),
          ];
          final allGood = checks.every((c) => c.$1);
          return ListView(
            padding: const EdgeInsets.fromLTRB(KSpace.s16, KSpace.s8, KSpace.s16, KSpace.s24),
            children: [
              ClipRRect(
                borderRadius: KRadius.heroAll,
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Micrograph(specimen: s!, fit: BoxFit.contain, adjustments: adjustments),
                ),
              ),
              const SizedBox(height: KSpace.s16),
              KListSection(
                header: 'QUALITY CHECK',
                children: [
                  for (final (ok, title, detail) in checks)
                    KListRow(
                      title: title,
                      subtitle: detail,
                      leading: ok ? KIcons.checkCircle : KIcons.warning,
                      leadingColor: ok ? k.success : k.warning,
                    ),
                ],
              ),
              const SizedBox(height: KSpace.s12),
              Center(
                child: KButton.tertiary(
                  label: 'Adjust image',
                  icon: KIcons.adjust,
                  onPressed: () => context.pushTo(Routes.editor(s.id)),
                ),
              ),
              if (!allGood) ...[
                const SizedBox(height: KSpace.s8),
                Text('You can still use this photo, but results may be less certain.', style: t.caption, textAlign: TextAlign.center),
              ],
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(KSpace.s16, KSpace.s8, KSpace.s16, KSpace.s12),
          child: Row(
            children: [
              Expanded(child: KButton.secondary(label: 'Retake', expand: true, onPressed: () => Navigator.of(context).maybePop())),
              const SizedBox(width: KSpace.s12),
              Expanded(
                child: KButton(
                  label: 'Use photo',
                  expand: true,
                  onPressed: specimen.value == null ? null : () => context.pushTo(Routes.identify(specimenId)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
