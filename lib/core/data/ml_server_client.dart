import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:http/http.dart' as http;

import '../models/models.dart';
import '../models/serialization.dart';

class MlServerHealth {
  const MlServerHealth({
    required this.reachable,
    required this.detectorEngine,
    required this.classifierEngine,
    required this.modelVersion,
  });

  final bool reachable;
  final String detectorEngine;
  final String classifierEngine;
  final String modelVersion;
}

class MlDetectResult {
  const MlDetectResult({
    required this.blurry,
    required this.dark,
    required this.detections,
  });

  final bool blurry;
  final bool dark;
  final List<Detection> detections;
}

class MlAnalyzeResult {
  const MlAnalyzeResult({
    required this.classification,
    required this.traits,
    required this.regions,
    required this.modelVersion,
  });

  final Classification classification;
  final List<Trait> traits;
  final Map<SpecimenRegion, Rect> regions;
  final String modelVersion;
}

/// Client for the Python FastAPI ML Server (`server/app/main.py`).
class MlServerClient {
  MlServerClient({required this.baseUrlProvider, this.accessTokenProvider});

  final String Function() baseUrlProvider;
  final String? Function()? accessTokenProvider;

  Uri _uri(String path) {
    final base = baseUrlProvider().trim().replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$base$path');
  }

  Map<String, String> _headers() {
    final token = accessTokenProvider?.call();
    if (token == null || token.isEmpty) return const {};
    return {'Authorization': 'Bearer $token'};
  }

  Future<MlServerHealth> checkHealth() async {
    try {
      final resp = await http.get(_uri('/health'), headers: _headers()).timeout(const Duration(seconds: 5));
      if (resp.statusCode != 200) {
        return const MlServerHealth(
          reachable: false,
          detectorEngine: 'offline',
          classifierEngine: 'offline',
          modelVersion: '—',
        );
      }
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      return MlServerHealth(
        reachable: true,
        detectorEngine: body['detector_engine'] as String? ?? 'opencv',
        classifierEngine: body['classifier_engine'] as String? ?? 'opencv',
        modelVersion: body['model_version'] as String? ?? '2.3.0',
      );
    } catch (_) {
      return const MlServerHealth(
        reachable: false,
        detectorEngine: 'offline',
        classifierEngine: 'offline',
        modelVersion: '—',
      );
    }
  }

  Future<MlDetectResult?> detect({
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    try {
      final req = http.MultipartRequest('POST', _uri('/v1/detect'))
        ..headers.addAll(_headers())
        ..files.add(http.MultipartFile.fromBytes('image', imageBytes, filename: fileName));
      final streamed = await req.send().timeout(const Duration(seconds: 12));
      if (streamed.statusCode != 200) return null;
      final body = jsonDecode(await streamed.stream.bytesToString()) as Map<String, dynamic>;
      final quality = body['quality'] as Map<String, dynamic>? ?? const <String, dynamic>{};
      final rawDetections = body['detections'] as List<dynamic>? ?? const <dynamic>[];
      return MlDetectResult(
        blurry: quality['blurry'] as bool? ?? false,
        dark: quality['dark'] as bool? ?? false,
        detections: [
          for (final item in rawDetections)
            Detection(
              id: newUuid(),
              rect: rectFromJson(Map<String, dynamic>.from((item as Map<String, dynamic>)['rect'] as Map)),
              kind: parseBoxKind(item['kind'] as String? ?? 'ai'),
              confidence: (item['confidence'] as num?)?.toDouble(),
            ),
        ],
      );
    } catch (_) {
      return null;
    }
  }

  Future<BoxCheckResult?> checkBox({
    required Uint8List imageBytes,
    required String fileName,
    required Rect rect,
  }) async {
    try {
      final req = http.MultipartRequest('POST', _uri('/v1/check-box'))
        ..headers.addAll(_headers())
        ..fields['left'] = rect.left.clamp(0.0, 1.0).toString()
        ..fields['top'] = rect.top.clamp(0.0, 1.0).toString()
        ..fields['right'] = rect.right.clamp(0.0, 1.0).toString()
        ..fields['bottom'] = rect.bottom.clamp(0.0, 1.0).toString()
        ..files.add(http.MultipartFile.fromBytes('image', imageBytes, filename: fileName));
      final streamed = await req.send().timeout(const Duration(seconds: 10));
      if (streamed.statusCode != 200) return null;
      final body = jsonDecode(await streamed.stream.bytesToString()) as Map<String, dynamic>;
      return BoxCheckResult(
        isNematode: body['is_nematode'] as bool? ?? false,
        confidence: (body['confidence'] as num? ?? 0.78).toDouble(),
        reason: body['reason'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  Future<MlAnalyzeResult?> analyze({
    required Uint8List imageBytes,
    required String fileName,
    required Rect rect,
  }) async {
    try {
      final req = http.MultipartRequest('POST', _uri('/v1/analyze'))
        ..headers.addAll(_headers())
        ..fields['left'] = rect.left.clamp(0.0, 1.0).toString()
        ..fields['top'] = rect.top.clamp(0.0, 1.0).toString()
        ..fields['right'] = rect.right.clamp(0.0, 1.0).toString()
        ..fields['bottom'] = rect.bottom.clamp(0.0, 1.0).toString()
        ..files.add(http.MultipartFile.fromBytes('image', imageBytes, filename: fileName));
      final streamed = await req.send().timeout(const Duration(seconds: 20));
      if (streamed.statusCode != 200) return null;
      final body = jsonDecode(await streamed.stream.bytesToString()) as Map<String, dynamic>;
      final rawTraits = body['traits'] as List<dynamic>? ?? const <dynamic>[];
      final rawRegions = body['regions'] as Map<String, dynamic>? ?? const <String, dynamic>{};
      return MlAnalyzeResult(
        classification: classificationFromJson(Map<String, dynamic>.from(body['classification'] as Map)),
        traits: [
          for (final t in rawTraits) traitFromJson(Map<String, dynamic>.from(t as Map)),
        ],
        regions: {
          for (final e in rawRegions.entries)
            parseRegion(e.key): rectFromJson(Map<String, dynamic>.from(e.value as Map)),
        },
        modelVersion: body['model_version'] as String? ?? '2.3.0',
      );
    } catch (_) {
      return null;
    }
  }
}
