import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/models.dart';
import '../models/serialization.dart';
import 'repositories.dart';

enum TrainingSource { scientistLab, userSubmission }

extension TrainingSourceSql on TrainingSource {
  String get sql => switch (this) {
        TrainingSource.scientistLab => 'scientist_lab',
        TrainingSource.userSubmission => 'user_submission',
      };

  static TrainingSource fromSql(String v) =>
      v == 'scientist_lab' ? TrainingSource.scientistLab : TrainingSource.userSubmission;
}

enum ReviewStatus {
  verifiedGold,
  verifiedSilver,
  pendingReview,
  priorityReview,
  quarantinedQuality,
  rejected,
}

extension ReviewStatusSql on ReviewStatus {
  String get sql => switch (this) {
        ReviewStatus.verifiedGold => 'verified_gold',
        ReviewStatus.verifiedSilver => 'verified_silver',
        ReviewStatus.pendingReview => 'pending_review',
        ReviewStatus.priorityReview => 'priority_review',
        ReviewStatus.quarantinedQuality => 'quarantined_quality',
        ReviewStatus.rejected => 'rejected',
      };

  String get label => switch (this) {
        ReviewStatus.verifiedGold => 'Gold · Lab ground truth',
        ReviewStatus.verifiedSilver => 'Silver · Scientist verified',
        ReviewStatus.pendingReview => 'Pending check',
        ReviewStatus.priorityReview => 'Priority review',
        ReviewStatus.quarantinedQuality => 'Quarantined (blur/dark)',
        ReviewStatus.rejected => 'Rejected',
      };

  static ReviewStatus fromSql(String v) => switch (v) {
        'verified_gold' => ReviewStatus.verifiedGold,
        'verified_silver' => ReviewStatus.verifiedSilver,
        'priority_review' => ReviewStatus.priorityReview,
        'quarantined_quality' => ReviewStatus.quarantinedQuality,
        'rejected' => ReviewStatus.rejected,
        _ => ReviewStatus.pendingReview,
      };
}

@immutable
class TrainingAnnotation {
  const TrainingAnnotation({
    required this.id,
    required this.rect,
    this.classLabel = 'nematode',
    this.genusLabel,
    this.confidence,
    this.isGroundTruth = false,
  });

  final String id;
  final Rect rect;
  final String classLabel;
  final String? genusLabel;
  final double? confidence;
  final bool isGroundTruth;

  factory TrainingAnnotation.fromJson(Map<String, dynamic> m) => TrainingAnnotation(
        id: m['id'] as String? ?? newUuid(),
        rect: rectFromJson(Map<String, dynamic>.from(m['rect'] as Map)),
        classLabel: m['class_label'] as String? ?? 'nematode',
        genusLabel: m['genus_label'] as String?,
        confidence: (m['confidence'] as num?)?.toDouble(),
        isGroundTruth: m['is_ground_truth'] as bool? ?? false,
      );
}

@immutable
class TrainingSample {
  const TrainingSample({
    required this.id,
    required this.submittedBy,
    required this.sourceType,
    required this.reviewStatus,
    required this.storagePath,
    required this.fileName,
    required this.objective,
    required this.lifeStage,
    required this.createdAt,
    this.imageUrl,
    this.crop,
    this.sampleCode,
    this.locality,
    this.aiPredictedGenus,
    this.aiConfidence,
    this.keyDisagreed = false,
    this.verifiedOrder,
    this.verifiedFamily,
    this.verifiedGenus,
    this.reviewNotes = '',
    this.annotations = const [],
  });

  final String id;
  final String submittedBy;
  final TrainingSource sourceType;
  final ReviewStatus reviewStatus;
  final String storagePath;
  final String fileName;
  final int objective;
  final String lifeStage;
  final DateTime createdAt;
  final String? imageUrl;
  final String? crop;
  final String? sampleCode;
  final String? locality;
  final String? aiPredictedGenus;
  final double? aiConfidence;
  final bool keyDisagreed;
  final String? verifiedOrder;
  final String? verifiedFamily;
  final String? verifiedGenus;
  final String reviewNotes;
  final List<TrainingAnnotation> annotations;
}

