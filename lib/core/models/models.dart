import 'dart:ui';

import 'package:flutter/foundation.dart';

/// Taxonomic rank used by the classification ladder.
enum Rank { order, family, genus }

extension RankLabel on Rank {
  String get label => switch (this) {
        Rank.order => 'Order',
        Rank.family => 'Family',
        Rank.genus => 'Genus',
      };
}

@immutable
class TaxonFamily {
  const TaxonFamily(this.name, this.order, this.genera);
  final String name;
  final String order;
  final List<String> genera;
}

@immutable
class TaxonOrder {
  const TaxonOrder(this.name, this.families);
  final String name;
  final List<TaxonFamily> families;
}

/// Body regions Kheryne reads and overlays on the specimen image.
enum SpecimenRegion { head, stylet, esophagus, vulva, tail }

extension SpecimenRegionLabel on SpecimenRegion {
  String get label => switch (this) {
        SpecimenRegion.head => 'Head',
        SpecimenRegion.stylet => 'Stylet',
        SpecimenRegion.esophagus => 'Esophagus',
        SpecimenRegion.vulva => 'Vulva',
        SpecimenRegion.tail => 'Tail',
      };
}

/// Simple line drawings used in the key, trait sheets and gallery.
enum Illustration {
  styletKnobbed,
  styletSmall,
  styletMassive,
  styletNeedle,
  styletFlanged,
  bulbLarge,
  bulbOval,
  annulated,
  annulatedRetrorse,
  sheath,
  swollenPear,
  cystRound,
  kidney,
  swollenPosterior,
  spiral,
  straight,
  slender,
  tailConoid,
  tailRounded,
  tailMucro,
  tailPointed,
  glandsOverlap,
  glandsAbutting,
  lipFlat,
  lipOffset,
  vulvaPosterior,
  vulvaMid,
}

/// A morphological trait as found on a specimen, or as described in the
/// reference gallery.
@immutable
class Trait {
  const Trait({
    required this.name,
    required this.value,
    required this.why,
    required this.region,
    required this.illustration,
  });

  final String name;
  final String value;

  /// Plain-language "why this matters" explanation.
  final String why;
  final SpecimenRegion region;
  final Illustration illustration;
}

@immutable
class SimilarGenus {
  const SimilarGenus(this.name, this.howToTell);
  final String name;
  final String howToTell;
}

/// Reference details for one genus.
@immutable
class GenusInfo {
  const GenusInfo({
    required this.name,
    required this.family,
    required this.order,
    required this.commonName,
    required this.summary,
    required this.traits,
    required this.similar,
    required this.crops,
    required this.imageSeeds,
    this.referenceImageUrls = const [],
    this.recordedInPhilippines = false,
  });

  final String name;
  final String family;
  final String order;
  final String commonName;
  final String summary;
  final List<Trait> traits;
  final List<SimilarGenus> similar;
  final List<String> crops;
  final List<int> imageSeeds;
  final List<String> referenceImageUrls;
  final bool recordedInPhilippines;

  bool get hasDetails => traits.isNotEmpty;

  Uri get nemysUrl => Uri.https('nemys.ugent.be', '/aphia.php',
      {'p': 'taxlist', 'tName': name});
}

/// One nematode-like body in a mock micrograph, in normalised image
/// coordinates (0..1 on both axes).
@immutable
class WormShape {
  const WormShape({required this.spine, required this.width, this.isNematode = true});
  final List<Offset> spine;
  final double width;

  /// False for root fragments and fungal hyphae that look elongated.
  final bool isNematode;

  Rect get bounds {
    var l = 1.0, t = 1.0, r = 0.0, b = 0.0;
    for (final p in spine) {
      if (p.dx < l) l = p.dx;
      if (p.dy < t) t = p.dy;
      if (p.dx > r) r = p.dx;
      if (p.dy > b) b = p.dy;
    }
    final pad = width * 1.6;
    return Rect.fromLTRB(l - pad, t - pad, r + pad, b + pad);
  }
}

enum CaptureSource { camera, upload, phone, batch }

@immutable
class Specimen {
  const Specimen({
    required this.id,
    required this.seed,
    required this.fileName,
    required this.objective,
    required this.worms,
    required this.capturedAt,
    this.source = CaptureSource.upload,
    this.blurry = false,
    this.dark = false,
    this.localPath,
    this.imageUrl,
    this.storagePath,
  });

  final String id;
  final int seed;
  final String fileName;

  /// Microscope objective magnification: 10, 40 or 100.
  final int objective;
  final List<WormShape> worms;
  final DateTime capturedAt;
  final CaptureSource source;
  final bool blurry;
  final bool dark;

  /// Local file path on device when imported or captured from camera.
  final String? localPath;

  /// Signed or public remote URL when stored in Supabase Storage.
  final String? imageUrl;

  /// Object path inside the `specimens` Supabase Storage bucket.
  final String? storagePath;

  bool get hasRealImage => (localPath != null && localPath!.isNotEmpty) || (imageUrl != null && imageUrl!.isNotEmpty);

  Specimen copyWith({
    int? objective,
    List<WormShape>? worms,
    bool? blurry,
    bool? dark,
    String? localPath,
    String? imageUrl,
    String? storagePath,
  }) =>
      Specimen(
        id: id,
        seed: seed,
        fileName: fileName,
        objective: objective ?? this.objective,
        worms: worms ?? this.worms,
        capturedAt: capturedAt,
        source: source,
        blurry: blurry ?? this.blurry,
        dark: dark ?? this.dark,
        localPath: localPath ?? this.localPath,
        imageUrl: imageUrl ?? this.imageUrl,
        storagePath: storagePath ?? this.storagePath,
      );
}

