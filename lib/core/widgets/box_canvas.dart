import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/theme.dart';
import 'detection_box.dart';
import 'micrograph.dart';

enum CanvasTool { select, draw, pan }

/// Zoomable specimen canvas with detection boxes.
///
/// - Pinch / scroll-wheel to zoom, drag to pan (select tool).
/// - Draw tool: one-finger drag draws a purple box.
/// - Selected purple boxes move by dragging and resize by corner handles.
/// - Tap a box to select it; right-click for a context menu on desktop.
///
/// Boxes are drawn in viewport space so strokes and labels stay crisp at
/// any zoom.
class BoxCanvas extends StatefulWidget {
  const BoxCanvas({
    super.key,
    required this.specimen,
    required this.detections,
    this.selectedId,
    this.tool = CanvasTool.select,
    this.onSelect,
    this.onCreate,
    this.onChange,
    this.onBoxTap,
    this.onBoxSecondaryTap,
    this.adjustments = ImageAdjustments.none,
    this.controller,
    this.longLabels = true,
    this.background,
    this.minScale = 1,
    this.maxScale = 8,
    this.imageOverride,
  });

  final Specimen specimen;
  final List<Detection> detections;
  final String? selectedId;
  final CanvasTool tool;
  final ValueChanged<String?>? onSelect;

  /// Called with a normalised rect when a new box is drawn.
  final ValueChanged<Rect>? onCreate;
  final void Function(String id, Rect rect)? onChange;

  /// Tap on a box, with the box rect in this widget's coordinates.
  final void Function(Detection d, Rect viewportRect)? onBoxTap;
  final void Function(Detection d, Offset globalPosition)? onBoxSecondaryTap;
  final ImageAdjustments adjustments;
  final TransformationController? controller;
  final bool longLabels;
  final Color? background;
  final double minScale;
  final double maxScale;

  /// Replaces the micrograph (e.g. a live frame).
  final Widget? imageOverride;

  @override
  State<BoxCanvas> createState() => BoxCanvasState();
}

enum _Mode { none, draw, move, resize, tap }

class BoxCanvasState extends State<BoxCanvas> {
  late TransformationController _tc = widget.controller ?? TransformationController();
  bool _interacting = false;
  _Mode _mode = _Mode.none;
  Offset _downAt = Offset.zero;
  Offset _last = Offset.zero;
  String? _activeId;
  Rect? _draft;
  Rect? _working;
  int _corner = 0;
  int _pointers = 0;
  Size _viewport = Size.zero;

  TransformationController get controller => _tc;

  Size get viewportSize => _viewport;

