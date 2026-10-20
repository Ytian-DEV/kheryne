import 'dart:ui';

import '../models/models.dart';

/// Everything the UI needs from identification. The mock implementation
/// lives in `lib/mock/mock_repository.dart`; the real one will wrap the
/// on-device detector/classifier and a SQLite store.
abstract interface class IdentificationRepository {
  /// Specimens already on the device (imports, captures, workspace).
  Future<List<Specimen>> specimens();

  Future<Specimen?> specimen(String id);

  /// Candidate boxes for a specimen (pink boxes).
  Future<List<Detection>> detect(Specimen specimen);

  /// "Check if nematode" for a user-drawn or candidate box.
  Future<BoxCheckResult> checkBox(Specimen specimen, Rect rect);

  /// Runs the full order → family → genus analysis on one box. The last
  /// event has `stage == AnalysisStage.done` and carries the report.
  Stream<AnalysisProgress> analyze(Specimen specimen, Detection detection);

  Future<List<Report>> history();

  Future<Report?> report(String id);

  Future<void> save(Report report);

  Future<void> delete(String id);
}

/// Taxonomy and reference genera for the gallery and dichotomous key.
abstract interface class ReferenceRepository {
  List<TaxonOrder> get taxonomy;

  /// The 19 genera recorded in the Philippines that Kheryne identifies.
  List<GenusInfo> get targetGenera;

  GenusInfo genus(String name);

  TaxonFamily? familyOf(String genus);
}
