import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import 'adjust_panel.dart';
import 'filters.dart';

/// Make nematodes stand out from the background and debris.
class ImageEditorScreen extends ConsumerStatefulWidget {
  const ImageEditorScreen({super.key, required this.specimenId});
  final String specimenId;

  @override
  ConsumerState<ImageEditorScreen> createState() => _ImageEditorScreenState();
}

class _ImageEditorScreenState extends ConsumerState<ImageEditorScreen> {
  late ImageAdjustments _a = ref.read(adjustmentsProvider)[widget.specimenId] ?? ImageAdjustments.none;
  double _split = 0.5;

  @override
  Widget build(BuildContext context) {
    final specimen = ref.watch(specimenProvider(widget.specimenId));
    return Scaffold(
      appBar: KNavBar(title: 'Adjust image', actions: [
        KButton.tertiary(
          label: 'Reset',
          size: KButtonSize.compact,
          onPressed: _a.isNone ? null : () => setState(() => _a = ImageAdjustments.none),
        ),
      ]),
      body: AsyncView<Specimen?>(
        value: specimen,
        loading: const Center(child: SkeletonBlock(width: 300, height: 300, radius: KRadius.hero)),
        isEmpty: (s) => s == null,
        empty: const EmptyState(art: LineArt.camera, message: 'This photo is no longer on the device.'),
        data: (s) => ListView(
          padding: const EdgeInsets.fromLTRB(KSpace.s16, KSpace.s8, KSpace.s16, KSpace.s24),
          children: [
            ClipRRect(
              borderRadius: KRadius.heroAll,
              child: AspectRatio(
                aspectRatio: 1,
                child: _BeforeAfter(specimen: s!, adjustments: _a, split: _split, onSplit: (v) => setState(() => _split = v)),
              ),
            ),
            const SizedBox(height: KSpace.s20),
            AdjustPanel(value: _a, onChanged: (v) => setState(() => _a = v)),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(KSpace.s16, KSpace.s8, KSpace.s16, KSpace.s12),
          child: KButton(
            label: 'Apply',
            expand: true,
            onPressed: () {
              ref.read(adjustmentsProvider.notifier).set(widget.specimenId, _a);
              Navigator.of(context).maybePop();
            },
          ),
        ),
      ),
    );
  }
}

/// Before/after comparison with a draggable divider.
class _BeforeAfter extends StatelessWidget {
  const _BeforeAfter({required this.specimen, required this.adjustments, required this.split, required this.onSplit});
  final Specimen specimen;
  final ImageAdjustments adjustments;
  final double split;
  final ValueChanged<double> onSplit;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final t = context.t;
    return LayoutBuilder(builder: (context, c) {
      final x = c.maxWidth * split;
      Widget tag(String s) => Container(
            padding: const EdgeInsets.symmetric(horizontal: KSpace.s8, vertical: 3),
            decoration: BoxDecoration(color: k.canvas.withValues(alpha: 0.6), borderRadius: KRadius.pill),
            child: Text(s, style: t.micro.copyWith(color: k.overlayText)),
          );
      return GestureDetector(
        onHorizontalDragUpdate: (d) => onSplit((d.localPosition.dx / c.maxWidth).clamp(0.05, 0.95)),
        onTapDown: (d) => onSplit((d.localPosition.dx / c.maxWidth).clamp(0.05, 0.95)),
        child: Stack(
          children: [
            Positioned.fill(child: Micrograph(specimen: specimen, fit: BoxFit.contain, adjustments: adjustments)),
            Positioned.fill(
              child: ClipRect(
                clipper: _LeftClip(x),
                child: Micrograph(specimen: specimen, fit: BoxFit.contain),
              ),
            ),
            Positioned(left: x - 1, top: 0, bottom: 0, child: Container(width: 2, color: k.overlayText)),
            Positioned(
              left: x - 18,
              top: c.maxHeight / 2 - 18,
              child: Semantics(
                slider: true,
                label: 'Before and after divider',
                value: '${(split * 100).round()}%',
                increasedValue: '${((split + 0.1).clamp(0.05, 0.95) * 100).round()}%',
                decreasedValue: '${((split - 0.1).clamp(0.05, 0.95) * 100).round()}%',
                onIncrease: () => onSplit((split + 0.1).clamp(0.05, 0.95)),
                onDecrease: () => onSplit((split - 0.1).clamp(0.05, 0.95)),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: k.overlayText, shape: BoxShape.circle),
                  child: Icon(KIcons.width, size: 18, color: k.canvas),
                ),
              ),
            ),
            Positioned(left: KSpace.s12, top: KSpace.s12, child: tag('Before')),
            Positioned(right: KSpace.s12, top: KSpace.s12, child: tag('After')),
          ],
        ),
      );
    });
  }
}

class _LeftClip extends CustomClipper<Rect> {
  _LeftClip(this.x);
  final double x;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, x, size.height);

  @override
  bool shouldReclip(_LeftClip old) => old.x != x;
}
