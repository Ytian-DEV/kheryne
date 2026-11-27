import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/box_canvas.dart';

@immutable
class IdentifyState {
  const IdentifyState({
    this.specimen,
    this.detections = const [],
    this.selectedId,
    this.tool = CanvasTool.select,
    this.loading = true,
    this.error = false,
    this.statusMessage,
  });

  final Specimen? specimen;
  final List<Detection> detections;
  final String? selectedId;
  final CanvasTool tool;
  final bool loading;
  final bool error;
  final String? statusMessage;

  Detection? get selected => detections.where((d) => d.id == selectedId).firstOrNull;
  int get detectedCount => detections.where((d) => !d.id.startsWith('u')).length;
  int get userCount => detections.where((d) => d.id.startsWith('u')).length;
  int get confirmedCount => detections.where((d) => d.kind == BoxKind.confirmed).length;

  String get summary {
    final parts = ['$detectedCount detected'];
    if (userCount > 0) parts.add('$userCount marked by you');
    if (confirmedCount > 0) parts.add('$confirmedCount confirmed');
    return parts.join(' · ');
  }

  IdentifyState copyWith({
    Specimen? specimen,
    List<Detection>? detections,
    String? selectedId,
    bool clearSelection = false,
    CanvasTool? tool,
    bool? loading,
    bool? error,
    String? statusMessage,
    bool clearStatus = false,
  }) =>
      IdentifyState(
        specimen: specimen ?? this.specimen,
        detections: detections ?? this.detections,
        selectedId: clearSelection ? null : (selectedId ?? this.selectedId),
        tool: tool ?? this.tool,
        loading: loading ?? this.loading,
        error: error ?? this.error,
        statusMessage: clearStatus ? null : (statusMessage ?? this.statusMessage),
      );
}

/// Box flow: pink candidate or purple user box → check → green (confirmed)
/// or red (not a nematode) → analyze (green only) → report.
class IdentifyController extends Notifier<IdentifyState> {
  IdentifyController(this.specimenId);
  final String specimenId;
  int _seq = 0;
  bool _seeded = false;

  @override
  IdentifyState build() {
    Future.microtask(load);
    return const IdentifyState();
  }

  Future<void> load() async {
    final repo = ref.read(identificationRepositoryProvider);
    try {
      final s = await repo.specimen(specimenId);
      if (!ref.mounted) return;
      if (s == null) {
        state = state.copyWith(loading: false, error: true);
        return;
      }
      final d = await repo.detect(s);
      if (!ref.mounted || _seeded) return;
      state = state.copyWith(specimen: s, detections: d, loading: false, error: false);
    } catch (_) {
      if (ref.mounted) state = state.copyWith(loading: false, error: true);
    }
  }

  void setTool(CanvasTool t) => state = state.copyWith(tool: t, clearSelection: t == CanvasTool.draw);

  void select(String? id) {
    if (id != state.selectedId) Haptics.selection();
    state = id == null ? state.copyWith(clearSelection: true) : state.copyWith(selectedId: id);
  }

  void addUserBox(Rect r) {
    final d = Detection(id: 'u${++_seq}', rect: r, kind: BoxKind.user);
    Haptics.light();
    state = state.copyWith(detections: [...state.detections, d], selectedId: d.id, tool: CanvasTool.select);
  }

  void move(String id, Rect r) =>
      state = state.copyWith(detections: [for (final d in state.detections) d.id == id ? d.copyWith(rect: r) : d]);

  void remove(String id) => state = state.copyWith(
      detections: state.detections.where((d) => d.id != id).toList(), clearSelection: state.selectedId == id);

  Future<void> check(String id) async {
    final s = state.specimen;
    final target = state.detections.where((d) => d.id == id).firstOrNull;
    if (s == null || target == null) return;
    _replace(target.copyWith(checking: true));
    try {
      final res = await ref.read(identificationRepositoryProvider).checkBox(s, target.rect);
      if (!ref.mounted) return;
      final current = state.detections.where((d) => d.id == id).firstOrNull;
      if (current == null) return;
      Haptics.light();
      state = state.copyWith(clearStatus: true);
      _replace(Detection(
        id: current.id,
        rect: current.rect,
        kind: res.isNematode ? BoxKind.confirmed : BoxKind.rejected,
        confidence: res.confidence,
        rejectReason: res.reason,
      ));
    } catch (e) {
      if (!ref.mounted) return;
      final current = state.detections.where((d) => d.id == id).firstOrNull;
      if (current != null) _replace(current.copyWith(checking: false));
      state = state.copyWith(statusMessage: e.toString());
    }
  }

  void _replace(Detection d) =>
      state = state.copyWith(detections: [for (final x in state.detections) x.id == d.id ? d : x]);

  /// Seeds a state directly (screen gallery and tests).
  void seed(IdentifyState s) {
    _seeded = true;
    state = s;
  }
}

final identifyControllerProvider =
    NotifierProvider.family<IdentifyController, IdentifyState, String>(IdentifyController.new);
