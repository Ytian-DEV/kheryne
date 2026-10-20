import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import '../core/data/repositories.dart';
import '../core/models/models.dart';
import 'genera.dart';
import 'specimens.dart';
import 'taxonomy.dart';

/// Typical adult measurements per genus (µm), used to make mock
/// morphometrics believable: body length, a, b, c, V%, stylet.
const _morpho = <String, (double, double, double, double, double, double)>{
  'Meloidogyne': (430, 28, 6.5, 8.5, 85, 13),
  'Globodera': (470, 24, 5.0, 10, 88, 22),
  'Pratylenchus': (560, 27, 6.4, 19, 80, 16),
  'Radopholus': (640, 30, 6.8, 9.5, 56, 18),
  'Hirschmanniella': (1450, 55, 9.5, 15, 52, 18),
  'Helicotylenchus': (720, 30, 6.8, 40, 62, 27),
  'Hoplolaimus': (1350, 34, 9.0, 52, 55, 45),
  'Rotylenchus': (1000, 33, 8.0, 50, 58, 32),
  'Rotylenchulus': (420, 24, 4.5, 15, 70, 18),
  'Tylenchorhynchus': (690, 30, 5.6, 15, 56, 19),
  'Criconemoides': (480, 10, 4.2, 22, 90, 60),
  'Mesocriconema': (520, 11, 4.4, 21, 92, 65),
  'Hemicriconemoides': (560, 13, 4.6, 24, 92, 70),
  'Hemicycliophora': (900, 22, 6.2, 9, 85, 85),
  'Tylenchulus': (380, 26, 4.2, 12, 80, 13),
  'Ditylenchus': (1050, 40, 7.5, 16, 80, 10),
  'Aphelenchoides': (640, 40, 9.0, 16, 68, 11),
  'Xiphinema': (2300, 55, 6.8, 70, 45, 110),
  'Longidorus': (4200, 90, 11, 110, 50, 95),
};

/// Confidence levels for the 20 history entries: mostly confident, with
/// four uncertain ones (< 60%).
const _historyConfidence = <double>[
  0.91, 0.82, 0.54, 0.88, 0.76, 0.93, 0.67, 0.48, 0.85, 0.79,
  0.95, 0.71, 0.57, 0.89, 0.83, 0.64, 0.90, 0.58, 0.86, 0.74,
];

const _crops = ['Banana', 'Rice', 'Tomato', 'Corn', 'Eggplant', 'Sweet potato', 'Pineapple', 'Citrus', 'Potato', 'Coconut'];
const _sites = ['Baybay', 'Abuyog', 'Ormoc', 'Inopacan', 'Hilongos', 'Albuera'];

class MockReferenceRepository implements ReferenceRepository {
  const MockReferenceRepository();

  @override
  List<TaxonOrder> get taxonomy => nemysTaxonomy;

  @override
  List<GenusInfo> get targetGenera => philippineGenera;

  @override
  GenusInfo genus(String name) {
    for (final g in philippineGenera) {
      if (g.name == name) return g;
    }
    final fam = familyOf(name);
    final idx = name.codeUnits.fold<int>(0, (a, b) => a + b);
    return GenusInfo(
      name: name,
      family: fam?.name ?? 'Unknown',
      order: fam?.order ?? 'Unknown',
      commonName: 'Not recorded in the Philippines',
      summary: 'Kheryne does not identify this genus yet. It is listed so the reference taxonomy is complete.',
      traits: const [],
      similar: const [],
      crops: const [],
      imageSeeds: [900 + idx % 50, 950 + idx % 40],
    );
  }

  @override
  TaxonFamily? familyOf(String genus) {
    for (final o in nemysTaxonomy) {
      for (final f in o.families) {
        if (f.genera.contains(genus)) return f;
      }
    }
    return null;
  }
}

/// In-memory implementation of [IdentificationRepository] with believable
/// latency. Replace with the real detector/classifier and SQLite store.
class MockIdentificationRepository implements IdentificationRepository {
  MockIdentificationRepository({required this.now, this.latency = const Duration(milliseconds: 450)})
      : _reference = const MockReferenceRepository() {
    _seed();
  }

  final DateTime Function() now;

  /// Simulated latency. Zero in tests.
  final Duration latency;
  final MockReferenceRepository _reference;

