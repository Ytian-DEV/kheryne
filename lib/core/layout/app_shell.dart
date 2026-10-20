import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers.dart';
import '../router/routes.dart';
import '../theme/theme.dart';
import '../widgets/k_bottom_sheet.dart';
import '../widgets/k_icons.dart';
import '../widgets/pressable.dart';
import 'form_factor.dart';

/// Branch indices of the [StatefulShellRoute].
abstract final class Branch {
  static const home = 0;
  static const history = 1;
  static const gallery = 2;
  static const settings = 3;
  static const workspace = 4;
  static const live = 5;
  static const batch = 6;
  static const key = 7;
}

// Desktop keyboard intents, handled by the screen that owns them.
class ImportIntent extends Intent {
  const ImportIntent();
}

class ExportIntent extends Intent {
  const ExportIntent();
}

class SearchIntent extends Intent {
  const SearchIntent();
}

class ZoomIntent extends Intent {
  const ZoomIntent(this.factor);
  final double factor;
}

/// One shell for both platforms: bottom tabs with a central Scan action on
/// phones; a macOS-style sidebar on desktop (collapses to icons < 1200 px).
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ff = FormFactor.of(context);
    if (ff.isDesktop) return _DesktopShell(shell: shell);
    return _PhoneShell(shell: shell);
  }
}

