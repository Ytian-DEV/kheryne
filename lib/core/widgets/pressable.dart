import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/theme.dart';

/// Shared interaction primitive: hover tint (desktop), keyboard focus ring,
/// press feedback, Enter/Space activation, right-click and semantics.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.onSecondaryTapDown,
    this.semanticLabel,
    this.isButton = true,
    this.selected = false,
    this.borderRadius = KRadius.cardAll,
    this.hoverColor,
    this.pressScale = 0.98,
    this.focusRing = true,
    this.tooltip,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final void Function(TapDownDetails details)? onSecondaryTapDown;
  final String? semanticLabel;
  final bool isButton;
  final bool selected;
  final BorderRadius borderRadius;
  final Color? hoverColor;
  final double pressScale;
  final bool focusRing;
  final String? tooltip;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _hover = false;
  bool _pressed = false;
  bool _focused = false;

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final d = KMotion.of(context, KMotion.fast);
    Widget content = AnimatedScale(
      scale: _pressed ? widget.pressScale : 1,
      duration: d,
      curve: KMotion.ease,
      child: AnimatedOpacity(
        opacity: _pressed ? 0.85 : 1,
        duration: d,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            widget.child,
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedContainer(
                  duration: d,
                  decoration: BoxDecoration(
                    borderRadius: widget.borderRadius,
                    color: _hover && _enabled ? (widget.hoverColor ?? k.text.withValues(alpha: 0.04)) : Colors.transparent,
                    border: _focused && widget.focusRing
                        ? Border.all(color: k.primary, width: 2)
                        : null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    content = FocusableActionDetector(
      enabled: _enabled,
      mouseCursor: _enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onShowHoverHighlight: (v) => setState(() => _hover = v),
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
          widget.onTap?.call();
          return null;
        }),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onSecondaryTapDown: widget.onSecondaryTapDown,
        onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
        child: content,
      ),
    );

    content = Semantics(
      button: widget.isButton && _enabled,
      selected: widget.selected,
      enabled: _enabled,
      label: widget.semanticLabel,
      onTap: widget.onTap,
      excludeSemantics: widget.semanticLabel != null,
      child: content,
    );

    if (widget.tooltip != null) {
      content = Tooltip(message: widget.tooltip!, child: content);
    }
    return content;
  }
}
