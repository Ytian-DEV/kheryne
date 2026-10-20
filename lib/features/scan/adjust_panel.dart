import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import 'filters.dart';

/// Filter controls built from [filterConfig]. Used by the image editor and
/// the Workspace "Adjust" inspector tab.
class AdjustPanel extends StatelessWidget {
  const AdjustPanel({super.key, required this.value, required this.onChanged, this.dense = false});

  final ImageAdjustments value;
  final ValueChanged<ImageAdjustments> onChanged;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final t = context.t;
    final highlight = _same(value, ImageAdjustments.highlightNematodes);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: KButton(
                label: highlight ? 'Highlighting nematodes' : 'Highlight nematodes',
                icon: highlight ? KIcons.check : KIcons.crosshair,
                variant: highlight ? KButtonVariant.secondary : KButtonVariant.primary,
                size: dense ? KButtonSize.compact : KButtonSize.regular,
                onPressed: () => onChanged(ImageAdjustments.highlightNematodes),
              ),
            ),
            const SizedBox(width: KSpace.s8),
            KButton.tertiary(
              label: 'Reset',
              icon: KIcons.reset,
              size: dense ? KButtonSize.compact : KButtonSize.regular,
              onPressed: value.isNone ? null : () => onChanged(ImageAdjustments.none),
            ),
          ],
        ),
        const SizedBox(height: KSpace.s4),
        Text('Boosts body outlines and fades debris so candidates are easier to spot.', style: t.caption),
        const SizedBox(height: KSpace.s16),
        ClipRRect(
          borderRadius: KRadius.cardAll,
          child: ColoredBox(
            color: dense ? k.background : k.surface,
            child: Column(
              children: [
                for (var i = 0; i < filterConfig.length; i++) ...[
                  _FilterRow(def: filterConfig[i], value: value, onChanged: onChanged, dense: dense),
                  if (i < filterConfig.length - 1)
                    Padding(
                      padding: const EdgeInsets.only(left: KSpace.s16),
                      child: Divider(height: KSize.hairline, thickness: KSize.hairline, color: k.separator),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  static bool _same(ImageAdjustments a, ImageAdjustments b) =>
      a.brightness == b.brightness &&
      a.contrast == b.contrast &&
      a.clahe == b.clahe &&
      a.sharpen == b.sharpen &&
      a.edge == b.edge &&
      a.grayscale == b.grayscale &&
      a.invert == b.invert;
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.def, required this.value, required this.onChanged, required this.dense});
  final FilterDef def;
  final ImageAdjustments value;
  final ValueChanged<ImageAdjustments> onChanged;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final t = context.t;
    final v = filterValue(value, def.id);
    final title = Row(
      children: [
        Icon(def.icon, size: KSize.icon, color: k.textSecondary),
        const SizedBox(width: KSpace.s12),
        Expanded(child: Text(def.label, style: dense ? t.subhead.copyWith(fontSize: 14) : t.callout)),
        if (!def.isToggle)
          Text(def.min < 0 ? (v >= 0 ? '+${(v * 100).round()}' : '${(v * 100).round()}') : '${(v * 100).round()}',
              style: t.caption.copyWith(fontFeatures: KType.tabular)),
        if (def.isToggle)
          Switch(value: v > 0.5, onChanged: (on) => onChanged(withFilter(value, def.id, on ? 1 : 0))),
      ],
    );
    return Tooltip(
      message: def.help,
      waitDuration: const Duration(milliseconds: 700),
      child: Padding(
        padding: EdgeInsets.fromLTRB(KSpace.s16, dense ? 6 : KSpace.s8, KSpace.s8, dense ? 6 : KSpace.s8),
        child: def.isToggle
            ? title
            : Column(
                children: [
                  Padding(padding: const EdgeInsets.only(right: KSpace.s8, top: KSpace.s4), child: title),
                  Slider(
                    value: v.clamp(def.min, def.max),
                    min: def.min,
                    max: def.max,
                    label: def.label,
                    semanticFormatterCallback: (x) => '${def.label} ${(x * 100).round()}',
                    onChanged: (x) => onChanged(withFilter(value, def.id, x)),
                  ),
                ],
              ),
      ),
    );
  }
}