  @override
  void didUpdateWidget(BoxCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != null && widget.controller != _tc) _tc = widget.controller!;
  }

  @override
  void dispose() {
    if (widget.controller == null) _tc.dispose();
    super.dispose();
  }

  double get _side => math.min(_viewport.width, _viewport.height);
  Offset get _origin => Offset((_viewport.width - _side) / 2, (_viewport.height - _side) / 2);

  /// Image (normalised) → viewport.
  Rect toViewport(Rect r) {
    final child = Rect.fromLTRB(_origin.dx + r.left * _side, _origin.dy + r.top * _side, _origin.dx + r.right * _side,
        _origin.dy + r.bottom * _side);
    return MatrixUtils.transformRect(_tc.value, child);
  }

  /// Viewport → image (normalised).
  Offset toImage(Offset p) {
    final inv = Matrix4.inverted(_tc.value);
    final c = MatrixUtils.transformPoint(inv, p);
    return Offset((c.dx - _origin.dx) / _side, (c.dy - _origin.dy) / _side);
  }

  double get _scale => _tc.value.getMaxScaleOnAxis();

  void zoomBy(double factor) {
    final s = (_scale * factor).clamp(widget.minScale, widget.maxScale) / _scale;
    final c = Offset(_viewport.width / 2, _viewport.height / 2);
    _tc.value = _tc.value.clone()
      ..translateByDouble(c.dx, c.dy, 0, 1)
      ..scaleByDouble(s, s, 1, 1)
      ..translateByDouble(-c.dx, -c.dy, 0, 1);
  }

  void fit() => _tc.value = Matrix4.identity();

  void actualSize() {
    // 100% = one image pixel per logical pixel for a 1600 px source.
    const source = 1600.0;
    final s = (source / _side).clamp(widget.minScale, widget.maxScale);
    final c = Offset(_viewport.width / 2, _viewport.height / 2);
    _tc.value = Matrix4.identity()
      ..translateByDouble(c.dx, c.dy, 0, 1)
      ..scaleByDouble(s, s, 1, 1)
      ..translateByDouble(-c.dx, -c.dy, 0, 1);
  }

  /// Centres and zooms onto a normalised rect (used for the zoom animation).
  Matrix4 matrixFor(Rect r, {double padding = 0.25}) {
    final target = Rect.fromLTRB(_origin.dx + r.left * _side, _origin.dy + r.top * _side, _origin.dx + r.right * _side,
        _origin.dy + r.bottom * _side);
    final s = math.min(_viewport.width / (target.width * (1 + padding)), _viewport.height / (target.height * (1 + padding)))
        .clamp(widget.minScale, widget.maxScale);
    final dx = _viewport.width / 2 - target.center.dx * s;
    final dy = _viewport.height / 2 - target.center.dy * s;
    return Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(s, s, 1, 1);
  }

  Detection? _hit(Offset p) {
    final sel = widget.detections.where((d) => d.id == widget.selectedId);
    for (final d in [...sel, ...widget.detections.reversed]) {
      final r = toViewport(d.rect).inflate(6);
      final pill = Rect.fromLTWH(r.left, r.top - DetectionBox.pillHeight - 4, 120, DetectionBox.pillHeight + 4);
      if (r.contains(p) || pill.contains(p)) return d;
    }
    return null;
  }

  int _hitCorner(Detection d, Offset p) {
    final r = toViewport(d.rect);
    final corners = [r.topLeft, r.topRight, r.bottomLeft, r.bottomRight];
    for (var i = 0; i < 4; i++) {
      if ((corners[i] - p).distance < 22) return i;
    }
    return -1;
  }

  void _onDown(PointerDownEvent e) {
    _pointers++;
    if (_pointers > 1) {
      // Second finger: hand over to pinch zoom.
      _cancel();
      return;
    }
    _downAt = e.localPosition;
    _last = e.localPosition;
    if (e.buttons == kSecondaryMouseButton) {
      final d = _hit(e.localPosition);
      if (d != null) {
        widget.onSelect?.call(d.id);
        widget.onBoxSecondaryTap?.call(d, e.position);
      }
      _mode = _Mode.none;
      return;
    }
    if (widget.tool == CanvasTool.pan) {
      _mode = _Mode.none;
      return;
    }
    final selected = widget.detections.where((d) => d.id == widget.selectedId && d.kind == BoxKind.user).firstOrNull;
    if (selected != null) {
      final c = _hitCorner(selected, e.localPosition);
      if (c >= 0) {
        _start(_Mode.resize, selected);
        _corner = c;
        return;
      }
    }
    final hit = _hit(e.localPosition);
    if (hit != null) {
      if (hit.kind == BoxKind.user && hit.id == widget.selectedId) {
        _start(_Mode.move, hit);
      } else {
        _mode = _Mode.tap;
        _activeId = hit.id;
      }
      return;
    }
    if (widget.tool == CanvasTool.draw) {
      _mode = _Mode.draw;
      setState(() {
        _interacting = true;
        _draft = Rect.fromPoints(toImage(e.localPosition), toImage(e.localPosition));
      });
      return;
    }
    _mode = _Mode.tap;
    _activeId = null;
  }

  void _start(_Mode m, Detection d) {
    _mode = m;
    _activeId = d.id;
    setState(() {
      _interacting = true;
      _working = d.rect;
    });
  }

  void _onMove(PointerMoveEvent e) {
    if (_pointers > 1) return;
    final delta = e.localPosition - _last;
    _last = e.localPosition;
    final k = _side * _scale;
    final dn = Offset(delta.dx / k, delta.dy / k);
    switch (_mode) {
      case _Mode.draw:
        setState(() => _draft = Rect.fromPoints(toImage(_downAt), _clampPoint(toImage(e.localPosition))));
      case _Mode.move:
        final r = _working!.shift(dn);
        setState(() => _working = r.shift(Offset(
            r.left < 0 ? -r.left : (r.right > 1 ? 1 - r.right : 0), r.top < 0 ? -r.top : (r.bottom > 1 ? 1 - r.bottom : 0))));
      case _Mode.resize:
        final r = _working!;
        final p = _clampPoint(toImage(e.localPosition));
        const m = 0.02;
        setState(() => _working = switch (_corner) {
              0 => Rect.fromLTRB(math.min(p.dx, r.right - m), math.min(p.dy, r.bottom - m), r.right, r.bottom),
              1 => Rect.fromLTRB(r.left, math.min(p.dy, r.bottom - m), math.max(p.dx, r.left + m), r.bottom),
              2 => Rect.fromLTRB(math.min(p.dx, r.right - m), r.top, r.right, math.max(p.dy, r.top + m)),
              _ => Rect.fromLTRB(r.left, r.top, math.max(p.dx, r.left + m), math.max(p.dy, r.top + m)),
            });
      case _Mode.tap:
        if ((e.localPosition - _downAt).distance > 8) _mode = _Mode.none;
      case _Mode.none:
        break;
    }
  }

  Offset _clampPoint(Offset p) => Offset(p.dx.clamp(0, 1), p.dy.clamp(0, 1));

  void _onUp(PointerUpEvent e) {
    _pointers = math.max(0, _pointers - 1);
    switch (_mode) {
      case _Mode.draw:
        final r = _draft;
        if (r != null && r.width > 0.03 && r.height > 0.03) widget.onCreate?.call(r);
      case _Mode.move:
      case _Mode.resize:
        if (_working != null && _activeId != null) widget.onChange?.call(_activeId!, _working!);
      case _Mode.tap:
        if (_activeId == null) {
          widget.onSelect?.call(null);
        } else {
          final d = widget.detections.firstWhere((d) => d.id == _activeId);
          widget.onSelect?.call(d.id);
          widget.onBoxTap?.call(d, toViewport(d.rect));
        }
      case _Mode.none:
        break;
    }
    _cancel();
  }

  void _cancel() {
    _mode = _Mode.none;
    if (_interacting || _draft != null || _working != null) {
      setState(() {
        _interacting = false;
        _draft = null;
        _working = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return LayoutBuilder(builder: (context, c) {
      _viewport = c.biggest;
      final side = _side;
      return ColoredBox(
        color: widget.background ?? k.canvas,
        child: Listener(
          onPointerDown: _onDown,
          onPointerMove: _onMove,
          onPointerUp: _onUp,
          onPointerCancel: (_) {
            _pointers = math.max(0, _pointers - 1);
            _cancel();
          },
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  transformationController: _tc,
                  minScale: widget.minScale,
                  maxScale: widget.maxScale,
                  panEnabled: !_interacting && widget.tool != CanvasTool.draw,
                  boundaryMargin: EdgeInsets.all(side * 0.5),
                  child: SizedBox(
                    width: c.maxWidth,
                    height: c.maxHeight,
                    child: Center(
                      child: SizedBox.square(
                        dimension: side,
                        child: widget.imageOverride ??
                            Micrograph(specimen: widget.specimen, fit: BoxFit.contain, adjustments: widget.adjustments),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _tc,
                    builder: (context, _) => Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        for (final d in widget.detections)
                          _place(
                            d.id == _activeId && _working != null ? d.copyWith(rect: _working) : d,
                            selected: d.id == widget.selectedId,
                          ),
                        if (_draft != null) _place(Detection(id: '_draft', rect: _draft!, kind: BoxKind.user), selected: true),
                      ],
                    ),
                  ),
                ),
              ),
              // Semantic handles for screen readers: one focusable target per box.
              for (final d in widget.detections)
                Positioned.fromRect(
                  rect: toViewport(d.rect),
                  child: Semantics(
                    button: true,
                    selected: d.id == widget.selectedId,
                    label: boxSemantics(d),
                    onTap: () {
                      widget.onSelect?.call(d.id);
                      widget.onBoxTap?.call(d, toViewport(d.rect));
                    },
                    child: const SizedBox.expand(),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }

  Widget _place(Detection d, {required bool selected}) {
    final r = toViewport(d.rect);
    return Positioned.fromRect(
      rect: r,
      child: DetectionBox(detection: d, selected: selected, longLabel: widget.longLabels),
    );
  }
}
