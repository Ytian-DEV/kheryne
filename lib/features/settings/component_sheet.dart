import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../mock/specimens.dart';

/// Every token and reusable widget on one page.
class ComponentSheetScreen extends ConsumerWidget {
  const ComponentSheetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = context.k;
    final t = context.t;
    final report = ref.watch(reportProvider('r-100')).value;
    final uncertain = ref.watch(reportProvider('r-107')).value;
    Widget section(String title, List<Widget> children) => Padding(
          padding: const EdgeInsets.only(bottom: KSpace.s32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(title.toUpperCase(), style: t.sectionHeader),
            const SizedBox(height: KSpace.s12),
            ...children,
          ]),
        );
    final swatches = <(String, Color)>[
      ('primary', k.primary),
      ('primaryStrong', k.primaryStrong),
      ('accent', k.accent),
      ('container', k.container),
      ('background', k.background),
      ('surface', k.surface),
      ('text', k.text),
      ('textSecondary', k.textSecondary),
      ('success', k.success),
      ('warning', k.warning),
      ('error', k.error),
      ('userBox', k.userBox),
      ('notNematode', k.notNematode),
      ('separator', k.separator),
    ];
    return LargeTitleScaffold(
      title: 'Components',
      maxContentWidth: 900,
      slivers: [
        SliverList.list(children: [
          section('Colour tokens', [
            Wrap(spacing: KSpace.s12, runSpacing: KSpace.s12, children: [
              for (final (name, c) in swatches)
                SizedBox(
                  width: 104,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(height: 48, decoration: BoxDecoration(color: c, borderRadius: KRadius.smAll, border: Border.all(color: k.separator))),
                    const SizedBox(height: KSpace.s4),
                    Text(name, style: t.captionStrong.copyWith(fontSize: 12)),
                    Text('#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}', style: t.micro),
                  ]),
                ),
            ]),
          ]),
          section('Type scale', [
            Text('Large title 34', style: t.largeTitle),
            Text('Title 28', style: t.title1),
            Text('Title 22', style: t.title2),
            Text('Headline 17', style: t.headline),
            Text('Body 17', style: t.bodyStyle),
            Text('Callout 15', style: t.callout),
            Text('Caption 13', style: t.caption),
            Text('Micro 11', style: t.micro),
            Text('Tabular 0123456789 µm', style: t.numeric),
            GenusName('Hemicriconemoides', style: t.title2),
          ]),
          section('Buttons', [
            Wrap(spacing: KSpace.s12, runSpacing: KSpace.s12, crossAxisAlignment: WrapCrossAlignment.center, children: [
              KButton(label: 'Identify nematode', icon: KIcons.scan, onPressed: () {}),
              KButton.secondary(label: 'Export PDF', icon: KIcons.pdf, onPressed: () {}),
              KButton.tertiary(label: 'See all', onPressed: () {}),
              const KButton(label: 'Disabled', onPressed: null),
              KButton(label: 'Saving', loading: true, onPressed: () {}),
              const KButton(label: 'Delete', variant: KButtonVariant.destructive, onPressed: null),
              KIconButton(icon: KIcons.share, label: 'Share', onPressed: () {}),
            ]),
          ]),
          section('Confidence, chips, status', [
            Wrap(spacing: KSpace.s8, runSpacing: KSpace.s8, children: [
              const ConfidencePill(0.92),
              const ConfidencePill(0.71),
              const ConfidencePill(0.48),
              const TraitChip(label: 'Head', selected: true),
              const TraitChip(label: 'Tail'),
              StatusChip(label: 'Offline ready', icon: KIcons.offlineReady, color: k.success),
              StatusChip(label: 'Recorded in the Philippines', icon: KIcons.leaf, color: k.success, filled: true),
            ]),
            const SizedBox(height: KSpace.s12),
            KSegmentedControl<int>(segments: const [(0, 'Select', KIcons.select), (1, 'Draw box', KIcons.drawBox), (2, 'Filters', KIcons.adjust)], value: 0, onChanged: (_) {}),
          ]),
          section('Banners', [
            const CaptureGuidanceBanner(guidance: CaptureGuidance.magnification),
            const SizedBox(height: KSpace.s8),
            const StatusBanner(title: 'You’re offline', message: 'Identification still works.', tone: BannerTone.info),
            const SizedBox(height: KSpace.s8),
            const StatusBanner(title: 'Couldn’t save the report', message: 'Storage is full.', tone: BannerTone.error),
            const SizedBox(height: KSpace.s8),
            const UncertainCard(),
          ]),
          section('Detection boxes', [
            Container(
              height: 150,
              padding: const EdgeInsets.fromLTRB(KSpace.s24, KSpace.s32, KSpace.s24, KSpace.s16),
              decoration: BoxDecoration(color: k.canvas, borderRadius: KRadius.cardAll),
              child: const Row(children: [
                Expanded(child: DetectionBox(detection: Detection(id: 'a', rect: Rect.zero, kind: BoxKind.ai, confidence: 0.87))),
                SizedBox(width: KSpace.s24),
                Expanded(child: DetectionBox(detection: Detection(id: 'u', rect: Rect.zero, kind: BoxKind.user), selected: true)),
                SizedBox(width: KSpace.s24),
                Expanded(child: DetectionBox(detection: Detection(id: 'c', rect: Rect.zero, kind: BoxKind.confirmed))),
                SizedBox(width: KSpace.s24),
                Expanded(child: DetectionBox(detection: Detection(id: 'r', rect: Rect.zero, kind: BoxKind.rejected))),
              ]),
            ),
          ]),
          if (report != null)
            section('Classification ladder', [
              ClassificationLadder(classification: report.classification),
              if (uncertain != null) ...[const SizedBox(height: KSpace.s12), ClassificationLadder(classification: uncertain.classification, dense: true)],
            ]),
          section('Lists', [
            KListSection(header: 'SECTION', footer: 'Footer text explains the section.', children: [
              const KListRow(title: 'Value row', value: '0.405 µm/px'),
              KListRow(title: 'Navigation row', leading: KIcons.ruler, onTap: () {}),
              KListRow(title: 'Switch row', leading: KIcons.moon, trailing: Switch(value: true, onChanged: (_) {})),
            ]),
          ]),
          section('Empty state and skeletons', [
            KCard(child: EmptyState(art: LineArt.emptySlide, message: 'No identifications yet.', action: 'Start a scan', onAction: () {})),
            const SizedBox(height: KSpace.s12),
            const Row(children: [
              SkeletonBlock(width: 56, height: 56),
              SizedBox(width: KSpace.s12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [SkeletonBlock(width: 160), SizedBox(height: 6), SkeletonBlock(width: 100, height: 12)])),
            ]),
          ]),
          section('Trait drawings', [
            Wrap(spacing: KSpace.s12, runSpacing: KSpace.s12, children: [
              for (final i in Illustration.values)
                Container(
                  width: 120,
                  padding: const EdgeInsets.all(KSpace.s8),
                  decoration: BoxDecoration(color: k.surface, borderRadius: KRadius.smAll),
                  child: Column(children: [TraitIllustration(i, height: 52), Text(i.name, style: t.micro)]),
                ),
            ]),
          ]),
          section('Line art', [
            Wrap(spacing: KSpace.s16, runSpacing: KSpace.s16, children: [for (final a in LineArt.values) LineArtView(a, size: 72)]),
          ]),
          section('Micrographs', [
            SizedBox(
              height: 140,
              child: Row(children: [
                for (final seed in const [11, 18, 25, 32])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: KSpace.s8),
                      child: ClipRRect(
                        borderRadius: KRadius.cardAll,
                        child: Micrograph(
                          specimen: makeSpecimen(seed, capturedAt: DateTime(2026)),
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
          ]),
        ]),
      ],
    );
  }
}
