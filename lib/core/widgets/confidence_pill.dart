import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'k_icons.dart';

enum ConfidenceLevel { high, medium, uncertain }

ConfidenceLevel confidenceLevel(double c) =>
    c >= 0.8 ? ConfidenceLevel.high : (c >= 0.6 ? ConfidenceLevel.medium : ConfidenceLevel.uncertain);

extension ConfidenceStyle on ConfidenceLevel {
  Color color(KheryneColors k) => switch (this) {
        ConfidenceLevel.high => k.success,
        ConfidenceLevel.medium => k.warning,
        ConfidenceLevel.uncertain => k.error,
      };

  IconData get icon => switch (this) {
        ConfidenceLevel.high => KIcons.checkCircle,
        ConfidenceLevel.medium => KIcons.info,
        ConfidenceLevel.uncertain => KIcons.warning,
      };
}

String percent(double c) => '${(c * 100).round()}%';

/// Confidence as icon + number (+ "Uncertain" below 60%). Colour is never
/// the only signal.
class ConfidencePill extends StatelessWidget {
  const ConfidencePill(this.confidence, {super.key, this.compact = false});

  final double confidence;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final t = context.t;
    final level = confidenceLevel(confidence);
    final c = level.color(k);
    final label = level == ConfidenceLevel.uncertain ? '${percent(confidence)} · Uncertain' : percent(confidence);
    return Semantics(
      label: 'Confidence ${percent(confidence)}${level == ConfidenceLevel.uncertain ? ', uncertain' : ''}',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(color: c.withValues(alpha: context.isDark ? 0.2 : 0.13), borderRadius: KRadius.pill),
        child: Padding(
          padding: EdgeInsets.fromLTRB(compact ? 6 : KSpace.s8, 3, compact ? KSpace.s8 : 10, 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(level.icon, size: compact ? 12 : 14, color: c),
              const SizedBox(width: KSpace.s4),
              Text(label,
                  style: (compact ? t.micro : t.captionStrong)
                      .copyWith(color: k.text, fontWeight: FontWeight.w600, fontFeatures: KType.tabular)),
            ],
          ),
        ),
      ),
    );
  }
}
