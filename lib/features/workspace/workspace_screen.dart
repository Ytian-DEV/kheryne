import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/layout/app_shell.dart';
import '../../core/layout/scan_theme.dart';
import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/router/routes.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import '../identify/identify_controller.dart';
import '../scan/filters.dart';
import 'inspector.dart';
import 'workspace_controller.dart';

/// Windows main screen: filmstrip, zoomable canvas with box tools, and the
/// inspector. Dark by default for dim labs.
class WorkspaceScreen extends ConsumerStatefulWidget {
  const WorkspaceScreen({super.key});

  @override
  ConsumerState<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends ConsumerState<WorkspaceScreen> {
  final _canvas = GlobalKey<BoxCanvasState>();
  final _focus = FocusNode(debugLabel: 'workspace');
  final _searchFocus = FocusNode(debugLabel: 'workspace search');
  final _tc = TransformationController();
  CanvasTool? _spaceRestore;

  @override
  void dispose() {
    _focus.dispose();
    _searchFocus.dispose();
    _tc.dispose();
    super.dispose();
  }

  IdentifyController? _ic(Specimen? s) => s == null ? null : ref.read(identifyControllerProvider(s.id).notifier);

  void _identify(Specimen? s) {
    if (s == null) return;
    final st = ref.read(identifyControllerProvider(s.id));
    final sel = st.selected;
    if (sel != null && sel.kind == BoxKind.confirmed) {
      ref.read(workspaceProvider.notifier).analyze(s, sel);
    } else if (sel != null && (sel.kind == BoxKind.ai || sel.kind == BoxKind.user)) {
      _ic(s)!.check(sel.id);
      ref.read(workspaceProvider.notifier).setTab(InspectorTab.detections);
    } else {
      final confirmed = st.detections.where((d) => d.kind == BoxKind.confirmed).firstOrNull;
      if (confirmed != null) {
        _ic(s)!.select(confirmed.id);
        ref.read(workspaceProvider.notifier).analyze(s, confirmed);
        return;
      }
      for (final d in st.detections.where((d) => d.kind == BoxKind.ai || d.kind == BoxKind.user)) {
        _ic(s)!.check(d.id);
      }
      ref.read(workspaceProvider.notifier).setTab(InspectorTab.detections);
      showToast(context, 'Checking candidates. Select a green box, then press Identify again.');
    }
  }

  void _export(Specimen? s) {
    final run = s == null ? null : ref.read(workspaceProvider).runs[s.id];
    if (run?.reportId != null) {
      context.pushTo(Routes.reportPdf(run!.reportId!));
    } else {
      showToast(context, 'Identify a nematode first, then export its report.');
    }
  }

  Future<void> _boxMenu(Specimen s, Detection d, Offset pos) async {
    final pick = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx + 1, pos.dy + 1),
      items: [
        if (d.kind == BoxKind.confirmed) const PopupMenuItem(value: 'analyze', child: Text('Analyze nematode')),
        if (d.kind != BoxKind.confirmed) const PopupMenuItem(value: 'check', child: Text('Check if nematode')),
        const PopupMenuItem(value: 'zoom', child: Text('Zoom to box')),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'remove', child: Text('Remove box')),
      ],
    );
    switch (pick) {
      case 'analyze':
        ref.read(workspaceProvider.notifier).analyze(s, d);
      case 'check':
        _ic(s)!.check(d.id);
      case 'zoom':
        final cs = _canvas.currentState;
        if (cs != null) _tc.value = cs.matrixFor(d.rect, padding: 0.6);
      case 'remove':
        _ic(s)!.remove(d.id);
    }
  }

  Future<void> _thumbMenu(Specimen s, Offset pos) async {
    final pick = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx + 1, pos.dy + 1),
      items: const [
        PopupMenuItem(value: 'open', child: Text('Open')),
        PopupMenuItem(value: 'compare', child: Text('Compare with reference')),
        PopupMenuDivider(),
        PopupMenuItem(value: 'remove', child: Text('Remove from workspace')),
      ],
    );
    if (!mounted) return;
    switch (pick) {
      case 'open':
        ref.read(workspaceProvider.notifier).select(s.id);
      case 'compare':
        context.pushTo(Routes.compare(s.id, _compareGenus(s)));
      case 'remove':
        ref.read(workspaceProvider.notifier).remove(s.id);
    }
  }

  String _compareGenus(Specimen s) {
    final run = ref.read(workspaceProvider).runs[s.id];
    final r = run?.reportId == null ? null : ref.read(pendingReportsProvider)[run!.reportId!];
    return r?.genus ?? 'Pratylenchus';
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e, Specimen? s) {
    if (s == null) return KeyEventResult.ignored;
    final ic = _ic(s)!;
    final st = ref.read(identifyControllerProvider(s.id));
    if (e.logicalKey == LogicalKeyboardKey.space) {
      if (e is KeyDownEvent && _spaceRestore == null) {
        _spaceRestore = st.tool;
        ic.setTool(CanvasTool.pan);
      } else if (e is KeyUpEvent && _spaceRestore != null) {
        ic.setTool(_spaceRestore!);
        _spaceRestore = null;
      }
      return KeyEventResult.handled;
    }
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.delete || e.logicalKey == LogicalKeyboardKey.backspace) {
      final sel = st.selected;
      if (sel != null) ic.remove(sel.id);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.escape) {
      ic.select(null);
      ic.setTool(CanvasTool.select);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.keyB) {
      ic.setTool(st.tool == CanvasTool.draw ? CanvasTool.select : CanvasTool.draw);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final ws = ref.watch(workspaceProvider);
    final s = ws.selected;
    final forced = ViewStateScope.of(context);
    return ScanTheme(
      child: Builder(builder: (context) {
        final k = context.k;
        final t = context.t;
        final ist = s == null ? null : ref.watch(identifyControllerProvider(s.id));
        final adjustments = s == null ? ImageAdjustments.none : (ref.watch(adjustmentsProvider)[s.id] ?? ImageAdjustments.none);
        final empty = forced == ViewState.empty || (!ws.loading && ws.images.isEmpty);
        final loading = forced == ViewState.loading || (ws.loading && forced == null);

        Widget toolbar() {
          Widget tb(IconData icon, String label, VoidCallback? onTap, {bool active = false, bool primary = false, String? shortcut}) => Padding(
                padding: const EdgeInsets.only(right: KSpace.s4),
                child: Pressable(
                  onTap: onTap,
                  semanticLabel: label,
                  tooltip: shortcut == null ? label : '$label ($shortcut)',
                  selected: active,
                  borderRadius: KRadius.smAll,
                  child: Opacity(
                    opacity: onTap == null ? 0.4 : 1,
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: primary ? k.primary : (active ? k.container : Colors.transparent),
                        borderRadius: KRadius.smAll,
                      ),
                      child: Row(children: [
                        Icon(icon, size: 18, color: primary ? k.onPrimary : (active ? k.primary : k.text)),
                        const SizedBox(width: 6),
                        Text(label, style: t.subhead.copyWith(fontSize: 13, color: primary ? k.onPrimary : k.text)),
                      ]),
                    ),
                  ),
                ),
              );
          final drawing = ist?.tool == CanvasTool.draw;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: KSpace.s12, vertical: KSpace.s8),
            decoration: BoxDecoration(color: k.background, border: Border(bottom: BorderSide(color: k.separator))),
            child: Row(children: [
              tb(KIcons.upload, 'Import', () => context.pushTo(Routes.import), shortcut: 'Ctrl+O'),
              tb(KIcons.scan, 'Identify', s == null ? null : () => _identify(s), primary: true),
              Container(width: 1, height: 20, margin: const EdgeInsets.symmetric(horizontal: KSpace.s8), color: k.separator),
              tb(KIcons.drawBox, 'Draw box', s == null ? null : () => _ic(s)!.setTool(drawing ? CanvasTool.select : CanvasTool.draw), active: drawing, shortcut: 'B'),
              tb(KIcons.ruler, 'Measure', s == null ? null : () => ref.read(workspaceProvider.notifier).setTab(InspectorTab.measure)),
              tb(KIcons.compare, 'Compare', s == null ? null : () => context.pushTo(Routes.compare(s.id, _compareGenus(s)))),
              tb(KIcons.export, 'Export', s == null ? null : () => _export(s), shortcut: 'Ctrl+E'),
              const Spacer(),
              SizedBox(
                width: 240,
                height: 36,
                child: TextField(
                  focusNode: _searchFocus,
                  onChanged: ref.read(workspaceProvider.notifier).setFilter,
                  style: t.subhead.copyWith(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search images',
                    contentPadding: const EdgeInsets.symmetric(horizontal: KSpace.s8),
                    prefixIcon: const Icon(KIcons.search, size: 16),
                    prefixIconConstraints: const BoxConstraints(minWidth: 32),
                    suffixText: 'Ctrl F',
                    suffixStyle: t.micro,
                    fillColor: k.surface,
                  ),
                ),
              ),
            ]),
          );
        }

        Widget filmstrip() => Container(
              width: 120,
              decoration: BoxDecoration(color: k.background, border: Border(right: BorderSide(color: k.separator))),
              child: loading
                  ? ListView(padding: const EdgeInsets.all(KSpace.s12), children: [
                      for (var i = 0; i < 5; i++) const Padding(padding: EdgeInsets.only(bottom: KSpace.s8), child: SkeletonBlock(height: 96, radius: KRadius.sm)),
                    ])
                  : ListView(
                      padding: const EdgeInsets.all(KSpace.s12),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: KSpace.s8),
                          child: Text('${ws.visible.length} images', style: t.micro),
                        ),
                        for (final img in ws.visible)
                          Padding(
                            padding: const EdgeInsets.only(bottom: KSpace.s8),
                            child: Pressable(
                              onTap: () => ref.read(workspaceProvider.notifier).select(img.id),
                              onSecondaryTapDown: (d) => _thumbMenu(img, d.globalPosition),
                              selected: img.id == ws.selectedId,
                              semanticLabel: img.fileName,
                              tooltip: img.fileName,
                              borderRadius: KRadius.smAll,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: KRadius.smAll,
                                  border: Border.all(color: img.id == ws.selectedId ? k.primary : Colors.transparent, width: 2),
                                ),
                                padding: const EdgeInsets.all(2),
                                child: Column(children: [
                                  ClipRRect(borderRadius: BorderRadius.circular(6), child: AspectRatio(aspectRatio: 1, child: Micrograph(specimen: img))),
                                  const SizedBox(height: 4),
                                  Text(img.fileName, style: t.micro, maxLines: 1, overflow: TextOverflow.ellipsis),
                                ]),
                              ),
                            ),
                          ),
                      ],
                    ),
            );

        Widget canvas() {
          if (loading) {
            return const Center(child: SizedBox.square(dimension: 420, child: SkeletonBlock(height: 420, radius: KRadius.full)));
          }
          if (empty) {
            return EmptyState(
              art: LineArt.slides,
              message: 'Import images to start.',
              detail: 'Drop micrographs here, or press Ctrl+O. Kheryne marks likely nematodes for you.',
              action: 'Import images',
              onAction: () => context.pushTo(Routes.import),
            );
          }
          if (s == null || ist == null || ist.loading) {
            return const Center(child: SkeletonBlock(width: 420, height: 420, radius: KRadius.full));
          }
          return Stack(children: [
            Positioned.fill(
              child: BoxCanvas(
                key: _canvas,
                specimen: s,
                detections: ist.detections,
                selectedId: ist.selectedId,
                tool: ist.tool,
                controller: _tc,
                adjustments: adjustments,
                onSelect: _ic(s)!.select,
                onCreate: _ic(s)!.addUserBox,
                onChange: _ic(s)!.move,
                onBoxTap: (d, _) => ref.read(workspaceProvider.notifier).setTab(d.kind == BoxKind.confirmed ? InspectorTab.report : InspectorTab.detections),
                onBoxSecondaryTap: (d, pos) => _boxMenu(s, d, pos),
              ),
            ),
            Positioned(
              top: KSpace.s12,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: KSpace.s12, vertical: 6),
                  decoration: BoxDecoration(color: k.canvas.withValues(alpha: 0.7), borderRadius: KRadius.pill),
                  child: Text(ist.summary, style: t.captionStrong.copyWith(color: k.overlayText)),
                ),
              ),
            ),
            Positioned(left: KSpace.s16, bottom: KSpace.s16, child: _ZoomControls(tc: _tc, canvas: _canvas)),
            Positioned(right: KSpace.s16, bottom: KSpace.s16, child: _Minimap(specimen: s, tc: _tc, canvas: _canvas)),
          ]);
        }

        return Actions(
          actions: {
            ZoomIntent: CallbackAction<ZoomIntent>(onInvoke: (i) => _canvas.currentState?.zoomBy(i.factor)),
            ExportIntent: CallbackAction<ExportIntent>(onInvoke: (_) => _export(s)),
            SearchIntent: CallbackAction<SearchIntent>(onInvoke: (_) => _searchFocus.requestFocus()),
          },
          child: Focus(
            focusNode: _focus,
            autofocus: true,
            onKeyEvent: (n, e) => _searchFocus.hasFocus ? KeyEventResult.ignored : _onKey(n, e, s),
            child: Scaffold(
              backgroundColor: k.canvas,
              body: Column(children: [
                toolbar(),
                Expanded(
                  child: Row(children: [
                    filmstrip(),
                    Expanded(child: ColoredBox(color: k.canvas, child: canvas())),
                    MouseRegion(
                      cursor: SystemMouseCursors.resizeColumn,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onHorizontalDragUpdate: (d) => ref.read(workspaceProvider.notifier).setWidth(ws.inspectorWidth - d.delta.dx),
                        child: Semantics(label: 'Resize inspector', child: Container(width: 6, color: k.separator)),
                      ),
                    ),
                    SizedBox(width: ws.inspectorWidth, child: Inspector(specimen: empty ? null : s)),
                  ]),
                ),
              ]),
            ),
          ),
        );
      }),
    );
  }
}

