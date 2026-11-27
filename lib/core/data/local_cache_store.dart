import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/models.dart';
import '../models/serialization.dart';

enum SyncOpKind { upsertSpecimen, upsertReport, deleteReport, upsertCalibration, deleteCalibration }

class PendingSyncOp {
  const PendingSyncOp({
    required this.id,
    required this.kind,
    required this.payload,
    required this.createdAt,
  });

  final String id;
  final SyncOpKind kind;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'payload': payload,
        'created_at': createdAt.toUtc().toIso8601String(),
      };

  factory PendingSyncOp.fromJson(Map<String, dynamic> m) {
    final kindName = m['kind'] as String? ?? 'upsertReport';
    final kind = SyncOpKind.values.firstWhere(
      (k) => k.name == kindName,
      orElse: () => SyncOpKind.upsertReport,
    );
    return PendingSyncOp(
      id: m['id'] as String? ?? newUuid(),
      kind: kind,
      payload: Map<String, dynamic>.from(m['payload'] as Map? ?? const <String, dynamic>{}),
      createdAt: DateTime.tryParse(m['created_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
    );
  }
}

/// Offline-first local store backed by atomic JSON files and a local
/// `specimens/` image directory under ApplicationSupportDirectory.
class LocalCacheStore {
  Directory? _rootDir;
  bool _initialized = false;

  final Map<String, Specimen> _specimens = {};
  final Map<String, List<Detection>> _detections = {};
  final Map<String, Report> _reports = {};
  final List<CalibrationProfile> _calibrations = [];
  final List<PendingSyncOp> _queue = [];
  Map<String, dynamic>? _settingsJson;
  Map<String, dynamic>? _taxonomyJson;

  List<Specimen> get specimens =>
      _specimens.values.toList()..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));

  List<Report> get reports =>
      _reports.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<CalibrationProfile> get calibrations => List.unmodifiable(_calibrations);

  List<PendingSyncOp> get pendingOps => List.unmodifiable(_queue);

  int get pendingCount => _queue.length;

  Map<String, dynamic>? get settingsJson => _settingsJson;
  Map<String, dynamic>? get taxonomyJson => _taxonomyJson;

  Future<void> init() async {
    if (_initialized) return;
    try {
      final support = await getApplicationSupportDirectory();
      final dir = Directory('${support.path}${Platform.pathSeparator}kheryne_store');
      await dir.create(recursive: true);
      await Directory('${dir.path}${Platform.pathSeparator}specimens').create(recursive: true);
      _rootDir = dir;
      await _loadAll();
    } catch (_) {
      // In headless widget tests where path_provider has no channel, stay in-memory.
      _rootDir = null;
    }
    _initialized = true;
  }

  File? _file(String name) {
    final root = _rootDir;
    if (root == null) return null;
    return File('${root.path}${Platform.pathSeparator}$name');
  }

  Future<void> _loadAll() async {
    final specRaw = await _readJsonList('specimens.json');
    for (final item in specRaw) {
      final s = specimenFromJson(item);
      _specimens[s.id] = s;
    }

    final detRaw = await _readJsonMap('detections.json');
    for (final entry in detRaw.entries) {
      final list = entry.value as List<dynamic>? ?? const <dynamic>[];
      _detections[entry.key] = [
        for (final d in list) detectionFromJson(Map<String, dynamic>.from(d as Map)),
      ];
    }

    final repRaw = await _readJsonList('reports.json');
    for (final item in repRaw) {
      final r = reportFromJson(item);
      _reports[r.id] = r;
    }

    final calRaw = await _readJsonList('calibrations.json');
    _calibrations
      ..clear()
      ..addAll(calRaw.map(calibrationFromJson));

    final qRaw = await _readJsonList('sync_queue.json');
    _queue
      ..clear()
      ..addAll(qRaw.map(PendingSyncOp.fromJson));

    final setMap = await _readJsonMap('settings.json');
    if (setMap.isNotEmpty) _settingsJson = setMap;

    final taxMap = await _readJsonMap('taxonomy.json');
    if (taxMap.isNotEmpty) _taxonomyJson = taxMap;
  }

  Future<List<Map<String, dynamic>>> _readJsonList(String name) async {
    final f = _file(name);
    if (f == null || !await f.exists()) return const [];
    try {
      final decoded = jsonDecode(await f.readAsString()) as List<dynamic>;
      return [for (final e in decoded) Map<String, dynamic>.from(e as Map)];
    } catch (_) {
      return const [];
    }
  }

  Future<Map<String, dynamic>> _readJsonMap(String name) async {
    final f = _file(name);
    if (f == null || !await f.exists()) return const {};
    try {
      final decoded = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      return decoded;
    } catch (_) {
      return const {};
    }
  }

  Future<void> _writeJson(String name, Object data) async {
    final f = _file(name);
    if (f == null) return;
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(data), flush: true);
    await tmp.rename(f.path);
  }

  /// Copies an imported/captured image into permanent app storage.
  Future<String?> persistImageBytes(String specimenId, String originalFileName, List<int> bytes) async {
    await init();
    final root = _rootDir;
    if (root == null) return null;
    final dot = originalFileName.lastIndexOf('.');
    final ext = dot >= 0 ? originalFileName.substring(dot).toLowerCase() : '.jpg';
    final dest = File('${root.path}${Platform.pathSeparator}specimens${Platform.pathSeparator}$specimenId$ext');
    await dest.writeAsBytes(bytes, flush: true);
    return dest.path;
  }

  Specimen? getSpecimen(String id) => _specimens[id];

  List<Detection>? getDetections(String specimenId) => _detections[specimenId];

  Report? getReport(String id) => _reports[id];

  Future<void> putSpecimen(Specimen s) async {
    await init();
    _specimens[s.id] = s;
    await _writeJson('specimens.json', [for (final v in _specimens.values) specimenToJson(v)]);
  }

  Future<void> putSpecimens(Iterable<Specimen> items) async {
    await init();
    for (final s in items) {
      final existing = _specimens[s.id];
      _specimens[s.id] = existing?.localPath != null && s.localPath == null
          ? s.copyWith(localPath: existing!.localPath)
          : s;
    }
    await _writeJson('specimens.json', [for (final v in _specimens.values) specimenToJson(v)]);
  }

  Future<void> putDetections(String specimenId, List<Detection> list) async {
    await init();
    _detections[specimenId] = list;
    await _writeJson('detections.json', {
      for (final e in _detections.entries)
        e.key: [for (final d in e.value) detectionToJson(d)],
    });
  }

  Future<void> putReport(Report r) async {
    await init();
    _reports[r.id] = r;
    _specimens[r.specimen.id] = r.specimen;
    await _writeJson('reports.json', [for (final v in _reports.values) reportToJson(v)]);
    await _writeJson('specimens.json', [for (final v in _specimens.values) specimenToJson(v)]);
  }

  Future<void> putReports(Iterable<Report> items) async {
    await init();
    for (final r in items) {
      final existingSpec = _specimens[r.specimen.id];
      final mergedSpec = existingSpec?.localPath != null && r.specimen.localPath == null
          ? r.specimen.copyWith(localPath: existingSpec!.localPath)
          : r.specimen;
      _specimens[mergedSpec.id] = mergedSpec;
      _reports[r.id] = r.copyWith(specimen: mergedSpec);
    }
    await _writeJson('reports.json', [for (final v in _reports.values) reportToJson(v)]);
    await _writeJson('specimens.json', [for (final v in _specimens.values) specimenToJson(v)]);
  }

  Future<void> removeReport(String id) async {
    await init();
    _reports.remove(id);
    await _writeJson('reports.json', [for (final v in _reports.values) reportToJson(v)]);
  }

  Future<void> putCalibrations(List<CalibrationProfile> items) async {
    await init();
    _calibrations
      ..clear()
      ..addAll(items);
    await _writeJson('calibrations.json', [for (final c in _calibrations) calibrationToJson(c)]);
  }

  Future<void> putSettings(Map<String, dynamic> json) async {
    await init();
    _settingsJson = json;
    await _writeJson('settings.json', json);
  }

  Future<void> putTaxonomy(Map<String, dynamic> json) async {
    await init();
    _taxonomyJson = json;
    await _writeJson('taxonomy.json', json);
  }

  Future<void> enqueue(PendingSyncOp op) async {
    await init();
    _queue.removeWhere((existing) => existing.kind == op.kind && existing.id == op.id);
    _queue.add(op);
    await _writeJson('sync_queue.json', [for (final q in _queue) q.toJson()]);
  }

  Future<void> completeOp(String id, SyncOpKind kind) async {
    await init();
    _queue.removeWhere((existing) => existing.id == id && existing.kind == kind);
    await _writeJson('sync_queue.json', [for (final q in _queue) q.toJson()]);
  }
}
