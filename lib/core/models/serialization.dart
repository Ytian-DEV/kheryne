import 'dart:math' as math;
import 'dart:ui';

import 'models.dart';

final _uuidRng = math.Random.secure();

/// Generates an RFC-4122 v4 UUID for offline-safe client primary keys.
String newUuid() {
  final bytes = List<int>.generate(16, (_) => _uuidRng.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  String hex(int b) => b.toRadixString(16).padLeft(2, '0');
  final h = bytes.map(hex).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

bool isValidUuid(String value) =>
    RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(value);

/// Deterministic UUID derived from a legacy string id when syncing older objects.
String ensureUuid(String id) {
  if (isValidUuid(id)) return id.toLowerCase();
  var h1 = 0x811c9dc5;
  var h2 = 0x01000193;
  for (final code in id.codeUnits) {
    h1 = ((h1 ^ code) * 0x01000193) & 0xffffffff;
    h2 = ((h2 ^ (code * 31)) * 0x85ebca6b) & 0xffffffff;
  }
  final hex = '${h1.toRadixString(16).padLeft(8, '0')}'
      '${h2.toRadixString(16).padLeft(8, '0')}'
      '${(h1 ^ h2).toRadixString(16).padLeft(8, '0')}'
      '${((h1 + h2) & 0xffffffff).toRadixString(16).padLeft(8, '0')}';
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-4${hex.substring(13, 16)}-a${hex.substring(17, 20)}-${hex.substring(20, 32)}';
}

Map<String, dynamic> rectToJson(Rect r) => {
      'left': r.left,
      'top': r.top,
      'right': r.right,
      'bottom': r.bottom,
    };

Rect rectFromJson(Map<String, dynamic> m) => Rect.fromLTRB(
      (m['left'] as num? ?? m['l'] as num? ?? 0).toDouble(),
      (m['top'] as num? ?? m['t'] as num? ?? 0).toDouble(),
      (m['right'] as num? ?? m['r'] as num? ?? 1).toDouble(),
      (m['bottom'] as num? ?? m['b'] as num? ?? 1).toDouble(),
    );

Illustration parseIllustration(String name) {
  for (final v in Illustration.values) {
    if (v.name == name) return v;
  }
  return Illustration.styletKnobbed;
}

SpecimenRegion parseRegion(String name) {
  for (final v in SpecimenRegion.values) {
    if (v.name == name) return v;
  }
  return SpecimenRegion.head;
}

CaptureSource parseCaptureSource(String name) {
  for (final v in CaptureSource.values) {
    if (v.name == name) return v;
  }
  return CaptureSource.upload;
}

BoxKind parseBoxKind(String name) {
  for (final v in BoxKind.values) {
    if (v.name == name) return v;
  }
  return BoxKind.ai;
}

Rank parseRank(String name) {
  for (final v in Rank.values) {
    if (v.name == name) return v;
  }
  return Rank.genus;
}

Map<String, dynamic> wormToJson(WormShape w) => {
      'spine': [
        for (final p in w.spine) {'dx': p.dx, 'dy': p.dy},
      ],
      'width': w.width,
      'isNematode': w.isNematode,
    };

WormShape wormFromJson(Map<String, dynamic> m) {
  final rawSpine = m['spine'] as List<dynamic>? ?? const <dynamic>[];
  return WormShape(
    spine: [
      for (final item in rawSpine)
        Offset(
          ((item as Map<String, dynamic>)['dx'] as num).toDouble(),
          (item['dy'] as num).toDouble(),
        ),
    ],
    width: (m['width'] as num? ?? 0.025).toDouble(),
    isNematode: m['isNematode'] as bool? ?? true,
  );
}

Map<String, dynamic> specimenToJson(Specimen s) => {
      'id': s.id,
      'seed': s.seed,
      'file_name': s.fileName,
      'objective': s.objective,
      'worms': [for (final w in s.worms) wormToJson(w)],
      'captured_at': s.capturedAt.toUtc().toIso8601String(),
      'source': s.source.name,
      'blurry': s.blurry,
      'dark': s.dark,
      'local_path': s.localPath,
      'image_url': s.imageUrl,
      'storage_path': s.storagePath,
    };

Specimen specimenFromJson(Map<String, dynamic> m) {
  final rawWorms = m['worms'] as List<dynamic>? ?? const <dynamic>[];
  return Specimen(
    id: m['id'] as String,
    seed: (m['seed'] as num? ?? 1).toInt(),
    fileName: m['file_name'] as String? ?? 'slide.jpg',
    objective: (m['objective'] as num? ?? 40).toInt(),
    worms: [
      for (final w in rawWorms) wormFromJson(Map<String, dynamic>.from(w as Map)),
    ],
    capturedAt: DateTime.tryParse(m['captured_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
    source: parseCaptureSource(m['source'] as String? ?? 'upload'),
    blurry: m['blurry'] as bool? ?? false,
    dark: m['dark'] as bool? ?? false,
    localPath: m['local_path'] as String?,
    imageUrl: m['image_url'] as String?,
    storagePath: m['storage_path'] as String?,
  );
}

Map<String, dynamic> detectionToJson(Detection d) => {
      'id': d.id,
      'rect': rectToJson(d.rect),
      'kind': d.kind.name,
      'confidence': d.confidence,
      'reject_reason': d.rejectReason,
    };

Detection detectionFromJson(Map<String, dynamic> m) => Detection(
      id: m['id'] as String,
      rect: rectFromJson(Map<String, dynamic>.from(m['rect'] as Map)),
      kind: parseBoxKind(m['kind'] as String? ?? 'ai'),
      confidence: (m['confidence'] as num?)?.toDouble(),
      rejectReason: m['reject_reason'] as String?,
    );

Map<String, dynamic> rankToJson(RankResult r) => {
      'rank': r.rank.name,
      'name': r.name,
      'confidence': r.confidence,
    };

RankResult rankFromJson(Map<String, dynamic> m) => RankResult(
      parseRank(m['rank'] as String? ?? 'genus'),
      m['name'] as String? ?? 'Unknown',
      (m['confidence'] as num? ?? 0).toDouble(),
    );

Map<String, dynamic> classificationToJson(Classification c) => {
      'order': rankToJson(c.order),
      'family': rankToJson(c.family),
      'genus': rankToJson(c.genus),
      'runners_up': [for (final r in c.runnersUp) rankToJson(r)],
    };

Classification classificationFromJson(Map<String, dynamic> m) {
  final runners = m['runners_up'] as List<dynamic>? ?? const <dynamic>[];
  return Classification(
    order: rankFromJson(Map<String, dynamic>.from(m['order'] as Map)),
    family: rankFromJson(Map<String, dynamic>.from(m['family'] as Map)),
    genus: rankFromJson(Map<String, dynamic>.from(m['genus'] as Map)),
    runnersUp: [
      for (final r in runners) rankFromJson(Map<String, dynamic>.from(r as Map)),
    ],
  );
}

Map<String, dynamic> traitToJson(Trait t) => {
      'name': t.name,
      'value': t.value,
      'why': t.why,
      'region': t.region.name,
      'illustration': t.illustration.name,
    };

Trait traitFromJson(Map<String, dynamic> m) => Trait(
      name: m['name'] as String? ?? '',
      value: m['value'] as String? ?? '',
      why: m['why'] as String? ?? '',
      region: parseRegion(m['region'] as String? ?? 'head'),
      illustration: parseIllustration(m['illustration'] as String? ?? 'styletKnobbed'),
    );

Map<String, dynamic> morphometricsToJson(Morphometrics m) => {
      'bodyLength': m.bodyLength,
      'maxWidth': m.maxWidth,
      'styletLength': m.styletLength,
      'esophagusLength': m.esophagusLength,
      'tailLength': m.tailLength,
      'vulvaFromHead': m.vulvaFromHead,
    };

Morphometrics morphometricsFromJson(Map<String, dynamic> m) => Morphometrics(
      bodyLength: (m['bodyLength'] as num).toDouble(),
      maxWidth: (m['maxWidth'] as num).toDouble(),
      styletLength: (m['styletLength'] as num).toDouble(),
      esophagusLength: (m['esophagusLength'] as num).toDouble(),
      tailLength: (m['tailLength'] as num).toDouble(),
      vulvaFromHead: (m['vulvaFromHead'] as num).toDouble(),
    );

Map<String, dynamic> reportToJson(Report r) => {
      'id': r.id,
      'specimen': specimenToJson(r.specimen),
      'detection': detectionToJson(r.detection),
      'classification': classificationToJson(r.classification),
      'traits': [for (final t in r.traits) traitToJson(t)],
      'regions': {
        for (final e in r.regions.entries) e.key.name: rectToJson(e.value),
      },
      'created_at': r.createdAt.toUtc().toIso8601String(),
      'morphometrics': r.morphometrics == null ? null : morphometricsToJson(r.morphometrics!),
      'crop': r.crop,
      'notes': r.notes,
      'sample_code': r.sampleCode,
      'inference_source': r.inferenceSource,
      'synced': r.synced,
    };

Report reportFromJson(Map<String, dynamic> m) {
  final rawTraits = m['traits'] as List<dynamic>? ?? const <dynamic>[];
  final rawRegions = m['regions'] as Map<String, dynamic>? ?? const <String, dynamic>{};
  final rawMorpho = m['morphometrics'] as Map<String, dynamic>?;
  return Report(
    id: m['id'] as String,
    specimen: specimenFromJson(Map<String, dynamic>.from(m['specimen'] as Map)),
    detection: detectionFromJson(Map<String, dynamic>.from(m['detection'] as Map)),
    classification: classificationFromJson(Map<String, dynamic>.from(m['classification'] as Map)),
    traits: [
      for (final t in rawTraits) traitFromJson(Map<String, dynamic>.from(t as Map)),
    ],
    regions: {
      for (final e in rawRegions.entries)
        parseRegion(e.key): rectFromJson(Map<String, dynamic>.from(e.value as Map)),
    },
    createdAt: DateTime.tryParse(m['created_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
    morphometrics: rawMorpho == null ? null : morphometricsFromJson(rawMorpho),
    crop: m['crop'] as String?,
    notes: m['notes'] as String? ?? '',
    sampleCode: m['sample_code'] as String?,
    inferenceSource: m['inference_source'] as String? ?? 'on_device',
    synced: m['synced'] as bool? ?? true,
  );
}

Map<String, dynamic> calibrationToJson(CalibrationProfile p) => {
      'objective': p.objective,
      'micrometres_per_pixel': p.micrometresPerPixel,
      'saved_at': p.savedAt.toUtc().toIso8601String(),
      'reference_micrometres': p.referenceMicrometres,
    };

CalibrationProfile calibrationFromJson(Map<String, dynamic> m) => CalibrationProfile(
      objective: (m['objective'] as num).toInt(),
      micrometresPerPixel: (m['micrometres_per_pixel'] as num).toDouble(),
      savedAt: DateTime.tryParse(m['saved_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      referenceMicrometres: (m['reference_micrometres'] as num).toDouble(),
    );

class MlModelRelease {
  const MlModelRelease({
    required this.modelType,
    required this.version,
    required this.storagePath,
    required this.sizeMb,
    required this.notes,
    required this.publishedAt,
  });

  final String modelType;
  final String version;
  final String storagePath;
  final double sizeMb;
  final String notes;
  final DateTime publishedAt;

  factory MlModelRelease.fromJson(Map<String, dynamic> m) => MlModelRelease(
        modelType: m['model_type'] as String? ?? 'detector',
        version: m['version'] as String? ?? '2.3.0',
        storagePath: m['storage_path'] as String? ?? '',
        sizeMb: (m['size_mb'] as num? ?? 0).toDouble(),
        notes: m['notes'] as String? ?? '',
        publishedAt: DateTime.tryParse(m['published_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      );
}
