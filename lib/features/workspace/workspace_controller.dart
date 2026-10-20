import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/providers.dart';

enum InspectorTab { adjust, detections, report, measure }

@immutable
class WorkspaceRun {
  const WorkspaceRun({required this.detectionId, required this.stage, required this.progress, this.reportId});
  final String detectionId;
  final AnalysisStage stage;
  final double progress;
  final String? reportId;
  bool get running => reportId == null;
}

@immutable
class WorkspaceState {
  const WorkspaceState({
    this.images = const [],
    this.selectedId,
    this.tab = InspectorTab.report,
    this.inspectorWidth = 400,
    this.loading = true,
    this.runs = const {},
    this.filter = '',
  });

  final List<Specimen> images;
  final String? selectedId;
  final InspectorTab tab;
  final double inspectorWidth;
  final bool loading;

  /// Latest analysis per specimen id.
  final Map<String, WorkspaceRun> runs;
  final String filter;

  Specimen? get selected => images.where((s) => s.id == selectedId).firstOrNull;

  List<Specimen> get visible =>
      filter.isEmpty ? images : images.where((s) => s.fileName.toLowerCase().contains(filter.toLowerCase())).toList();

  WorkspaceState copyWith({
    List<Specimen>? images,
    String? selectedId,
    InspectorTab? tab,
    double? inspectorWidth,
    bool? loading,
    Map<String, WorkspaceRun>? runs,
    String? filter,
  }) =>
      WorkspaceState(
        images: images ?? this.images,
        selectedId: selectedId ?? this.selectedId,
        tab: tab ?? this.tab,
        inspectorWidth: inspectorWidth ?? this.inspectorWidth,
        loading: loading ?? this.loading,
        runs: runs ?? this.runs,
        filter: filter ?? this.filter,
      );
}

class WorkspaceController extends Notifier<WorkspaceState> {
  bool _seeded = false;

  @override
  WorkspaceState build() {
    Future.microtask(_load);
    return const WorkspaceState();
  }

  Future<void> _load() async {
    final list = await ref.read(identificationRepositoryProvider).specimens();
    if (!ref.mounted || _seeded) return;
    final images = list.take(8).toList();
    state = state.copyWith(images: images, selectedId: images.length > 1 ? images[1].id : images.firstOrNull?.id, loading: false);
  }

  void select(String id) => state = state.copyWith(selectedId: id);
  void setTab(InspectorTab t) => state = state.copyWith(tab: t);
  void setWidth(double w) => state = state.copyWith(inspectorWidth: w.clamp(280, 480));
  void setFilter(String f) => state = state.copyWith(filter: f);

  void remove(String id) {
    final images = state.images.where((s) => s.id != id).toList();
    state = WorkspaceState(
      images: images,
      selectedId: state.selectedId == id ? images.firstOrNull?.id : state.selectedId,
      tab: state.tab,
      inspectorWidth: state.inspectorWidth,
      loading: false,
      runs: state.runs,
      filter: state.filter,
    );
  }

  void importAll(List<Specimen> list) {
    final add = list.where((s) => !state.images.any((i) => i.id == s.id)).toList();
    state = state.copyWith(images: [...add, ...state.images], selectedId: add.firstOrNull?.id ?? state.selectedId, loading: false);
  }

  /// "Analyze this frame" from the paired phone.
  void addFrozenFrame(Specimen s) => importAll([s]);

  void clear() => state = WorkspaceState(loading: false, inspectorWidth: state.inspectorWidth);

  /// Seeds a state directly (screen gallery and screenshots).
  void seed(WorkspaceState s) {
    _seeded = true;
    state = s;
  }

  Future<void> analyze(Specimen s, Detection d) async {
    final repo = ref.read(identificationRepositoryProvider);
    state = state.copyWith(tab: InspectorTab.report, runs: {...state.runs, s.id: WorkspaceRun(detectionId: d.id, stage: AnalysisStage.regions, progress: 0)});
    await for (final p in repo.analyze(s, d)) {
      if (!ref.mounted) return;
      if (p.report != null) ref.read(pendingReportsProvider.notifier).put(p.report!);
      state = state.copyWith(runs: {
        ...state.runs,
        s.id: WorkspaceRun(detectionId: d.id, stage: p.stage, progress: p.stageProgress, reportId: p.report?.id),
      });
    }
  }
}

final workspaceProvider = NotifierProvider<WorkspaceController, WorkspaceState>(WorkspaceController.new);