class _ZoomControls extends StatelessWidget {
  const _ZoomControls({required this.tc, required this.canvas});
  final TransformationController tc;
  final GlobalKey<BoxCanvasState> canvas;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final t = context.t;
    return Container(
      padding: const EdgeInsets.all(KSpace.s4),
      decoration: BoxDecoration(color: k.surface.withValues(alpha: 0.92), borderRadius: KRadius.smAll, border: Border.all(color: k.separator)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        KIconButton(icon: KIcons.minus, label: 'Zoom out (-)', size: 16, dimension: 32, onPressed: () => canvas.currentState?.zoomBy(0.8)),
        AnimatedBuilder(
          animation: tc,
          builder: (context, _) => SizedBox(
            width: 52,
            child: Text('${(tc.value.getMaxScaleOnAxis() * 100).round()}%',
                textAlign: TextAlign.center, style: t.captionStrong.copyWith(fontFeatures: KType.tabular, color: k.text)),
          ),
        ),
        KIconButton(icon: KIcons.plus, label: 'Zoom in (+)', size: 16, dimension: 32, onPressed: () => canvas.currentState?.zoomBy(1.25)),
        KIconButton(icon: KIcons.fit, label: 'Fit to window', size: 16, dimension: 32, onPressed: () => canvas.currentState?.fit()),
        Pressable(
          onTap: () => canvas.currentState?.actualSize(),
          semanticLabel: 'Actual size, 100 percent',
          tooltip: 'Actual size',
          borderRadius: KRadius.smAll,
          child: SizedBox(height: 32, child: Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Text('1:1', style: t.captionStrong.copyWith(color: k.text))))),
        ),
      ]),
    );
  }
}

