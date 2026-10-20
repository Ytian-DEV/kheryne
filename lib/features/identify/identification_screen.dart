import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/router/routes.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import '../scan/filters.dart';
import 'box_actions.dart';
import 'identify_controller.dart';

/// Identification Mode: pink candidates, purple user boxes, check, analyze.
class IdentificationScreen extends ConsumerStatefulWidget {
  const IdentificationScreen({super.key, required this.specimenId, this.popoverFor});
  final String specimenId;

  /// Screen gallery: open the popover on this box id.
  final String? popoverFor;

  @override
  ConsumerState<IdentificationScreen> createState() => _IdentificationScreenState();
}

class _IdentificationScreenState extends ConsumerState<IdentificationScreen> {
  final _canvas = GlobalKey<BoxCanvasState>();
  String? _popoverId;
  Rect? _anchor;

  @override
  void initState() {
    super.initState();
    _popoverId = widget.popoverFor;
    // Anchor a preset popover once the canvas has been laid out.
    if (widget.popoverFor != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? setState(() {}) : null);
    }
  }

  IdentifyController get _c => ref.read(identifyControllerProvider(widget.specimenId).notifier);

  void _analyze(Detection d) {
    setState(() => _popoverId = null);
    context.pushTo(Routes.analysis(widget.specimenId, d.id));
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final t = context.t;
    final st = ref.watch(identifyControllerProvider(widget.specimenId));
    final adjustments = ref.watch(adjustmentsProvider)[widget.specimenId] ?? ImageAdjustments.none;
    final forced = ViewStateScope.of(context);
    final loading = forced == ViewState.loading || (st.loading && forced == null);
    final error = forced == ViewState.error || (st.error && forced == null);
    final selected = st.selected;
    final popover = st.detections.where((d) => d.id == _popoverId).firstOrNull;

    return Scaffold(
      appBar: KNavBar(
        title: 'Identify',
        subtitle: st.specimen == null ? null : '${st.specimen!.fileName} · ${st.specimen!.objective}× objective',
        actions: [
          KIconButton(
            icon: KIcons.adjust,
            label: 'Adjust image',
            onPressed: st.specimen == null ? null : () => context.pushTo(Routes.editor(widget.specimenId)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ColoredBox(
              color: k.canvas,
              child: error
                  ? Theme(
                      data: Theme.of(context),
                      child: ColoredBox(
                        color: k.background,
                        child: ErrorState(title: 'Couldn’t open this image', onRetry: _c.load),
                      ),
                    )
                  : loading || st.specimen == null
                      ? const _CanvasSkeleton()
                      : LayoutBuilder(builder: (context, c) {
                          return Stack(
                            children: [
                              Positioned.fill(
                                child: BoxCanvas(
                                  key: _canvas,
                                  specimen: st.specimen!,
                                  detections: st.detections,
                                  selectedId: st.selectedId,
                                  tool: st.tool,
                                  adjustments: adjustments,
                                  onSelect: (id) {
                                    _c.select(id);
                                    if (id == null) setState(() => _popoverId = null);
                                  },
                                  onCreate: (r) {
                                    _c.addUserBox(r);
                                    final id = ref.read(identifyControllerProvider(widget.specimenId)).selectedId;
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      final cs = _canvas.currentState;
                                      if (cs != null && mounted) {
                                        setState(() {
                                          _popoverId = id;
                                          _anchor = cs.toViewport(r);
                                        });
                                      }
                                    });
                                  },
                                  onChange: _c.move,
                                  onBoxTap: (d, r) => setState(() {
                                    _popoverId = d.id;
                                    _anchor = r;
                                  }),
                                ),
                              ),
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: KSpace.s12,
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: KSpace.s12, vertical: 6),
                                    decoration: BoxDecoration(color: k.canvas.withValues(alpha: 0.7), borderRadius: KRadius.pill),
                                    child: Semantics(
                                      liveRegion: true,
                                      child: Text(st.summary, style: t.captionStrong.copyWith(color: k.overlayText)),
                                    ),
                                  ),
                                ),
                              ),
                              if (popover != null) _popoverLayer(popover, c.biggest),
                            ],
                          );
                        }),
            ),
          ),
          _BottomPanel(
            tool: st.tool,
            selected: selected,
            onTool: (tool) {
              if (tool == null) {
                context.pushTo(Routes.editor(widget.specimenId));
                return;
              }
              setState(() => _popoverId = null);
              _c.setTool(tool);
            },
            onAnalyze: selected?.kind == BoxKind.confirmed ? () => _analyze(selected!) : null,
          ),
        ],
      ),
    );
  }

  Widget _popoverLayer(Detection d, Size area) {
    final anchor = _anchor ?? _canvas.currentState?.toViewport(d.rect) ?? Rect.fromCenter(center: area.center(Offset.zero), width: 10, height: 10);
    const w = 240.0;
    const h = 150.0;
    final below = anchor.bottom + KSpace.s8 + h < area.height;
    final left = (anchor.left).clamp(KSpace.s8, math.max(KSpace.s8, area.width - w - KSpace.s8));
    final top = below ? anchor.bottom + KSpace.s8 : math.max(KSpace.s8, anchor.top - h - 28);
    return Positioned(
      left: left.toDouble(),
      top: top,
      child: TweenAnimationBuilder<double>(
        key: ValueKey(d.id),
        tween: Tween(begin: 0.92, end: 1),
        duration: KMotion.of(context, KMotion.fast),
        curve: KMotion.spring,
        builder: (context, v, child) => Transform.scale(scale: v, alignment: below ? Alignment.topLeft : Alignment.bottomLeft, child: child),
        child: BoxPopover(
          detection: d,
          actions: boxActions(
            d,
            onCheck: () {
              setState(() => _popoverId = null);
              _c.check(d.id);
            },
            onAnalyze: () => _analyze(d),
            onRemove: () {
              setState(() => _popoverId = null);
              _c.remove(d.id);
            },
          ),
        ),
      ),
    );
  }
}