class _PhoneShell extends StatelessWidget {
  const _PhoneShell({required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final t = context.t;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final tabs = <(int?, IconData, String)>[
      (Branch.home, KIcons.home, 'Home'),
      (Branch.history, KIcons.history, 'History'),
      (null, KIcons.scan, 'Scan'),
      (Branch.gallery, KIcons.gallery, 'Gallery'),
      (Branch.settings, KIcons.settings, 'Settings'),
    ];
    return Scaffold(
      extendBody: true,
      body: shell,
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: k.surface.withValues(alpha: 0.9),
              border: Border(top: BorderSide(color: k.separator, width: KSize.hairline)),
            ),
            padding: EdgeInsets.only(bottom: bottom, top: KSpace.s4),
            child: SizedBox(
              height: 60,
              child: Row(
                children: [
                  for (final (branch, icon, label) in tabs)
                    Expanded(
                      child: branch == null
                          ? Center(
                              child: Pressable(
                                onTap: () => context.pushTo(Routes.scan),
                                semanticLabel: 'Start live scan',
                                borderRadius: KRadius.pill,
                                pressScale: 0.92,
                                child: Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(color: k.primary, shape: BoxShape.circle),
                                  child: Icon(icon, color: k.onPrimary, size: 26),
                                ),
                              ),
                            )
                          : Pressable(
                              onTap: () => shell.goBranch(branch, initialLocation: branch == shell.currentIndex),
                              semanticLabel: '$label tab',
                              selected: shell.currentIndex == branch,
                              borderRadius: KRadius.cardAll,
                              pressScale: 0.95,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(icon,
                                      size: KSize.iconLg,
                                      color: shell.currentIndex == branch ? k.primary : k.textSecondary),
                                  const SizedBox(height: 3),
                                  Text(label,
                                      style: t.micro.copyWith(
                                          color: shell.currentIndex == branch ? k.primary : k.textSecondary,
                                          fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopShell extends ConsumerWidget {
  const _DesktopShell({required this.shell});
  final StatefulNavigationShell shell;

  static const _items = <(int, IconData, String)>[
    (Branch.workspace, KIcons.layout, 'Workspace'),
    (Branch.live, KIcons.phone, 'Live (phone)'),
    (Branch.batch, KIcons.batch, 'Batch'),
    (Branch.history, KIcons.history, 'History'),
    (Branch.gallery, KIcons.gallery, 'Reference gallery'),
    (Branch.key, KIcons.key, 'Dichotomous key'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = context.k;
    final width = MediaQuery.sizeOf(context).width;
    final collapsed = width < kSidebarCollapseWidth;
    final settings = ref.watch(settingsProvider);
    final online = ref.watch(onlineProvider);

    Widget item(int branch, IconData icon, String label) {
      final selected = shell.currentIndex == branch;
      return _SidebarItem(
        icon: icon,
        label: label,
        selected: selected,
        collapsed: collapsed,
        onTap: () => shell.goBranch(branch, initialLocation: selected),
      );
    }

    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.keyO, control: true): ImportIntent(),
        SingleActivator(LogicalKeyboardKey.keyE, control: true): ExportIntent(),
        SingleActivator(LogicalKeyboardKey.keyF, control: true): SearchIntent(),
        SingleActivator(LogicalKeyboardKey.equal): ZoomIntent(1.25),
        SingleActivator(LogicalKeyboardKey.equal, shift: true): ZoomIntent(1.25),
        SingleActivator(LogicalKeyboardKey.numpadAdd): ZoomIntent(1.25),
        SingleActivator(LogicalKeyboardKey.minus): ZoomIntent(0.8),
        SingleActivator(LogicalKeyboardKey.numpadSubtract): ZoomIntent(0.8),
      },
      child: Actions(
        actions: {
          ImportIntent: CallbackAction<ImportIntent>(onInvoke: (_) => context.pushTo(Routes.import)),
          ExportIntent: CallbackAction<ExportIntent>(
              onInvoke: (_) => showToast(context, 'Open an image or report to export it.')),
          SearchIntent: CallbackAction<SearchIntent>(onInvoke: (_) {
            shell.goBranch(Branch.history);
            return null;
          }),
          ZoomIntent: CallbackAction<ZoomIntent>(onInvoke: (_) => null),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            body: Row(
              children: [
                AnimatedContainer(
                  duration: KMotion.of(context, KMotion.base),
                  curve: KMotion.ease,
                  width: collapsed ? 72 : 232,
                  decoration: BoxDecoration(
                    color: Color.alphaBlend(k.surface.withValues(alpha: 0.55), k.background),
                    border: Border(right: BorderSide(color: k.separator)),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: KSpace.s12, vertical: KSpace.s16),
                      child: FocusTraversalGroup(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _Brand(collapsed: collapsed),
                            const SizedBox(height: KSpace.s16),
                            for (final (b, i, l) in _items) item(b, i, l),
                            const Spacer(),
                            item(Branch.settings, KIcons.settings, 'Settings'),
                            const SizedBox(height: KSpace.s8),
                            _ModelStatus(
                                collapsed: collapsed, version: settings.modelVersion, online: online),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(child: FocusTraversalGroup(child: shell)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.collapsed});
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final mark = Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: k.primary, width: 2)),
      alignment: Alignment.center,
      child: Container(width: 8, height: 8, decoration: BoxDecoration(color: k.primary, shape: BoxShape.circle)),
    );
    return Semantics(
      label: 'Kheryne',
      header: true,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(left: KSpace.s8, top: KSpace.s4),
        child: Row(children: [
          mark,
          if (!collapsed) ...[
            const SizedBox(width: KSpace.s12),
            Text('Kheryne', style: context.t.headline),
          ],
        ]),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({required this.icon, required this.label, required this.selected, required this.collapsed, required this.onTap});
  final IconData icon;
  final String label;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final t = context.t;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Pressable(
        onTap: onTap,
        selected: selected,
        semanticLabel: label,
        tooltip: collapsed ? label : null,
        borderRadius: KRadius.smAll,
        pressScale: 1,
        child: AnimatedContainer(
          duration: KMotion.of(context, KMotion.fast),
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(color: selected ? k.container : Colors.transparent, borderRadius: KRadius.smAll),
          child: Row(
            mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Icon(icon, size: KSize.icon, color: selected ? k.primary : k.textSecondary),
              if (!collapsed) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Text(label,
                      style: t.subhead.copyWith(
                          fontSize: 14, color: selected ? k.text : k.textSecondary, fontWeight: selected ? FontWeight.w600 : FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ModelStatus extends StatelessWidget {
  const _ModelStatus({required this.collapsed, required this.version, required this.online});
  final bool collapsed;
  final String version;
  final bool online;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final label = 'Models v$version · ${online ? 'up to date' : 'offline'}';
    final dot = Container(width: 8, height: 8, decoration: BoxDecoration(color: k.success, shape: BoxShape.circle));
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(left: 10),
        child: collapsed
            ? Tooltip(message: label, child: Align(alignment: Alignment.centerLeft, child: dot))
            : Row(children: [
                dot,
                const SizedBox(width: KSpace.s8),
                Expanded(child: Text(label, style: context.t.caption.copyWith(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
      ),
    );
  }
}
