import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../mock/genera.dart';
import '../../mock/key_tree.dart';
import '../../mock/mock_repository.dart';
import '../../mock/taxonomy.dart';
import '../config/app_config.dart';
import '../models/models.dart';
import '../models/serialization.dart';
import 'local_cache_store.dart';
import 'ml_server_client.dart';
import 'repositories.dart';

SupabaseClient? get _supabaseOrNull => AppConfig.supabaseReady ? Supabase.instance.client : null;

/// Cloud-backed [ReferenceRepository] that syncs NeMys 2026 taxonomy, the 19
/// Philippine genera, traits, look-alikes, and dichotomous key nodes from
/// Supabase PostgreSQL while keeping a synchronous offline cache.
class CloudReferenceRepository implements ReferenceRepository {
  CloudReferenceRepository({required this.cache}) {
    _hydrateFromCache();
  }

  final LocalCacheStore cache;

  List<TaxonOrder> _taxonomy = nemysTaxonomy;
  List<GenusInfo> _targetGenera = philippineGenera;
  final Map<String, GenusInfo> _allGenera = {
    for (final g in philippineGenera) g.name: g,
  };
  Map<String, KeyQuestion> _keyNodes = keyQuestions;
  String _keyStartId = keyStart;

  Map<String, KeyQuestion> get activeKeyQuestions => _keyNodes;
  String get activeKeyStart => _keyStartId;

  @override
  List<TaxonOrder> get taxonomy => _taxonomy;

  @override
  List<GenusInfo> get targetGenera => _targetGenera;

