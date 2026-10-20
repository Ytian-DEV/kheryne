import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';

@immutable
class BoxAction {
  const BoxAction(this.label, this.icon, this.onTap, {this.primary = false, this.destructive = false});
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;
  final bool destructive;
}

/// What you can do with a box in each state.
List<BoxAction> boxActions(
  Detection d, {
  required VoidCallback onCheck,
  required VoidCallback onAnalyze,
  required VoidCallback onRemove,
}) {
  if (d.checking) return const [];
  return switch (d.kind) {
    BoxKind.ai || BoxKind.user => [
        BoxAction('Check if nematode', KIcons.checkCircle, onCheck, primary: true),
        BoxAction(d.kind == BoxKind.user ? 'Delete box' : 'Remove box', KIcons.trash, onRemove, destructive: true),
      ],
    BoxKind.confirmed => [
        BoxAction('Analyze nematode', KIcons.scan, onAnalyze, primary: true),
        BoxAction('Remove box', KIcons.trash, onRemove, destructive: true),
      ],
    BoxKind.rejected => [
        BoxAction('Check again', KIcons.retry, onCheck),
        BoxAction('Remove box', KIcons.trash, onRemove, destructive: true),
      ],
  };
}

/// Small popover anchored to a box on the canvas.
class BoxPopover extends StatelessWidget {
  const BoxPopover({super.key, required this.detection, required this.actions});
  final Detection detection;
  final List<BoxAction> actions;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final t = context.t;
    final header = switch (detection.kind) {
      BoxKind.rejected => 'Not a nematode${detection.rejectReason != null ? ' · ${detection.rejectReason}' : ''}',
      BoxKind.confirmed => 'Confirmed nematode',
      BoxKind.ai => 'Candidate · ${percent(detection.confidence ?? 0)}',
      BoxKind.user => 'Box you drew',
    };
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(minWidth: 220, maxWidth: 260),
        decoration: BoxDecoration(
          color: k.surface,
          borderRadius: KRadius.cardAll,
          border: Border.all(color: k.separator),
          boxShadow: [BoxShadow(color: k.canvas.withValues(alpha: 0.22), blurRadius: 24, offset: const Offset(0, 8))],
        ),
        padding: const EdgeInsets.symmetric(vertical: KSpace.s4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(KSpace.s16, KSpace.s8, KSpace.s16, KSpace.s4),
              child: Text(header, style: t.caption),
            ),
            for (final a in actions)
              Pressable(
                onTap: a.onTap,
                semanticLabel: a.label,
                borderRadius: KRadius.smAll,
                pressScale: 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: KSpace.s16, vertical: 13),
                  child: Row(
                    children: [
                      Icon(a.icon, size: KSize.icon, color: a.destructive ? k.error : k.primary),
                      const SizedBox(width: KSpace.s12),
                      Text(a.label,
                          style: (a.primary ? t.calloutStrong : t.callout).copyWith(color: a.destructive ? k.error : k.text)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
