import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../layout/form_factor.dart';
import '../theme/theme.dart';
import 'k_button.dart';
import 'k_icons.dart';

/// Page with an iOS-style large title that collapses into a compact,
/// blurred navigation bar on scroll. Back is a chevron icon only.
class LargeTitleScaffold extends StatefulWidget {
  const LargeTitleScaffold({
    super.key,
    required this.title,
    required this.slivers,
    this.subtitle,
    this.actions = const [],
    this.leading,
    this.showBack,
    this.bottomBar,
    this.largeTitle = true,
    this.titleWidget,
    this.background,
    this.maxContentWidth,
    this.onRefresh,
    this.header,
    this.italicTitle = false,
  });

  /// Genus names are always italic, including in the compact bar.
  final bool italicTitle;

  final String title;
  final String? subtitle;
  final Widget? titleWidget;
  final List<Widget> slivers;
  final List<Widget> actions;
  final Widget? leading;

  /// Defaults to `context.canPop()`.
  final bool? showBack;
  final Widget? bottomBar;
  final bool largeTitle;
  final Color? background;
  final double? maxContentWidth;
  final Future<void> Function()? onRefresh;

  /// Optional widget under the large title (search field, chips).
  final Widget? header;

  @override
  State<LargeTitleScaffold> createState() => _LargeTitleScaffoldState();
}

class _LargeTitleScaffoldState extends State<LargeTitleScaffold> {
  final _collapsed = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _collapsed.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification n) {
    if (n.depth == 0 && n.metrics.axis == Axis.vertical) {
      _collapsed.value = n.metrics.pixels > (widget.largeTitle ? 44 : 4);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final t = context.t;
    final desktop = FormFactor.of(context).isDesktop;
    final canPop = widget.showBack ?? GoRouter.maybeOf(context)?.canPop() ?? Navigator.of(context).canPop();
    final top = MediaQuery.paddingOf(context).top;
    final gutter = desktop ? KSpace.s32 : KSpace.gutter;
    const barHeight = 52.0;

    Widget constrain(Widget child) => widget.maxContentWidth == null
        ? child
        : Center(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: widget.maxContentWidth!), child: child));

    final leading = widget.leading ??
        (canPop
            ? KIconButton(icon: KIcons.chevronLeft, label: 'Back', onPressed: () => Navigator.of(context).maybePop())
            : null);

    final scroll = CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: SizedBox(height: top + barHeight)),
        if (widget.largeTitle)
          SliverToBoxAdapter(
            child: constrain(Padding(
              padding: EdgeInsets.fromLTRB(gutter, KSpace.s4, gutter, KSpace.s12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.subtitle != null) Text(widget.subtitle!, style: t.captionStrong),
                  Semantics(
                    header: true,
                    child: widget.titleWidget ?? Text(widget.title, style: desktop ? t.title1 : t.largeTitle),
                  ),
                ],
              ),
            )),
          ),
        if (widget.header != null)
          SliverToBoxAdapter(
              child: constrain(Padding(padding: EdgeInsets.fromLTRB(gutter, 0, gutter, KSpace.s16), child: widget.header))),
        for (final s in widget.slivers)
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: gutter),
            sliver: widget.maxContentWidth == null
                ? s
                : SliverLayoutBuilder(builder: (context, c) {
                    final extra = ((c.crossAxisExtent - widget.maxContentWidth!) / 2).clamp(0.0, double.infinity);
                    return SliverPadding(padding: EdgeInsets.symmetric(horizontal: extra), sliver: s);
                  }),
          ),
        SliverToBoxAdapter(child: SizedBox(height: KSpace.s40 + MediaQuery.paddingOf(context).bottom)),
      ],
    );

    Widget body = NotificationListener<ScrollNotification>(onNotification: _onScroll, child: scroll);
    if (widget.onRefresh != null) {
      body = RefreshIndicator(
          onRefresh: widget.onRefresh!, edgeOffset: top + barHeight, color: k.primary, backgroundColor: k.surface, child: body);
    }

    final bar = ValueListenableBuilder<bool>(
      valueListenable: _collapsed,
      builder: (context, collapsed, _) {
        final d = KMotion.of(context, KMotion.fast);
        final showTitle = collapsed || !widget.largeTitle;
        return ClipRect(
          child: BackdropFilter(
            filter: collapsed ? ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20) : ui.ImageFilter.blur(),
            child: AnimatedContainer(
              duration: d,
              height: top + barHeight,
              padding: EdgeInsets.only(top: top, left: desktop ? KSpace.s16 : KSpace.s4, right: desktop ? KSpace.s16 : KSpace.s8),
              decoration: BoxDecoration(
                color: collapsed ? (widget.background ?? k.background).withValues(alpha: 0.86) : (widget.background ?? k.background).withValues(alpha: 0),
                border: Border(bottom: BorderSide(color: collapsed ? k.separator : Colors.transparent, width: KSize.hairline)),
              ),
              child: NavigationToolbar(
                leading: leading,
                middle: AnimatedOpacity(
                  opacity: showTitle ? 1 : 0,
                  duration: d,
                  child: Text(widget.title,
                      style: t.headline.copyWith(fontStyle: widget.italicTitle ? FontStyle.italic : null),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: widget.actions),
                centerMiddle: true,
                middleSpacing: KSpace.s8,
              ),
            ),
          ),
        );
      },
    );

    return Scaffold(
      backgroundColor: widget.background ?? k.background,
      body: Stack(children: [Positioned.fill(child: body), Positioned(left: 0, right: 0, top: 0, child: bar)]),
      bottomNavigationBar: widget.bottomBar,
    );
  }
}

/// Plain compact navigation bar for full-screen tools (no large title).
class KNavBar extends StatelessWidget implements PreferredSizeWidget {
  const KNavBar({super.key, required this.title, this.subtitle, this.actions = const [], this.onBack, this.onDark = false, this.showBack = true});

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final VoidCallback? onBack;
  final bool onDark;
  final bool showBack;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final t = context.t;
    final fg = onDark ? k.overlayText : k.text;
    return Material(
      color: onDark ? Colors.transparent : k.background,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: KSpace.s4),
            child: Row(
              children: [
                if (showBack)
                  KIconButton(
                    icon: KIcons.chevronLeft,
                    label: 'Back',
                    color: fg,
                    onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                  )
                else
                  const SizedBox(width: KSpace.s12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: t.headline.copyWith(color: fg), maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (subtitle != null)
                        Text(subtitle!, style: t.caption.copyWith(color: onDark ? k.overlayText.withValues(alpha: 0.7) : k.textSecondary), maxLines: 1),
                    ],
                  ),
                ),
                ...actions,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