/// Box states on the identification canvas.
enum BoxKind {
  /// Candidate plotted by Kheryne (pink).
  ai,

  /// Drawn by the user, not yet checked (purple).
  user,

  /// Checked and confirmed as a plant-parasitic nematode (green).
  confirmed,

  /// Checked and rejected (red with X).
  rejected,
}

@immutable
class Detection {
  const Detection({
    required this.id,
    required this.rect,
    required this.kind,
    this.confidence,
    this.rejectReason,
    this.checking = false,
  });

  final String id;

  /// Normalised rect in image space.
  final Rect rect;
  final BoxKind kind;
  final double? confidence;
  final String? rejectReason;

  /// True while "Check if nematode" is running.
  final bool checking;

  Detection copyWith({Rect? rect, BoxKind? kind, double? confidence, String? rejectReason, bool? checking}) =>
      Detection(
        id: id,
        rect: rect ?? this.rect,
        kind: kind ?? this.kind,
        confidence: confidence ?? this.confidence,
        rejectReason: rejectReason ?? this.rejectReason,
        checking: checking ?? this.checking,
      );
}

@immutable
class BoxCheckResult {
  const BoxCheckResult({required this.isNematode, required this.confidence, this.reason});
  final bool isNematode;
  final double confidence;

  /// When not a nematode: "Debris", "Root tissue", "Fungal hyphae" or
  /// "Free-living nematode (no stylet)".
  final String? reason;
}

@immutable
class RankResult {
  const RankResult(this.rank, this.name, this.confidence);
  final Rank rank;
  final String name;
  final double confidence;
}

@immutable
class Classification {
  const Classification({required this.order, required this.family, required this.genus, this.runnersUp = const []});
  final RankResult order;
  final RankResult family;
  final RankResult genus;

  /// Other genera worth considering, highest first.
  final List<RankResult> runnersUp;

  List<RankResult> get ladder => [order, family, genus];

  /// Genus confidence below 60% is shown as "Uncertain".
  bool get isUncertain => genus.confidence < 0.6;
}

/// de Man indices computed from measurements in micrometres.
@immutable
class Morphometrics {
  const Morphometrics({
    required this.bodyLength,
    required this.maxWidth,
    required this.styletLength,
    required this.esophagusLength,
    required this.tailLength,
    required this.vulvaFromHead,
  });

  final double bodyLength;
  final double maxWidth;
  final double styletLength;
  final double esophagusLength;
  final double tailLength;
  final double vulvaFromHead;

  double get a => bodyLength / maxWidth;
  double get b => bodyLength / esophagusLength;
  double get c => bodyLength / tailLength;
  double get vPercent => vulvaFromHead / bodyLength * 100;
}

@immutable
class Report {
  const Report({
    required this.id,
    required this.specimen,
    required this.detection,
    required this.classification,
    required this.traits,
    required this.regions,
    required this.createdAt,
    this.morphometrics,
    this.crop,
    this.notes = '',
    this.sampleCode,
    this.inferenceSource = 'on_device',
    this.synced = true,
  });

  final String id;
  final Specimen specimen;
  final Detection detection;
  final Classification classification;
  final List<Trait> traits;

  /// Normalised rects inside the detection crop.
  final Map<SpecimenRegion, Rect> regions;
  final DateTime createdAt;
  final Morphometrics? morphometrics;
  final String? crop;
  final String notes;
  final String? sampleCode;
  final String inferenceSource;
  final bool synced;

  String get genus => classification.genus.name;

  Report copyWith({
    Specimen? specimen,
    String? notes,
    Morphometrics? morphometrics,
    String? crop,
    String? sampleCode,
    String? inferenceSource,
    bool? synced,
  }) =>
      Report(
        id: id,
        specimen: specimen ?? this.specimen,
        detection: detection,
        classification: classification,
        traits: traits,
        regions: regions,
        createdAt: createdAt,
        morphometrics: morphometrics ?? this.morphometrics,
        crop: crop ?? this.crop,
        notes: notes ?? this.notes,
        sampleCode: sampleCode ?? this.sampleCode,
        inferenceSource: inferenceSource ?? this.inferenceSource,
        synced: synced ?? this.synced,
      );
}

enum AnalysisStage { regions, head, tail, order, family, genus, done }

extension AnalysisStageLabel on AnalysisStage {
  String get label => switch (this) {
        AnalysisStage.regions => 'Detecting body regions',
        AnalysisStage.head => 'Reading head and stylet',
        AnalysisStage.tail => 'Reading tail',
        AnalysisStage.order => 'Classifying order',
        AnalysisStage.family => 'Classifying family',
        AnalysisStage.genus => 'Classifying genus',
        AnalysisStage.done => 'Done',
      };
}

@immutable
class AnalysisProgress {
  const AnalysisProgress(this.stage, this.stageProgress, {this.report});
  final AnalysisStage stage;

  /// 0..1 within the current stage.
  final double stageProgress;
  final Report? report;
}

@immutable
class CalibrationProfile {
  const CalibrationProfile({required this.objective, required this.micrometresPerPixel, required this.savedAt, required this.referenceMicrometres});
  final int objective;
  final double micrometresPerPixel;
  final DateTime savedAt;
  final double referenceMicrometres;
}