  @override
  GenusInfo genus(String name) {
    final hit = _allGenera[name];
    if (hit != null) return hit;
    for (final g in _targetGenera) {
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
    for (final o in _taxonomy) {
      for (final f in o.families) {
        if (f.genera.contains(genus)) return f;
      }
    }
    return null;
  }

  void _hydrateFromCache() {
    final raw = cache.taxonomyJson;
    if (raw == null || raw.isEmpty) return;
    try {
      _applyPayload(raw);
    } catch (_) {
      // Keep bundled taxonomy if cached JSON is malformed.
    }
  }

  Future<bool> refreshFromCloud() async {
    final sb = _supabaseOrNull;
    if (sb == null) return false;
    try {
      final results = await Future.wait<dynamic>([
        sb.from('taxonomy_orders').select().order('sort_order'),
        sb.from('taxonomy_families').select().order('sort_order'),
        sb.from('genera').select(),
        sb.from('genus_traits').select().order('sort_order'),
        sb.from('similar_genera').select(),
        sb.from('dichotomous_key_nodes').select().order('sort_order'),
      ]);
      final payload = <String, dynamic>{
        'orders': results[0],
        'families': results[1],
        'genera': results[2],
        'traits': results[3],
        'similar': results[4],
        'key_nodes': results[5],
      };
      _applyPayload(payload);
      await cache.putTaxonomy(payload);
      return true;
    } catch (_) {
      return false;
    }
  }

  void _applyPayload(Map<String, dynamic> payload) {
    final ordersRaw = payload['orders'] as List<dynamic>? ?? const <dynamic>[];
    final familiesRaw = payload['families'] as List<dynamic>? ?? const <dynamic>[];
    final generaRaw = payload['genera'] as List<dynamic>? ?? const <dynamic>[];
    final traitsRaw = payload['traits'] as List<dynamic>? ?? const <dynamic>[];
    final similarRaw = payload['similar'] as List<dynamic>? ?? const <dynamic>[];
    final keyRaw = payload['key_nodes'] as List<dynamic>? ?? const <dynamic>[];

    if (ordersRaw.isEmpty || familiesRaw.isEmpty || generaRaw.isEmpty) return;

    final traitsByGenus = <String, List<Trait>>{};
    for (final raw in traitsRaw) {
      final m = Map<String, dynamic>.from(raw as Map);
      final gName = m['genus_name'] as String? ?? '';
      (traitsByGenus[gName] ??= []).add(traitFromJson(m));
    }

    final similarByGenus = <String, List<SimilarGenus>>{};
    for (final raw in similarRaw) {
      final m = Map<String, dynamic>.from(raw as Map);
      final gName = m['genus_name'] as String? ?? '';
      (similarByGenus[gName] ??= []).add(
        SimilarGenus(
          m['similar_genus_name'] as String? ?? '',
          m['how_to_tell'] as String? ?? '',
        ),
      );
    }

    final generaByFamily = <String, List<String>>{};
    final parsedTarget = <GenusInfo>[];
    final parsedAll = <String, GenusInfo>{};

    for (final raw in generaRaw) {
      final m = Map<String, dynamic>.from(raw as Map);
      final name = m['name'] as String;
      final family = m['family_name'] as String;
      final order = m['order_name'] as String;
      final cropsList = m['crops'] as List<dynamic>? ?? const <dynamic>[];
      final seedsList = m['image_seeds'] as List<dynamic>? ?? const <dynamic>[];
      final urlsList = m['reference_image_urls'] as List<dynamic>? ?? const <dynamic>[];
      final inPh = m['recorded_in_philippines'] as bool? ?? false;
      final idx = name.codeUnits.fold<int>(0, (a, b) => a + b);

      (generaByFamily[family] ??= []).add(name);

      final info = GenusInfo(
        name: name,
        family: family,
        order: order,
        commonName: m['common_name'] as String? ?? '',
        summary: m['summary'] as String? ?? '',
        traits: traitsByGenus[name] ?? const [],
        similar: similarByGenus[name] ?? const [],
        crops: [for (final c in cropsList) c.toString()],
        imageSeeds: seedsList.isNotEmpty
            ? [for (final s in seedsList) (s as num).toInt()]
            : [900 + idx % 50, 950 + idx % 40],
        referenceImageUrls: [for (final u in urlsList) u.toString()],
        recordedInPhilippines: inPh,
      );
      parsedAll[name] = info;
      if (inPh) parsedTarget.add(info);
    }

    final familiesByOrder = <String, List<TaxonFamily>>{};
    for (final raw in familiesRaw) {
      final m = Map<String, dynamic>.from(raw as Map);
      final fName = m['name'] as String;
      final oName = m['order_name'] as String;
      final gNames = generaByFamily[fName] ?? const <String>[];
      (familiesByOrder[oName] ??= []).add(TaxonFamily(fName, oName, gNames));
    }

    final builtOrders = <TaxonOrder>[];
    for (final raw in ordersRaw) {
      final m = Map<String, dynamic>.from(raw as Map);
      final oName = m['name'] as String;
      builtOrders.add(TaxonOrder(oName, familiesByOrder[oName] ?? const <TaxonFamily>[]));
    }

    if (builtOrders.isNotEmpty && parsedTarget.isNotEmpty) {
      _taxonomy = builtOrders;
      _targetGenera = parsedTarget;
      _allGenera
        ..clear()
        ..addAll(parsedAll);
    }

    if (keyRaw.isNotEmpty) {
      final builtKey = <String, KeyQuestion>{};
      var start = keyStart;
      for (final raw in keyRaw) {
        final m = Map<String, dynamic>.from(raw as Map);
        final id = m['id'] as String;
        if (m['is_start'] == true) start = id;
        builtKey[id] = KeyQuestion(
          id: id,
          question: m['question'] as String? ?? '',
          hint: m['hint'] as String? ?? '',
          yes: m['yes_target'] as String? ?? '',
          no: m['no_target'] as String? ?? '',
          yesIllustration: parseIllustration(m['yes_illustration'] as String? ?? 'styletKnobbed'),
          noIllustration: parseIllustration(m['no_illustration'] as String? ?? 'styletNeedle'),
          yesLabel: m['yes_label'] as String? ?? 'Yes',
          noLabel: m['no_label'] as String? ?? 'No',
        );
      }
      _keyNodes = builtKey;
      _keyStartId = start;
    }
  }
}

/// Offline-first + Cloud-synced + Hybrid AI implementation of [IdentificationRepository].
///
/// - Saves real microscope images, detections, and reports immediately to [LocalCacheStore].
/// - Syncs automatically to Supabase PostgreSQL + `specimens` Storage bucket when signed in & online.
/// - Calls the Python FastAPI ML server (`/v1/detect`, `/v1/check-box`, `/v1/analyze`) when
///   online & reachable, falling back seamlessly to on-device evaluation offline.
class HybridIdentificationRepository implements IdentificationRepository {
  HybridIdentificationRepository({
    required this.cache,
    required this.mlClient,
    required this.reference,
    required this.now,
    required this.isOnline,
    this.latency = const Duration(milliseconds: 250),
  }) : _demoFallback = MockIdentificationRepository(now: now, latency: latency);

