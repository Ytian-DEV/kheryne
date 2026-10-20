import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/theme.dart';
import 'confidence_pill.dart';
import 'k_icons.dart';

/// Order → Family → Genus, each with a confidence bar and percentage.
class ClassificationLadder extends StatelessWidget {
  const ClassificationLadder({super.key, required this.classification, this.orderName, this.dense = false, this.background});

  final Classification classification;

  /// Display name of the order under the chosen classification system.
  final String? orderName;
  final bool dense;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final t = context.t;
    final rows = classification.ladder;
    return ClipRRect(
      borderRadius: KRadius.cardAll,
      child: ColoredBox(
        color: background ?? k.surface,
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              _Row(
                result: rows[i],
                name: rows[i].rank == Rank.order ? (orderName ?? rows[i].name) : rows[i].name,
                dense: dense,
                runnersUp: rows[i].rank == Rank.genus ? classification.runnersUp : const [],
              ),
              if (i < rows.length - 1)
                Padding(
                  padding: const EdgeInsets.only(left: KSpace.s16),
                  child: Divider(height: KSize.hairline, thickness: KSize.hairline, color: k.separator),
                ),
            ],
            if (rows.isEmpty) Text('No classification', style: t.caption),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.result, required this.name, required this.dense, required this.runnersUp});
  final RankResult result;
  final String name;
  final bool dense;
  final List<RankResult> runnersUp;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final t = context.t;
    final level = confidenceLevel(result.confidence);
    final c = level.color(k);
    final isGenus = result.rank == Rank.genus;
    final nameStyle = (dense ? t.subhead : t.headline).copyWith(fontStyle: isGenus ? FontStyle.italic : FontStyle.normal);
    return Semantics(
      label: '${result.rank.label} $name, ${percent(result.confidence)}${level == ConfidenceLevel.uncertain ? ', uncertain' : ''}',
      excludeSemantics: true,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: dense ? KSpace.s12 : KSpace.s16, vertical: dense ? 10 : 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: dense ? 52 : 60,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(result.rank.label, style: t.caption.copyWith(fontSize: dense ? 12 : 13)),
                  ),
                ),
                Expanded(child: Text(name, style: nameStyle, softWrap: true)),
                const SizedBox(width: KSpace.s8),
                if (level != ConfidenceLevel.high) ...[
                  Icon(level.icon, size: 14, color: c),
                  const SizedBox(width: KSpace.s4),
                ],
                Text(percent(result.confidence), style: (dense ? t.subhead : t.calloutStrong).copyWith(fontFeatures: KType.tabular)),
              ],
            ),
            SizedBox(height: dense ? 6 : KSpace.s8),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: result.confidence),
              duration: KMotion.of(context, const Duration(milliseconds: 600)),
              curve: KMotion.ease,
              builder: (context, v, _) => ClipRRect(
                borderRadius: KRadius.pill,
                child: Stack(children: [
                  Container(height: dense ? 4 : 6, color: k.container),
                  FractionallySizedBox(widthFactor: v, child: Container(height: dense ? 4 : 6, color: c)),
                ]),
              ),
            ),
            if (runnersUp.isNotEmpty) ...[
              const SizedBox(height: KSpace.s8),
              Text.rich(
                TextSpan(style: t.caption, children: [
                  const TextSpan(text: 'Also possible: '),
                  for (var i = 0; i < runnersUp.length; i++) ...[
                    TextSpan(text: runnersUp[i].name, style: const TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.w500)),
                    TextSpan(text: ' ${percent(runnersUp[i].confidence)}${i < runnersUp.length - 1 ? ', ' : ''}'),
                  ],
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Uncertain — confirm with an expert" card, shown when genus < 60%.
class UncertainCard extends StatelessWidget {
  const UncertainCard({super.key, this.onOpenKey});
  final VoidCallback? onOpenKey;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final t = context.t;
    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsets.all(KSpace.s16),
        decoration: BoxDecoration(
          color: k.warning.withValues(alpha: context.isDark ? 0.14 : 0.1),
          borderRadius: KRadius.cardAll,
          border: Border.all(color: k.warning.withValues(alpha: 0.45)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(KIcons.warning, color: k.warning, size: KSize.iconLg),
            const SizedBox(width: KSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Uncertain — confirm with an expert', style: t.headline),
                  const SizedBox(height: KSpace.s4),
                  Text('The genus result is below 60%. Check the traits below, walk through the dichotomous key, or ask a nematologist before recording it.',
                      style: t.callout.copyWith(color: k.textSecondary)),
                  if (onOpenKey != null) ...[
                    const SizedBox(height: KSpace.s8),
                    GestureDetector(
                      onTap: onOpenKey,
                      child: Text('Open in dichotomous key', style: t.calloutStrong.copyWith(color: k.primary)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
