import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/layout/scan_theme.dart';
import '../../core/providers.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';

/// Specimen side by side with a reference genus, with synced zoom and pan.
class CompareScreen extends ConsumerStatefulWidget {
  const CompareScreen({super.key, required this.specimenId, required this.genus});
  final String specimenId;
  final String genus;

  @override
  ConsumerState<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends ConsumerState<CompareScreen> {
  final _tc = TransformationController();
  late String _genus = widget.genus;

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final specimen = ref.watch(specimenProvider(widget.specimenId)).value;
    final info = ref.watch(referenceRepositoryProvider).genus(_genus);
    final options = [widget.genus, ...ref.watch(referenceRepositoryProvider).genus(widget.genus).similar.map((s) => s.name)];
    return ScanTheme(
      child: Builder(builder: (context) {
        final k = context.k;
        final t = context.t;
        Widget pane(String title, Widget label, Widget child) => Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(KSpace.s16, KSpace.s12, KSpace.s16, KSpace.s8),
                  child: Row(children: [Text(title, style: t.captionStrong), const SizedBox(width: KSpace.s8), label]),
                ),
                Expanded(
                  child: ClipRect(
                    child: InteractiveViewer(
                      transformationController: _tc,
                      minScale: 1,
                      maxScale: 8,
                      child: child,
                    ),
                  ),
                ),
              ]),
            );
        return Scaffold(
          backgroundColor: k.canvas,
          appBar: KNavBar(
            title: 'Compare',
            subtitle: 'Zoom and pan are linked',
            actions: [
              SizedBox(
                width: 420,
                child: KSegmentedControl<String>(
                  segments: [for (final o in options.take(3)) (o, o, null)],
                  value: _genus,
                  onChanged: (v) => setState(() => _genus = v),
                ),
              ),
              const SizedBox(width: KSpace.s8),
              KIconButton(icon: KIcons.fit, label: 'Reset zoom', onPressed: () => _tc.value = Matrix4.identity()),
              const SizedBox(width: KSpace.s8),
            ],
          ),
          body: Row(children: [
            pane(
              'YOUR SPECIMEN',
              Text(specimen?.fileName ?? '', style: t.caption),
              specimen == null
                  ? const Center(child: SkeletonBlock(width: 300, height: 300, radius: KRadius.full))
                  : Center(child: AspectRatio(aspectRatio: 1, child: Micrograph(specimen: specimen, fit: BoxFit.contain))),
            ),
            VerticalDivider(width: 1, color: k.separator),
            pane(
              'REFERENCE',
              GenusName(info.name, style: t.captionStrong.copyWith(color: k.text)),
              Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Stack(children: [
                    Positioned.fill(child: ColoredBox(color: MicrographPalette.outside, child: Center(child: AspectRatio(aspectRatio: 2.6, child: SpecimenPortrait(genus: info.name, seed: info.imageSeeds.first))))),
                    Positioned(
                      left: KSpace.s12,
                      bottom: KSpace.s12,
                      right: KSpace.s12,
                      child: Text(info.traits.take(2).map((tr) => '${tr.name}: ${tr.value}').join(' · '),
                          style: t.caption.copyWith(color: k.overlayText)),
                    ),
                  ]),
                ),
              ),
            ),
          ]),
        );
      }),
    );
  }
}