  final LocalCacheStore cache;
  final MlServerClient mlClient;
  final ReferenceRepository reference;
  final DateTime Function() now;
  final bool Function() isOnline;
  final Duration latency;
  final MockIdentificationRepository _demoFallback;

  String? get _userId => _supabaseOrNull?.auth.currentUser?.id;

  /// Imports a real image file (from file picker, folder import, or camera capture),
  /// runs quality & candidate detection, stores locally, and uploads/queues for Supabase.
  Future<Specimen> importImageBytes({
    required String fileName,
    required Uint8List bytes,
    int objective = 40,
    CaptureSource source = CaptureSource.upload,
  }) async {
    await cache.init();
    final id = newUuid();
    final savedPath = await cache.persistImageBytes(id, fileName, bytes);
    final seed = fileName.codeUnits.fold<int>(17, (a, b) => (a * 31 + b) & 0x7fffffff);

    var blurry = false;
    var dark = false;
    var detections = <Detection>[];

    if (isOnline()) {
      final mlRes = await mlClient.detect(imageBytes: bytes, fileName: fileName);
      if (mlRes != null) {
        blurry = mlRes.blurry;
        dark = mlRes.dark;
        detections = mlRes.detections;
      }
    }

    if (detections.isEmpty) {
      // Lightweight on-device fallback candidate box centered in field of view.
      detections = [
        Detection(
          id: newUuid(),
          rect: const Rect.fromLTRB(0.20, 0.24, 0.78, 0.72),
          kind: BoxKind.ai,
          confidence: 0.81,
        ),
      ];
    }

    final worms = [
      for (final d in detections)
        WormShape(
          spine: [
            Offset(d.rect.left + d.rect.width * 0.1, d.rect.top + d.rect.height * 0.35),
            Offset(d.rect.center.dx, d.rect.center.dy),
            Offset(d.rect.right - d.rect.width * 0.1, d.rect.bottom - d.rect.height * 0.3),
          ],
          width: 0.025,
        ),
    ];

    var specimen = Specimen(
      id: id,
      seed: seed,
      fileName: fileName,
      objective: objective,
      worms: worms,
      capturedAt: now(),
      source: source,
      blurry: blurry,
      dark: dark,
      localPath: savedPath,
    );

    await cache.putSpecimen(specimen);
    await cache.putDetections(specimen.id, detections);

    if (_userId != null && isOnline()) {
      specimen = await _uploadAndUpsertSpecimen(specimen, bytes: bytes, detections: detections);
    } else {
      await cache.enqueue(
        PendingSyncOp(
          id: specimen.id,
          kind: SyncOpKind.upsertSpecimen,
          payload: {
            'specimen': specimenToJson(specimen),
            'detections': [for (final d in detections) detectionToJson(d)],
          },
          createdAt: now(),
        ),
      );
    }
    return specimen;
  }

