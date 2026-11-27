import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/theme/theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import 'trait_sheet.dart';

/// Specimen portrait with region overlays toggled by chips.
class RegionHeader extends StatefulWidget {
  const RegionHeader({super.key, required this.report, this.height = 200, this.initial = const {SpecimenRegion.head, SpecimenRegion.vulva, SpecimenRegion.tail}});
  final Report report;
  final double height;
  final Set<SpecimenRegion> initial;

  @override
  State<RegionHeader> createState() => _RegionHeaderState();
}

class _RegionHeaderState extends State<RegionHeader> {
  late final Set<SpecimenRegion> _on = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final t = context.t;
    return KCard(
      padding: EdgeInsets.zero,
      clip: true,
      radius: KRadius.sheet,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: widget.height,
            child: LayoutBuilder(builder: (context, c) {
              return Stack(
                children: [
                  Positioned.fill(
                    child: SpecimenPortrait(
                      genus: widget.report.genus,
                      seed: widget.report.specimen.seed,
                      localPath: widget.report.specimen.localPath,
                      imageUrl: widget.report.specimen.imageUrl,
                    ),
                  ),
                  for (final r in SpecimenRegion.values)
                    if (_on.contains(r) && widget.report.regions[r] != null)
                      _overlay(r, widget.report.regions[r]!, c.biggest, k, t),
                ],
              );
            }),
          ),
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: KSpace.s12, vertical: 10),
              children: [
                for (final r in SpecimenRegion.values)
                  Padding(
                    padding: const EdgeInsets.only(right: KSpace.s8),
                    child: TraitChip(
                      label: r.label,
                      selected: _on.contains(r),
                      onTap: () => setState(() => _on.contains(r) ? _on.remove(r) : _on.add(r)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _overlay(SpecimenRegion region, Rect r, Size size, KheryneColors k, KType t) {
    final rect = Rect.fromLTRB(r.left * size.width, r.top * size.height, r.right * size.width, r.bottom * size.height);
    final c = k.accent;
    return Positioned.fromRect(
      rect: rect,
      child: IgnorePointer(
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned.fill(
            child: CustomPaint(painter: _DashedRect(c)),
          ),
          Positioned(
            left: region == SpecimenRegion.tail ? null : 0,
            right: region == SpecimenRegion.tail ? 0 : null,
            top: region == SpecimenRegion.tail ? null : -18,
            bottom: region == SpecimenRegion.tail ? -18 : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(KRadius.box)),
              child: Text(region.label, style: t.micro.copyWith(color: onFill(c), fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _DashedRect extends CustomPainter {
  _DashedRect(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(KRadius.box)));
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 9) {
        canvas.drawPath(m.extractPath(d, d + 5), p);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRect old) => old.color != color;
}

/// "Likely Pratylenchus (82%). Based on: …"
class ReportHeadline extends StatelessWidget {
  const ReportHeadline({super.key, required this.report, this.large = true});
  final Report report;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final t = context.t;
    final c = report.classification.genus;
    final style = large ? t.title1 : t.title2;
    final basis = report.traits.take(3).map((tr) => '${tr.name.toLowerCase()} ${tr.value.toLowerCase()}').join('; ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text.rich(TextSpan(style: style, children: [
            TextSpan(text: report.classification.isUncertain ? 'Possibly ' : 'Likely '),
            genusSpan(c.name),
          ])),
        ),
        const SizedBox(height: KSpace.s8),
        Row(children: [ConfidencePill(c.confidence)]),
        const SizedBox(height: KSpace.s8),
        Text('Based on: $basis.', style: t.callout.copyWith(color: k.textSecondary)),
      ],
    );
  }
}

/// Traits with a "why this matters" disclosure and a detail sheet.
class TraitsList extends StatelessWidget {
  const TraitsList({super.key, required this.report, this.dense = false});
  final Report report;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return ClipRRect(
      borderRadius: KRadius.cardAll,
      child: ColoredBox(
        color: dense ? k.background : k.surface,
        child: Column(
          children: [
            for (var i = 0; i < report.traits.length; i++) ...[
              _TraitRow(report: report, trait: report.traits[i], dense: dense),
              if (i < report.traits.length - 1)
                Padding(
                  padding: const EdgeInsets.only(left: KSpace.s16),
                  child: Divider(height: KSize.hairline, thickness: KSize.hairline, color: k.separator),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TraitRow extends StatefulWidget {
  const _TraitRow({required this.report, required this.trait, required this.dense});
  final Report report;
  final Trait trait;
  final bool dense;

  @override
  State<_TraitRow> createState() => _TraitRowState();
}

class _TraitRowState extends State<_TraitRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final t = context.t;
    final tr = widget.trait;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Pressable(
          onTap: () => setState(() => _open = !_open),
          semanticLabel: '${tr.name}: ${tr.value}. ${_open ? 'Hide' : 'Show'} why this matters',
          borderRadius: BorderRadius.zero,
          pressScale: 1,
          child: Padding(
            padding: EdgeInsets.fromLTRB(KSpace.s16, widget.dense ? 10 : 13, KSpace.s12, widget.dense ? 10 : 13),
            child: Row(
              children: [
                Expanded(child: Text(tr.name, style: widget.dense ? t.subhead.copyWith(fontSize: 14) : t.bodyStyle)),
                const SizedBox(width: KSpace.s8),
                Flexible(
                  child: Text(tr.value,
                      style: (widget.dense ? t.caption : t.bodyStyle.copyWith(color: k.textSecondary)), textAlign: TextAlign.end),
                ),
                const SizedBox(width: KSpace.s4),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: KMotion.of(context, KMotion.fast),
                  child: Icon(KIcons.chevronDown, size: 16, color: k.textSecondary),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: KMotion.of(context, KMotion.base),
          curve: KMotion.ease,
          alignment: Alignment.topCenter,
          child: !_open
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.fromLTRB(KSpace.s16, 0, KSpace.s16, KSpace.s12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Why this matters', style: t.captionStrong.copyWith(color: k.text)),
                      const SizedBox(height: 2),
                      Text(tr.why, style: t.caption),
                      const SizedBox(height: KSpace.s8),
                      GestureDetector(
                        onTap: () => showTraitSheet(context, widget.report, tr),
                        child: Text('Compare with reference', style: t.captionStrong.copyWith(color: k.primary)),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

/// de Man indices in a tabular-figure table.
class MorphometricsTable extends StatelessWidget {
  const MorphometricsTable({super.key, required this.m, this.dense = false});
  final Morphometrics m;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final t = context.t;
    final rows = [
      ('L', 'Body length', um(m.bodyLength)),
      ('a', 'Length ÷ max width', ratio(m.a)),
      ('b', 'Length ÷ esophagus', ratio(m.b)),
      ('c', 'Length ÷ tail', ratio(m.c)),
      ('V%', 'Vulva from head', '${m.vPercent.toStringAsFixed(0)}%'),
      ('Stylet', 'Stylet length', um(m.styletLength)),
    ];
    return ClipRRect(
      borderRadius: KRadius.cardAll,
      child: ColoredBox(
        color: dense ? k.background : k.surface,
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++)
              Container(
                padding: EdgeInsets.symmetric(horizontal: KSpace.s16, vertical: dense ? 8 : 11),
                decoration: BoxDecoration(
                  border: i == rows.length - 1 ? null : Border(bottom: BorderSide(color: k.separator, width: KSize.hairline)),
                ),
                child: Row(
                  children: [
                    SizedBox(width: 56, child: Text(rows[i].$1, style: t.calloutStrong.copyWith(fontStyle: rows[i].$1.length == 1 ? FontStyle.italic : null))),
                    Expanded(child: Text(rows[i].$2, style: t.caption)),
                    Text(rows[i].$3, style: t.numeric.copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Order line under the chosen classification system.
class LadderFor extends ConsumerWidget {
  const LadderFor({super.key, required this.report, this.dense = false, this.background});
  final Report report;
  final bool dense;
  final Color? background;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = report.classification;
    return ClassificationLadder(
      classification: c,
      orderName: displayOrder(ref, c.order.name, c.family.name),
      dense: dense,
      background: background,
    );
  }
}

const disclaimer = 'Kheryne supports identification. Confirm important results with a qualified nematologist.';
