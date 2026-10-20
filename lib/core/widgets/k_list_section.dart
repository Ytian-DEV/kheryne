import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'k_icons.dart';
import 'pressable.dart';

/// Inset grouped list section with a hairline separator between rows.
class KListSection extends StatelessWidget {
  const KListSection({super.key, required this.children, this.header, this.footer, this.margin});

  final List<Widget> children;
  final String? header;
  final String? footer;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final t = context.t;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i < children.length - 1) {
        rows.add(Padding(
          padding: const EdgeInsetsDirectional.only(start: KSpace.s16),
          child: Divider(height: KSize.hairline, thickness: KSize.hairline, color: k.separator),
        ));
      }
    }
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(KSpace.s16, 0, KSpace.s16, KSpace.s8),
              child: Semantics(header: true, child: Text(header!, style: t.sectionHeader)),
            ),
          ClipRRect(
            borderRadius: KRadius.cardAll,
            child: ColoredBox(color: k.surface, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows)),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(KSpace.s16, KSpace.s8, KSpace.s16, 0),
              child: Text(footer!, style: t.caption),
            ),
        ],
      ),
    );
  }
}

/// One row in a [KListSection].
class KListRow extends StatelessWidget {
  const KListRow({
    super.key,
    required this.title,
    this.titleWidget,
    this.subtitle,
    this.leading,
    this.leadingColor,
    this.value,
    this.trailing,
    this.onTap,
    this.onSecondaryTapDown,
    this.chevron,
    this.destructive = false,
    this.selected = false,
  });

  final String title;

  /// Replaces the title text (for italic genus names etc.); [title] is
  /// still used for semantics.
  final Widget? titleWidget;
  final String? subtitle;
  final IconData? leading;
  final Color? leadingColor;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final void Function(TapDownDetails)? onSecondaryTapDown;

  /// Defaults to true when [onTap] is set and there is no [trailing].
  final bool? chevron;
  final bool destructive;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final t = context.t;
    final showChevron = chevron ?? (onTap != null && trailing == null);
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: KSize.hit + 4),
      child: Container(
        color: selected ? k.container : null,
        padding: const EdgeInsets.symmetric(horizontal: KSpace.s16, vertical: KSpace.s12),
        child: Row(
          children: [
            if (leading != null) ...[
              Icon(leading, size: KSize.icon + 2, color: leadingColor ?? (destructive ? k.error : k.primary)),
              const SizedBox(width: KSpace.s12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  titleWidget ??
                      Text(title, style: t.bodyStyle.copyWith(color: destructive ? k.error : k.text)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: t.caption),
                  ],
                ],
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: KSpace.s8),
              Flexible(
                child: Text(value!,
                    style: t.bodyStyle.copyWith(color: k.textSecondary, fontFeatures: KType.tabular),
                    textAlign: TextAlign.end),
              ),
            ],
            if (trailing != null) ...[const SizedBox(width: KSpace.s8), trailing!],
            if (showChevron) ...[
              const SizedBox(width: KSpace.s4),
              Icon(KIcons.chevronRight, size: KSize.iconSm + 2, color: k.textSecondary),
            ],
          ],
        ),
      ),
    );
    if (onTap == null && onSecondaryTapDown == null) {
      return Semantics(label: titleWidget != null ? title : null, child: row);
    }
    return Pressable(
      onTap: onTap,
      onSecondaryTapDown: onSecondaryTapDown,
      borderRadius: BorderRadius.zero,
      pressScale: 1,
      semanticLabel: [title, ?subtitle, ?value].join(', '),
      selected: selected,
      child: row,
    );
  }
}