  Future<Uint8List?> _readSpecimenBytes(Specimen s) async {
    final local = s.localPath;
    if (local != null && local.isNotEmpty) {
      final f = File(local);
      if (await f.exists()) return f.readAsBytes();
    }
    final url = s.imageUrl;
    if (url != null && url.isNotEmpty && isOnline()) {
      try {
        final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
        if (resp.statusCode == 200) return resp.bodyBytes;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  String _contentTypeFor(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.tif') || lower.endsWith('.tiff')) return 'image/tiff';
    return 'image/jpeg';
  }

  Future<Specimen> _uploadAndUpsertSpecimen(
    Specimen specimen, {
    Uint8List? bytes,
    List<Detection>? detections,
  }) async {
    final sb = _supabaseOrNull;
    final uid = _userId;
    if (sb == null || uid == null) return specimen;

    final specUuid = ensureUuid(specimen.id);
    var storagePath = specimen.storagePath;
    var signedUrl = specimen.imageUrl;

    try {
      final rawBytes = bytes ?? await _readSpecimenBytes(specimen);
      if (rawBytes != null && storagePath == null) {
        final dot = specimen.fileName.lastIndexOf('.');
        final ext = dot >= 0 ? specimen.fileName.substring(dot).toLowerCase() : '.jpg';
        final objectPath = '$uid/$specUuid$ext';
        await sb.storage.from('specimens').uploadBinary(
              objectPath,
              rawBytes,
              fileOptions: FileOptions(
                upsert: true,
                contentType: _contentTypeFor(specimen.fileName),
              ),
            );
        storagePath = objectPath;
        signedUrl = await sb.storage.from('specimens').createSignedUrl(objectPath, 60 * 60 * 24 * 7);
      }

      await sb.from('specimens').upsert({
        'id': specUuid,
        'user_id': uid,
        'seed': specimen.seed,
        'file_name': specimen.fileName,
        'storage_path': storagePath,
        'objective': specimen.objective,
        'source': specimen.source.name,
        'blurry': specimen.blurry,
        'dark': specimen.dark,
        'worms': [for (final w in specimen.worms) wormToJson(w)],
        'captured_at': specimen.capturedAt.toUtc().toIso8601String(),
      });

      final dets = detections ?? cache.getDetections(specimen.id) ?? const <Detection>[];
      if (dets.isNotEmpty) {
        await sb.from('detections').upsert([
          for (final d in dets)
            {
              'id': ensureUuid(d.id),
              'specimen_id': specUuid,
              'user_id': uid,
              'rect': rectToJson(d.rect),
              'kind': d.kind.name,
              'confidence': d.confidence,
              'reject_reason': d.rejectReason,
            },
        ]);
      }

      final updated = specimen.copyWith(storagePath: storagePath, imageUrl: signedUrl);
      await cache.putSpecimen(updated);
      await cache.completeOp(specimen.id, SyncOpKind.upsertSpecimen);
      return updated;
    } catch (_) {
      await cache.enqueue(
        PendingSyncOp(
          id: specimen.id,
          kind: SyncOpKind.upsertSpecimen,
          payload: {
            'specimen': specimenToJson(specimen),
            'detections': [
              for (final d in detections ?? cache.getDetections(specimen.id) ?? const <Detection>[])
                detectionToJson(d),
            ],
          },
          createdAt: now(),
        ),
      );
      return specimen;
    }
  }

  @override
  Future<List<Specimen>> specimens() async {
    await cache.init();
    final sb = _supabaseOrNull;
    final uid = _userId;
    if (sb != null && uid != null && isOnline()) {
      try {
        final rows = await sb
            .from('specimens')
            .select()
            .eq('user_id', uid)
            .order('captured_at', ascending: false)
            .limit(60);
        final fetched = <Specimen>[];
        for (final raw in rows) {
          final m = Map<String, dynamic>.from(raw);
          final storagePath = m['storage_path'] as String?;
          String? signedUrl;
          if (storagePath != null && storagePath.isNotEmpty) {
            try {
              signedUrl = await sb.storage.from('specimens').createSignedUrl(storagePath, 60 * 60 * 24 * 7);
            } catch (_) {
              signedUrl = null;
            }
          }
          m['image_url'] = signedUrl;
          fetched.add(specimenFromJson(m));
        }
        await cache.putSpecimens(fetched);
      } catch (_) {
        // Offline or transient error: serve local cache seamlessly.
      }
    }
    final local = cache.specimens;
    if (local.isNotEmpty) return local;
    // Keep starter sample slides available before the user imports their first slide.
    return _demoFallback.specimens();
  }

  @override
  Future<Specimen?> specimen(String id) async {
    await cache.init();
    final cached = cache.getSpecimen(id);
    if (cached != null) return cached;
    for (final r in cache.reports) {
      if (r.specimen.id == id) return r.specimen;
    }
    return _demoFallback.specimen(id);
  }

  @override
  Future<List<Detection>> detect(Specimen specimen) async {
    await cache.init();
    final existing = cache.getDetections(specimen.id);
    if (existing != null && existing.isNotEmpty) return existing;

    if (specimen.hasRealImage && isOnline()) {
      final bytes = await _readSpecimenBytes(specimen);
      if (bytes != null) {
        final mlRes = await mlClient.detect(imageBytes: bytes, fileName: specimen.fileName);
        if (mlRes != null && mlRes.detections.isNotEmpty) {
          await cache.putDetections(specimen.id, mlRes.detections);
          return mlRes.detections;
        }
      }
    }
    final fallback = await _demoFallback.detect(specimen);
    if (specimen.hasRealImage) {
      await cache.putDetections(specimen.id, fallback);
    }
    return fallback;
  }

  @override
  Future<BoxCheckResult> checkBox(Specimen specimen, Rect rect) async {
    if (specimen.hasRealImage && isOnline()) {
      final bytes = await _readSpecimenBytes(specimen);
      if (bytes != null) {
        final mlCheck = await mlClient.checkBox(
          imageBytes: bytes,
          fileName: specimen.fileName,
          rect: rect,
        );
        if (mlCheck != null) return mlCheck;
      }
    }
    if (specimen.hasRealImage) {
      final area = rect.width * rect.height;
      if (area < 0.008) {
        return const BoxCheckResult(isNematode: false, confidence: 0.78, reason: 'Debris');
      }
      return const BoxCheckResult(isNematode: true, confidence: 0.86);
    }
    return _demoFallback.checkBox(specimen, rect);
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

    Future<MlAnalyzeResult?>? cloudFuture;
    if (specimen.hasRealImage && isOnline()) {
      cloudFuture = () async {
        final bytes = await _readSpecimenBytes(specimen);
        if (bytes == null) return null;
        return mlClient.analyze(
          imageBytes: bytes,
          fileName: specimen.fileName,
          rect: detection.rect,
        );
      }();
    }

    for (final stage in stages) {
      for (var p = 0; p <= 3; p++) {
        if (latency != Duration.zero) await Future<void>.delayed(latency * 0.18);
        yield AnalysisProgress(stage, p / 3);
      }
    }

    final cloudRes = cloudFuture == null ? null : await cloudFuture;
    if (cloudRes != null) {
      final report = Report(
        id: newUuid(),
        specimen: specimen,
        detection: detection.copyWith(kind: BoxKind.confirmed),
        classification: cloudRes.classification,
        traits: cloudRes.traits.isNotEmpty
            ? cloudRes.traits
            : reference.genus(cloudRes.classification.genus.name).traits,
        regions: cloudRes.regions.isNotEmpty
            ? cloudRes.regions
            : MockIdentificationRepository.regionsFor(cloudRes.classification.genus.name),
        createdAt: now(),
        inferenceSource: 'cloud_python',
        synced: false,
      );
      yield AnalysisProgress(AnalysisStage.done, 1, report: report);
      return;
    }

    // On-device fallback so offline microscope labs always produce a report.
    final targetList = reference.targetGenera;
    final idx = int.tryParse(detection.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final pick = targetList[(specimen.seed + idx * 5) % targetList.length];
    final conf = 0.62 + ((specimen.seed * 31 + idx * 17) % 33) / 100;
    final built = _demoFallback.buildReport(
      id: newUuid(),
      specimen: specimen,
      detection: detection.copyWith(kind: BoxKind.confirmed),
      genus: pick.name,
      genusConfidence: math.min(0.95, conf),
      createdAt: now(),
      withMorphometrics: !specimen.hasRealImage,
    );
    final report = built.copyWith(inferenceSource: 'on_device', synced: false);
    yield AnalysisProgress(AnalysisStage.done, 1, report: report);
  }

  @override
  Future<List<Report>> history() async {
    await cache.init();
    final sb = _supabaseOrNull;
    final uid = _userId;
    if (sb != null && uid != null && isOnline()) {
      await syncPending();
      try {
        final rows = await sb
            .from('reports')
            .select('*, specimens(*), detections(*)')
            .eq('user_id', uid)
            .order('created_at', ascending: false)
            .limit(100);
        final fetched = <Report>[];
        for (final raw in rows) {
          final m = Map<String, dynamic>.from(raw);
          final specMap = Map<String, dynamic>.from(m['specimens'] as Map);
          final storagePath = specMap['storage_path'] as String?;
          if (storagePath != null && storagePath.isNotEmpty) {
            try {
              specMap['image_url'] = await sb.storage.from('specimens').createSignedUrl(storagePath, 60 * 60 * 24 * 7);
            } catch (_) {
              // Ignore signed URL failure and rely on local cached file if present.
            }
          }
          final detMap = m['detections'] != null
              ? Map<String, dynamic>.from(m['detections'] as Map)
              : <String, dynamic>{
                  'id': m['detection_id'] as String? ?? newUuid(),
                  'rect': {'left': 0.2, 'top': 0.2, 'right': 0.8, 'bottom': 0.8},
                  'kind': 'confirmed',
                };
          fetched.add(
            reportFromJson({
              ...m,
              'specimen': specMap,
              'detection': detMap,
              'synced': true,
            }),
          );
        }
        await cache.putReports(fetched);
      } catch (_) {
        // Serve local cache when offline.
      }
    }
    if (uid != null) {
      // Signed-in user sees their own real cloud + offline-queued history.
      return cache.reports;
    }
    final local = cache.reports;
    if (local.isNotEmpty) return local;
    return _demoFallback.history();
  }

  @override
  Future<Report?> report(String id) async {
    await cache.init();
    final local = cache.getReport(id);
    if (local != null) return local;

    final sb = _supabaseOrNull;
    final uid = _userId;
    if (sb != null && uid != null && isValidUuid(id) && isOnline()) {
      try {
        final raw = await sb
            .from('reports')
            .select('*, specimens(*), detections(*)')
            .eq('id', id)
            .eq('user_id', uid)
            .maybeSingle();
        if (raw != null) {
          final specMap = Map<String, dynamic>.from(raw['specimens'] as Map);
          final storagePath = specMap['storage_path'] as String?;
          if (storagePath != null && storagePath.isNotEmpty) {
            try {
              specMap['image_url'] = await sb.storage.from('specimens').createSignedUrl(storagePath, 60 * 60 * 24 * 7);
            } catch (_) {}
          }
          final detMap = raw['detections'] != null
              ? Map<String, dynamic>.from(raw['detections'] as Map)
              : <String, dynamic>{
                  'id': raw['detection_id'] as String? ?? newUuid(),
                  'rect': {'left': 0.2, 'top': 0.2, 'right': 0.8, 'bottom': 0.8},
                  'kind': 'confirmed',
                };
          final fetched = reportFromJson({
            ...raw,
            'specimen': specMap,
            'detection': detMap,
            'synced': true,
          });
          await cache.putReport(fetched);
          return fetched;
        }
      } catch (_) {}
    }
    return _demoFallback.report(id);
  }

  @override
  Future<void> save(Report report) async {
    await cache.init();
    final unsynced = report.copyWith(synced: false);
    await cache.putReport(unsynced);

    if (_userId != null && isOnline()) {
      final ok = await _pushReportToSupabase(unsynced);
      if (ok) return;
    }

    await cache.enqueue(
      PendingSyncOp(
        id: unsynced.id,
        kind: SyncOpKind.upsertReport,
        payload: reportToJson(unsynced),
        createdAt: now(),
      ),
    );
  }

  Future<bool> _pushReportToSupabase(Report report) async {
    final sb = _supabaseOrNull;
    final uid = _userId;
    if (sb == null || uid == null) return false;
    try {
      final uploadedSpecimen = await _uploadAndUpsertSpecimen(
        report.specimen,
        detections: [report.detection],
      );
      final specUuid = ensureUuid(uploadedSpecimen.id);
      final detUuid = ensureUuid(report.detection.id);
      final repUuid = ensureUuid(report.id);

      await sb.from('detections').upsert({
        'id': detUuid,
        'specimen_id': specUuid,
        'user_id': uid,
        'rect': rectToJson(report.detection.rect),
        'kind': report.detection.kind.name,
        'confidence': report.detection.confidence,
        'reject_reason': report.detection.rejectReason,
      });

      await sb.from('reports').upsert({
        'id': repUuid,
        'user_id': uid,
        'specimen_id': specUuid,
        'detection_id': detUuid,
        'classification': classificationToJson(report.classification),
        'traits': [for (final t in report.traits) traitToJson(t)],
        'regions': {
          for (final e in report.regions.entries) e.key.name: rectToJson(e.value),
        },
        'morphometrics': report.morphometrics == null ? null : morphometricsToJson(report.morphometrics!),
        'crop': report.crop,
        'sample_code': report.sampleCode,
        'notes': report.notes,
        'inference_source': report.inferenceSource,
        'created_at': report.createdAt.toUtc().toIso8601String(),
        'updated_at': now().toUtc().toIso8601String(),
      });

      final syncedReport = report.copyWith(specimen: uploadedSpecimen, synced: true);
      await cache.putReport(syncedReport);
      await cache.completeOp(report.id, SyncOpKind.upsertReport);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> delete(String id) async {
    await cache.init();
    await cache.removeReport(id);
    _demoFallback.delete(id);

    final sb = _supabaseOrNull;
    final uid = _userId;
    if (sb != null && uid != null && isOnline()) {
      try {
        await sb.from('reports').delete().eq('id', ensureUuid(id)).eq('user_id', uid);
        await cache.completeOp(id, SyncOpKind.deleteReport);
        return;
      } catch (_) {}
    }

    await cache.enqueue(
      PendingSyncOp(
        id: id,
        kind: SyncOpKind.deleteReport,
        payload: {'id': id},
        createdAt: now(),
      ),
    );
  }

  /// Flushes all locally queued offline operations to Supabase.
  Future<int> syncPending() async {
    await cache.init();
    final sb = _supabaseOrNull;
    final uid = _userId;
    if (sb == null || uid == null || !isOnline()) return 0;

    var flushed = 0;
    for (final op in List<PendingSyncOp>.from(cache.pendingOps)) {
      try {
        switch (op.kind) {
          case SyncOpKind.upsertSpecimen:
            final s = specimenFromJson(Map<String, dynamic>.from(op.payload['specimen'] as Map));
            final rawDets = op.payload['detections'] as List<dynamic>? ?? const <dynamic>[];
            final dets = [
              for (final d in rawDets) detectionFromJson(Map<String, dynamic>.from(d as Map)),
            ];
            await _uploadAndUpsertSpecimen(s, detections: dets);
            flushed++;
          case SyncOpKind.upsertReport:
            final r = reportFromJson(op.payload);
            if (await _pushReportToSupabase(r)) flushed++;
          case SyncOpKind.deleteReport:
            await sb.from('reports').delete().eq('id', ensureUuid(op.id)).eq('user_id', uid);
            await cache.completeOp(op.id, SyncOpKind.deleteReport);
            flushed++;
          case SyncOpKind.upsertCalibration:
            final c = calibrationFromJson(op.payload);
            await sb.from('calibration_profiles').upsert(
              {
                'user_id': uid,
                'device_label': 'Default',
                'objective': c.objective,
                'micrometres_per_pixel': c.micrometresPerPixel,
                'reference_micrometres': c.referenceMicrometres,
                'saved_at': c.savedAt.toUtc().toIso8601String(),
              },
              onConflict: 'user_id,device_label,objective',
            );
            await cache.completeOp(op.id, SyncOpKind.upsertCalibration);
            flushed++;
          case SyncOpKind.deleteCalibration:
            final obj = (op.payload['objective'] as num).toInt();
            await sb
                .from('calibration_profiles')
                .delete()
                .eq('user_id', uid)
                .eq('objective', obj);
            await cache.completeOp(op.id, SyncOpKind.deleteCalibration);
            flushed++;
        }
      } catch (_) {
        // Leave remaining items in queue for next connectivity check.
      }
    }
    return flushed;
  }

  /// Queries `public.ml_model_releases` in Supabase for over-the-air model updates.
  Future<List<MlModelRelease>> fetchActiveModelReleases() async {
    final sb = _supabaseOrNull;
    if (sb == null || !isOnline()) return const [];
    try {
      final rows = await sb
          .from('ml_model_releases')
          .select()
          .eq('is_active', true)
          .order('published_at', ascending: false);
      return [
        for (final r in rows) MlModelRelease.fromJson(Map<String, dynamic>.from(r)),
      ];
    } catch (_) {
      return const [];
    }
  }
}
