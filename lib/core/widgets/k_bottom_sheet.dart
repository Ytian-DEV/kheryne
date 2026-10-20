import 'package:flutter/material.dart';

import '../layout/form_factor.dart';
import '../theme/theme.dart';
import 'k_button.dart';
import 'k_icons.dart';

/// Bottom sheet with a grabber and medium/large detents. On desktop it opens
/// as a centred sheet window instead, which is the native pattern there.
Future<T?> showKBottomSheet<T>(
  BuildContext context, {
  required Widget Function(BuildContext context, ScrollController controller) builder,
  String? title,
  double initial = 0.55,
  List<double> detents = const [0.55, 0.92],
}) {
  if (FormFactor.of(context).isDesktop) {
    return showDialog<T>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(KSpace.s40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SheetHeader(title: title, showClose: true),
              Flexible(child: builder(ctx, ScrollController())),
            ],
          ),
        ),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    sheetAnimationStyle: AnimationStyle(duration: KMotion.of(context, KMotion.slow), curve: KMotion.spring),
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: initial,
      minChildSize: detents.first * 0.6,
      maxChildSize: detents.last,
      snap: true,
      snapSizes: detents,
      builder: (ctx, controller) => Column(
        children: [
          const _Grabber(),
          if (title != null) _SheetHeader(title: title),
          Expanded(child: builder(ctx, controller)),
        ],
      ),
    ),
  );
}

class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: KSpace.s8, bottom: KSpace.s4),
        child: Container(
          width: 36,
          height: 5,
          decoration: BoxDecoration(color: context.k.textSecondary.withValues(alpha: 0.35), borderRadius: KRadius.pill),
        ),
      );
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({this.title, this.showClose = false});
  final String? title;
  final bool showClose;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(KSpace.s20, KSpace.s8, KSpace.s8, KSpace.s4),
        child: Row(
          children: [
            Expanded(child: Text(title ?? '', style: context.t.headline)),
            if (showClose)
              KIconButton(icon: KIcons.close, label: 'Close', onPressed: () => Navigator.of(context).pop()),
          ],
        ),
      );
}

/// Small confirmation dialog with one destructive or primary action.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirm,
  bool destructive = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actionsPadding: const EdgeInsets.fromLTRB(KSpace.s16, 0, KSpace.s16, KSpace.s16),
      actions: [
        KButton.tertiary(label: 'Cancel', onPressed: () => Navigator.of(ctx).pop(false), size: KButtonSize.compact),
        KButton(
          label: confirm,
          onPressed: () => Navigator.of(ctx).pop(true),
          variant: destructive ? KButtonVariant.destructive : KButtonVariant.primary,
          size: KButtonSize.compact,
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Calm toast at the bottom of the screen.
void showToast(BuildContext context, String message, {String? action, VoidCallback? onAction}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 3),
      action: action == null ? null : SnackBarAction(label: action, onPressed: onAction ?? () {}),
      width: FormFactor.of(context).isDesktop ? 420 : null,
    ));
}