class _CanvasSkeleton extends StatelessWidget {
  const _CanvasSkeleton();

  @override
  Widget build(BuildContext context) => Center(
        child: FractionallySizedBox(
          widthFactor: 0.8,
          child: AspectRatio(
            aspectRatio: 1,
            child: Theme(
              data: Theme.of(context),
              child: const SkeletonBlock(height: double.infinity, radius: KRadius.full),
            ),
          ),
        ),
      );
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({required this.tool, required this.selected, required this.onTool, required this.onAnalyze});
  final CanvasTool tool;
  final Detection? selected;

  /// null = open filters.
  final ValueChanged<CanvasTool?> onTool;
  final VoidCallback? onAnalyze;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final t = context.t;
    final hint = switch ((tool, selected?.kind)) {
      (CanvasTool.draw, _) => 'Drag on the image to draw a box around anything Kheryne missed.',
      (_, BoxKind.confirmed) => 'Confirmed. Analyze it to read the head, stylet and tail.',
      (_, BoxKind.rejected) => 'Kheryne doesn’t think this is a plant-parasitic nematode.',
      (_, BoxKind.user) => 'Drag to move, use the corners to resize, then check it.',
      (_, BoxKind.ai) => 'Check this candidate to confirm it before analysis.',
      _ => 'Tap a box to check it. Only green boxes can be analyzed.',
    };
    return Container(
      decoration: BoxDecoration(
        color: k.surface,
        border: Border(top: BorderSide(color: k.separator)),
      ),
      padding: EdgeInsets.fromLTRB(KSpace.s16, KSpace.s12, KSpace.s16, MediaQuery.paddingOf(context).bottom + KSpace.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KSegmentedControl<int>(
            segments: const [(0, 'Select', KIcons.select), (1, 'Draw box', KIcons.drawBox), (2, 'Filters', KIcons.adjust)],
            value: tool == CanvasTool.draw ? 1 : 0,
            onChanged: (v) => onTool(switch (v) { 0 => CanvasTool.select, 1 => CanvasTool.draw, _ => null }),
          ),
          const SizedBox(height: KSpace.s12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(KIcons.info, size: 18, color: k.textSecondary),
              const SizedBox(width: KSpace.s8),
              Expanded(child: Text(hint, style: t.caption)),
            ],
          ),
          const SizedBox(height: KSpace.s12),
          KButton(label: 'Analyze nematode', icon: KIcons.scan, expand: true, onPressed: onAnalyze),
        ],
      ),
    );
  }
}
