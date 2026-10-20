import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/providers.dart';

enum BatchStatus { queued, running, done, noNematode, failed }

@immutable
class BatchItem {
  const BatchItem({required this.specimen, this.status = BatchStatus.queued, this.progress = 0, this.report});
  final Specimen specimen;
  final BatchStatus status;
  final double progress;
  final Report? report;

  BatchItem copyWith({BatchStatus? status, double? progress, Report? report}) =>
      BatchItem(specimen: specimen, status: status ?? this.status, progress: progress ?? this.progress, report: report ?? this.report);
}

@immutable
class BatchState {
  const BatchState({this.items = const [], this.running = false});
  final List<BatchItem> items;
  final bool running;

  bool get isEmpty => items.isEmpty;
  bool get finished => items.isNotEmpty && items.every((i) => i.status != BatchStatus.queued && i.status != BatchStatus.running);
  int get doneCount => items.where((i) => i.status != BatchStatus.queued && i.status != BatchStatus.running).length;
  double get overall => items.isEmpty ? 0 : items.fold<double>(0, (a, i) => a + (i.status == BatchStatus.running ? i.progress : (i.status == BatchStatus.queued ? 0 : 1))) / items.length;
}

class BatchController extends Notifier<BatchState> {
  bool _cancel = false;

  @override
  BatchState build() => const BatchState();

  void add(List<Specimen> specimens) => state = BatchState(
        items: [...state.items, for (final s in specimens) if (!state.items.any((i) => i.specimen.id == s.id)) BatchItem(specimen: s)],
      );

  void clear() {
    _cancel = true;
    state = const BatchState();
  }

  void cancel() {
    _cancel = true;
    state = BatchState(items: state.items, running: false);
  }

  /// Seeds a state directly (screen gallery and screenshots).
  void seed(BatchState s) => state = s;

  Future<void> start() async {
    if (state.running) return;
    _cancel = false;
    state = BatchState(items: state.items, running: true);
    final repo = ref.read(identificationRepositoryProvider);
    for (var i = 0; i < state.items.length; i++) {
      if (_cancel || !ref.mounted) return;
      final item = state.items[i];
      if (item.status != BatchStatus.queued) continue;
      _set(i, item.copyWith(status: BatchStatus.running, progress: 0.05));
      try {
        final dets = await repo.detect(item.specimen);
        final target = dets.where((d) => (d.confidence ?? 0) >= 0.65).firstOrNull;
        if (target == null) {
          _set(i, item.copyWith(status: BatchStatus.noNematode, progress: 1));
          continue;
        }
        await for (final p in repo.analyze(item.specimen, target)) {
          if (_cancel || !ref.mounted) return;
          if (p.report != null) ref.read(pendingReportsProvider.notifier).put(p.report!);
          final stageIndex = AnalysisStage.values.indexOf(p.stage);
          _set(i, state.items[i].copyWith(progress: ((stageIndex + p.stageProgress) / 6).clamp(0.05, 1.0), report: p.report));
        }
        _set(i, state.items[i].copyWith(status: BatchStatus.done, progress: 1));
      } catch (_) {
        _set(i, item.copyWith(status: BatchStatus.failed, progress: 1));
      }
    }
    if (ref.mounted) state = BatchState(items: state.items, running: false);
  }

  void _set(int i, BatchItem item) {
    final items = [...state.items];
    items[i] = item;
    state = BatchState(items: items, running: state.running);
  }
}

final batchProvider = NotifierProvider<BatchController, BatchState>(BatchController.new);