  final List<Specimen> _specimens = [];
  final List<Report> _history = [];

  void _seed() {
    final today = now();
    for (var i = 0; i < 12; i++) {
      _specimens.add(makeSpecimen(
        11 + i * 7,
        capturedAt: today.subtract(Duration(hours: i * 5 + 1)),
        fileName: 'slide_${(i + 1).toString().padLeft(2, '0')}_40x.jpg',
        objective: i % 4 == 3 ? 10 : 40,
        nematodes: 1 + i % 3,
      ));
    }
    for (var i = 0; i < 20; i++) {
      final genus = philippineGenera[(i * 7) % philippineGenera.length];
      final spec = makeSpecimen(500 + i * 13,
          capturedAt: today.subtract(Duration(days: (i * 3 + i ~/ 4) % 30, hours: 2 + i % 9, minutes: i * 7 % 60)),
          fileName: 'IMG_${4120 + i * 3}.jpg',
          source: i.isEven ? CaptureSource.camera : CaptureSource.upload,
          nematodes: 1);
      _history.add(buildReport(
        id: 'r-${100 + i}',
        specimen: spec,
        detection: Detection(id: 'd0', rect: spec.worms.first.bounds, kind: BoxKind.confirmed, confidence: 0.9),
        genus: genus.name,
        genusConfidence: _historyConfidence[i],
        createdAt: spec.capturedAt,
        crop: _crops[i % _crops.length],
        sampleCode: '${_sites[i % _sites.length].substring(0, 3).toUpperCase()}-${(i * 17 % 90 + 10)}',
        notes: i % 5 == 0 ? 'Soil sample from the ${_crops[i % _crops.length].toLowerCase()} plot near the access road. Two more slides to check.' : '',
        withMorphometrics: i % 3 == 0,
      ));
    }
    _history.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> _wait([double factor = 1]) =>
      latency == Duration.zero ? Future.value() : Future.delayed(latency * factor);

  @override
  Future<List<Specimen>> specimens() async {
    await _wait(0.5);
    return List.unmodifiable(_specimens);
  }

  @override
  Future<Specimen?> specimen(String id) async {
    for (final s in _specimens) {
      if (s.id == id) return s;
    }
    for (final r in _history) {
      if (r.specimen.id == id) return r.specimen;
    }
    final seed = int.tryParse(id.replaceFirst('sp-', ''));
    if (seed == null) return null;
    final s = makeSpecimen(seed, capturedAt: now());
    _specimens.add(s);
    return s;
  }

  @override
  Future<List<Detection>> detect(Specimen specimen) async {
    await _wait();
    final r = math.Random(specimen.seed);
    return [
      for (var i = 0; i < specimen.worms.length; i++)
        Detection(
          id: 'ai-$i',
          rect: specimen.worms[i].bounds,
          kind: BoxKind.ai,
          confidence: specimen.worms[i].isNematode ? 0.72 + r.nextDouble() * 0.24 : 0.52 + r.nextDouble() * 0.1,
        ),
    ];
  }

  @override
  Future<BoxCheckResult> checkBox(Specimen specimen, Rect rect) async {
    await _wait(1.6);
    WormShape? best;
    var bestCover = 0.0;
    for (final w in specimen.worms) {
      final inter = w.bounds.intersect(rect);
      if (inter.width <= 0 || inter.height <= 0) continue;
      final cover = (inter.width * inter.height) / (w.bounds.width * w.bounds.height);
      if (cover > bestCover) {
        bestCover = cover;
        best = w;
      }
    }
    if (best != null && best.isNematode && bestCover > 0.35) {
      return BoxCheckResult(isNematode: true, confidence: 0.8 + bestCover * 0.15);
    }
    const reasons = ['Debris', 'Root tissue', 'Fungal hyphae', 'Free-living nematode (no stylet)'];
    final reason = best != null && !best.isNematode
        ? reasons[1 + specimen.seed % 2]
        : reasons[(rect.left * 100).round() % 2 == 0 ? 0 : 3];
    return BoxCheckResult(isNematode: false, confidence: 0.78, reason: reason);
  }

  @override
  Stream<AnalysisProgress> analyze(Specimen specimen, Detection detection) async* {
    const stages = [
      AnalysisStage.regions,
      AnalysisStage.head,
      AnalysisStage.tail,
      AnalysisStage.order,
      AnalysisStage.family,
      AnalysisStage.genus,
    ];
    for (final s in stages) {
      for (var p = 0; p <= 4; p++) {
        if (latency != Duration.zero) await Future<void>.delayed(latency * 0.22);
        yield AnalysisProgress(s, p / 4);
      }
    }
    final idx = int.tryParse(detection.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final pick = philippineGenera[(specimen.seed + idx * 5) % philippineGenera.length];
    final conf = 0.55 + ((specimen.seed * 31 + idx * 17) % 40) / 100;
    final report = buildReport(
      id: 'r-${specimen.seed}-${detection.id}',
      specimen: specimen,
      detection: detection,
      genus: pick.name,
      genusConfidence: conf,
      createdAt: now(),
    );
    yield AnalysisProgress(AnalysisStage.done, 1, report: report);
  }

  @override
  Future<List<Report>> history() async {
    await _wait();
    return List.unmodifiable(_history);
  }

  @override
  Future<Report?> report(String id) async {
    await _wait(0.4);
    for (final r in _history) {
      if (r.id == id) return r;
    }
    return _scratch[id];
  }

  final Map<String, Report> _scratch = {};

  /// Keeps an unsaved report reachable by id (after analysis, before save).
  void remember(Report r) => _scratch[r.id] = r;

  @override
  Future<void> save(Report report) async {
    await _wait(0.4);
    _history.removeWhere((r) => r.id == report.id);
    _history.insert(0, report);
  }

  @override
  Future<void> delete(String id) async {
    await _wait(0.2);
    _history.removeWhere((r) => r.id == id);
  }

  Report buildReport({
    required String id,
    required Specimen specimen,
    required Detection detection,
    required String genus,
    required double genusConfidence,
    required DateTime createdAt,
    String? crop,
    String? sampleCode,
    String notes = '',
    bool withMorphometrics = true,
  }) {
    final info = _reference.genus(genus);
    final familyConf = math.min(0.97, math.max(genusConfidence + 0.12, 0.7) + (specimen.seed % 5) / 100);
    final orderConf = math.min(0.99, math.max(familyConf + 0.05, 0.9));
    final runners = <RankResult>[
      for (final s in info.similar.take(2))
        RankResult(Rank.genus, s.name, math.max(0.03, (1 - genusConfidence) * (s == info.similar.first ? 0.6 : 0.3))),
    ];
    final m = _morpho[genus];
    Morphometrics? morpho;
    if (withMorphometrics && m != null) {
      final jitter = 1 + ((specimen.seed % 11) - 5) / 100;
      final l = m.$1 * jitter;
      morpho = Morphometrics(
        bodyLength: l,
        maxWidth: l / m.$2,
        esophagusLength: l / m.$3,
        tailLength: l / m.$4,
        vulvaFromHead: l * m.$5 / 100,
        styletLength: m.$6 * jitter,
      );
    }
    return Report(
      id: id,
      specimen: specimen,
      detection: detection,
      classification: Classification(
        order: RankResult(Rank.order, info.order, orderConf),
        family: RankResult(Rank.family, info.family, familyConf),
        genus: RankResult(Rank.genus, genus, genusConfidence),
        runnersUp: runners,
      ),
      traits: info.traits,
      regions: regionsFor(genus),
      createdAt: createdAt,
      morphometrics: morpho,
      crop: crop,
      sampleCode: sampleCode,
      notes: notes,
    );
  }

  /// Region rects inside the straightened specimen portrait (0..1).
  static Map<SpecimenRegion, Rect> regionsFor(String genus) {
    final v = (_morpho[genus]?.$5 ?? 75) / 100;
    return {
      SpecimenRegion.head: const Rect.fromLTRB(0.02, 0.30, 0.10, 0.70),
      SpecimenRegion.stylet: const Rect.fromLTRB(0.05, 0.38, 0.16, 0.62),
      SpecimenRegion.esophagus: const Rect.fromLTRB(0.15, 0.30, 0.33, 0.70),
      SpecimenRegion.vulva: Rect.fromLTRB(v * 0.92 - 0.04, 0.34, v * 0.92 + 0.04, 0.72),
      SpecimenRegion.tail: const Rect.fromLTRB(0.86, 0.32, 0.99, 0.68),
    };
  }
}