class _Minimap extends StatelessWidget {
  const _Minimap({required this.specimen, required this.tc, required this.canvas});
  final Specimen specimen;
  final TransformationController tc;
  final GlobalKey<BoxCanvasState> canvas;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    const size = 132.0;
    return Semantics(
      label: 'Minimap',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(borderRadius: KRadius.smAll, border: Border.all(color: k.separator)),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          Positioned.fill(child: Micrograph(specimen: specimen, fit: BoxFit.contain)),
          AnimatedBuilder(
            animation: tc,
            builder: (context, _) {
              final cs = canvas.currentState;
              if (cs == null || tc.value.getMaxScaleOnAxis() <= 1.01) return const SizedBox.shrink();
              // Visible part of the image, in normalised image space.
              final a = cs.toImage(Offset.zero);
              final b = cs.toImage(cs.viewportSize.bottomRight(Offset.zero));
              final r = Rect.fromPoints(a, b).intersect(const Rect.fromLTWH(0, 0, 1, 1));
              if (r.isEmpty) return const SizedBox.shrink();
              return Positioned(
                left: r.left * size,
                top: r.top * size,
                width: r.width * size,
                height: r.height * size,
                child: DecoratedBox(
                  decoration: BoxDecoration(border: Border.all(color: k.primary, width: 1.5), borderRadius: BorderRadius.circular(3)),
                ),
              );
            },
          ),
        ]),
      ),
    );
  }
}