@immutable
class DatasetSummary {
  const DatasetSummary({
    this.goldCount = 0,
    this.silverCount = 0,
    this.pendingCount = 0,
    this.priorityCount = 0,
    this.quarantinedCount = 0,
    this.perGenusVerified = const {},
  });

  final int goldCount;
  final int silverCount;
  final int pendingCount;
  final int priorityCount;
  final int quarantinedCount;
  final Map<String, int> perGenusVerified;

  int get totalVerified => goldCount + silverCount;
  int get totalQueue => pendingCount + priorityCount;
}

/// Manages the 2-way nematode model training dataset in Supabase:
/// - Source 1 (`scientist_lab` -> `verified_gold` ground truth)
/// - Source 2 (`user_submission` -> confidence-routed review queue -> `verified_silver`)
class TrainingDatasetRepository {
  TrainingDatasetRepository({required this.reference});
  final ReferenceRepository reference;

  SupabaseClient? get _sb => AppConfig.supabaseReady ? Supabase.instance.client : null;

  String _contentType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.tif') || lower.endsWith('.tiff')) return 'image/tiff';
    return 'image/jpeg';
  }

  /// Source 1: Scientist / Owner uploads a ground-truth lab slide with verified
  /// bounding boxes and known genus directly into `verified_gold`.
  Future<TrainingSample> submitScientistLabSample({
    required Uint8List imageBytes,
    required String fileName,
    required String verifiedGenus,
    required List<TrainingAnnotation> annotations,
    int objective = 40,
    String lifeStage = 'adult_female',
    String? crop,
    String? sampleCode,
    String? locality,
    String notes = '',
  }) async {
    final sb = _sb;
    final uid = sb?.auth.currentUser?.id;
    if (sb == null || uid == null) {
      throw StateError('Sign in as a scientist or owner to submit ground-truth lab samples.');
    }

    final sampleId = newUuid();
    final dot = fileName.lastIndexOf('.');
    final ext = dot >= 0 ? fileName.substring(dot).toLowerCase() : '.jpg';
    final objectPath = '$uid/lab_$sampleId$ext';

    await sb.storage.from('training-dataset').uploadBinary(
          objectPath,
          imageBytes,
          fileOptions: FileOptions(upsert: true, contentType: _contentType(fileName)),
        );

    final genusInfo = reference.genus(verifiedGenus);
    final inserted = await sb
        .from('training_samples')
        .insert({
          'id': sampleId,
          'submitted_by': uid,
          'source_type': 'scientist_lab',
          'review_status': 'verified_gold',
          'storage_bucket': 'training-dataset',
          'storage_path': objectPath,
          'file_name': fileName,
          'objective': objective,
          'life_stage': lifeStage,
          'crop': (crop == null || crop.trim().isEmpty) ? null : crop.trim(),
          'sample_code': (sampleCode == null || sampleCode.trim().isEmpty) ? null : sampleCode.trim(),
          'locality': (locality == null || locality.trim().isEmpty) ? null : locality.trim(),
          'verified_order': genusInfo.order,
          'verified_family': genusInfo.family,
          'verified_genus': verifiedGenus,
          'reviewed_by': uid,
          'review_notes': notes.trim(),
          'reviewed_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select()
        .single();

    final effectiveBoxes = annotations.isNotEmpty
        ? annotations
        : [
            TrainingAnnotation(
              id: newUuid(),
              rect: const Rect.fromLTRB(0.15, 0.15, 0.85, 0.85),
              classLabel: 'nematode',
              genusLabel: verifiedGenus,
              isGroundTruth: true,
            ),
          ];

    await sb.from('training_annotations').insert([
      for (final b in effectiveBoxes)
        {
          'id': ensureUuid(b.id),
          'sample_id': sampleId,
          'rect': rectToJson(b.rect),
          'class_label': b.classLabel,
          'genus_label': b.classLabel == 'nematode' ? (b.genusLabel ?? verifiedGenus) : null,
          'confidence': b.confidence,
          'is_ground_truth': true,
        },
    ]);

    final signedUrl = await sb.storage.from('training-dataset').createSignedUrl(objectPath, 60 * 60 * 24);
    return _mapSample(inserted, effectiveBoxes, signedUrl: signedUrl);
  }

  /// Source 2: Submits a user-captured/imported detection scan into the
  /// confidence-triaged Scientist Verification Queue.
  Future<void> submitUserDetectionSample({
    required Specimen specimen,
    required List<Detection> detections,
    Report? report,
    Uint8List? imageBytes,
    bool keyDisagreed = false,
  }) async {
    final sb = _sb;
    final uid = sb?.auth.currentUser?.id;
    if (sb == null || uid == null) return;

    Uint8List? raw = imageBytes;
    if (raw == null && specimen.localPath != null && specimen.localPath!.isNotEmpty) {
      final f = File(specimen.localPath!);
      if (await f.exists()) raw = await f.readAsBytes();
    }
    if (raw == null) return;

    final sampleId = newUuid();
    final dot = specimen.fileName.lastIndexOf('.');
    final ext = dot >= 0 ? specimen.fileName.substring(dot).toLowerCase() : '.jpg';
    final objectPath = '$uid/user_$sampleId$ext';

    await sb.storage.from('training-dataset').uploadBinary(
          objectPath,
          raw,
          fileOptions: FileOptions(upsert: true, contentType: _contentType(specimen.fileName)),
        );

    final conf = report?.classification.genus.confidence;
    final String status;
    if (specimen.blurry || specimen.dark) {
      status = 'quarantined_quality';
    } else if (conf == null || conf < 0.80 || keyDisagreed) {
      status = 'priority_review';
    } else {
      status = 'pending_review';
    }

    await sb.from('training_samples').insert({
      'id': sampleId,
      'submitted_by': uid,
      'specimen_id': isValidUuid(specimen.id) ? specimen.id : null,
      'report_id': (report != null && isValidUuid(report.id)) ? report.id : null,
      'source_type': 'user_submission',
      'review_status': status,
      'storage_bucket': 'training-dataset',
      'storage_path': objectPath,
      'file_name': specimen.fileName,
      'objective': specimen.objective,
      'crop': report?.crop,
      'sample_code': report?.sampleCode,
      'ai_predicted_genus': report?.genus,
      'ai_confidence': conf,
      'key_disagreed': keyDisagreed,
    });

    if (detections.isNotEmpty) {
      await sb.from('training_annotations').insert([
        for (final d in detections)
          {
            'id': newUuid(),
            'sample_id': sampleId,
            'rect': rectToJson(d.rect),
            'class_label': d.kind == BoxKind.rejected ? 'debris' : 'nematode',
            'genus_label': d.kind == BoxKind.rejected ? null : report?.genus,
            'confidence': d.confidence,
            'is_ground_truth': false,
          },
      ]);
    }
  }

  /// Scientist / Owner reviews a queued user sample: approves/relabels -> `verified_silver`, or rejects -> `rejected`.
  Future<void> reviewSample({
    required String sampleId,
    required bool approve,
    String? verifiedGenus,
    String notes = '',
  }) async {
    final sb = _sb;
    final uid = sb?.auth.currentUser?.id;
    if (sb == null || uid == null) return;

    if (!approve) {
      await sb.from('training_samples').update({
        'review_status': 'rejected',
        'reviewed_by': uid,
        'review_notes': notes.trim(),
        'reviewed_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', sampleId);
      return;
    }

    if (verifiedGenus == null || verifiedGenus.isEmpty) {
      throw ArgumentError('Select a verified genus before approving a training sample.');
    }
    final info = reference.genus(verifiedGenus);
    await sb.from('training_samples').update({
      'review_status': 'verified_silver',
      'verified_order': info.order,
      'verified_family': info.family,
      'verified_genus': verifiedGenus,
      'reviewed_by': uid,
      'review_notes': notes.trim(),
      'reviewed_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', sampleId);

    await sb
        .from('training_annotations')
        .update({
          'genus_label': verifiedGenus,
          'is_ground_truth': true,
        })
        .eq('sample_id', sampleId)
        .eq('class_label', 'nematode');
  }

  Future<List<TrainingSample>> listSamples({List<ReviewStatus>? statuses, int limit = 60}) async {
    final sb = _sb;
    if (sb == null || sb.auth.currentUser == null) return const [];

    var query = sb.from('training_samples').select('*, training_annotations(*)');
    if (statuses != null && statuses.isNotEmpty) {
      query = query.inFilter('review_status', [for (final s in statuses) s.sql]);
    }
    final rows = await query.order('created_at', ascending: false).limit(limit);
    final result = <TrainingSample>[];
    for (final raw in rows) {
      final m = Map<String, dynamic>.from(raw);
      final rawBoxes = m['training_annotations'] as List<dynamic>? ?? const <dynamic>[];
      final boxes = [
        for (final b in rawBoxes) TrainingAnnotation.fromJson(Map<String, dynamic>.from(b as Map)),
      ];
      String? signedUrl;
      final path = m['storage_path'] as String?;
      final bucket = m['storage_bucket'] as String? ?? 'training-dataset';
      if (path != null && path.isNotEmpty) {
        try {
          signedUrl = await sb.storage.from(bucket).createSignedUrl(path, 60 * 60 * 12);
        } catch (_) {}
      }
      result.add(_mapSample(m, boxes, signedUrl: signedUrl));
    }
    return result;
  }

  Future<DatasetSummary> fetchSummary() async {
    final sb = _sb;
    if (sb == null || sb.auth.currentUser == null) return const DatasetSummary();
    try {
      final rows = await sb.from('training_samples').select('review_status, verified_genus');
      var gold = 0;
      var silver = 0;
      var pending = 0;
      var priority = 0;
      var quarantined = 0;
      final perGenus = <String, int>{};

      for (final raw in rows) {
        final status = raw['review_status'] as String? ?? '';
        final genus = raw['verified_genus'] as String?;
        switch (status) {
          case 'verified_gold':
            gold++;
            if (genus != null && genus.isNotEmpty) {
              perGenus[genus] = (perGenus[genus] ?? 0) + 1;
            }
          case 'verified_silver':
            silver++;
            if (genus != null && genus.isNotEmpty) {
              perGenus[genus] = (perGenus[genus] ?? 0) + 1;
            }
          case 'pending_review':
            pending++;
          case 'priority_review':
            priority++;
          case 'quarantined_quality':
            quarantined++;
        }
      }
      return DatasetSummary(
        goldCount: gold,
        silverCount: silver,
        pendingCount: pending,
        priorityCount: priority,
        quarantinedCount: quarantined,
        perGenusVerified: perGenus,
      );
    } catch (_) {
      return const DatasetSummary();
    }
  }

  TrainingSample _mapSample(
    Map<String, dynamic> m,
    List<TrainingAnnotation> boxes, {
    String? signedUrl,
  }) =>
      TrainingSample(
        id: m['id'] as String,
        submittedBy: m['submitted_by'] as String,
        sourceType: TrainingSourceSql.fromSql(m['source_type'] as String? ?? 'user_submission'),
        reviewStatus: ReviewStatusSql.fromSql(m['review_status'] as String? ?? 'pending_review'),
        storagePath: m['storage_path'] as String? ?? '',
        fileName: m['file_name'] as String? ?? 'slide.jpg',
        objective: (m['objective'] as num? ?? 40).toInt(),
        lifeStage: m['life_stage'] as String? ?? 'unknown',
        createdAt: DateTime.tryParse(m['created_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
        imageUrl: signedUrl,
        crop: m['crop'] as String?,
        sampleCode: m['sample_code'] as String?,
        locality: m['locality'] as String?,
        aiPredictedGenus: m['ai_predicted_genus'] as String?,
        aiConfidence: (m['ai_confidence'] as num?)?.toDouble(),
        keyDisagreed: m['key_disagreed'] as bool? ?? false,
        verifiedOrder: m['verified_order'] as String?,
        verifiedFamily: m['verified_family'] as String?,
        verifiedGenus: m['verified_genus'] as String?,
        reviewNotes: m['review_notes'] as String? ?? '',
        annotations: boxes,
      );
}
