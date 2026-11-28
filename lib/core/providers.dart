import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../mock/mock_repository.dart';
import '../mock/taxonomy.dart';
import 'config/app_config.dart';
import 'data/cloud_repositories.dart';
import 'data/local_cache_store.dart';
import 'data/ml_server_client.dart';
import 'data/repositories.dart';
import 'data/training_repository.dart';
import 'layout/form_factor.dart';
import 'models/models.dart';
import 'models/serialization.dart';
import 'widgets/async_view.dart' show ViewState;

/// Current time. Overridden with a fixed date in tests and screenshots.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Simulated repository latency (used only by MockIdentificationRepository in widget tests).
final latencyProvider = Provider<Duration>((ref) => const Duration(milliseconds: 450));

/// Persistent offline-first store for specimens, detections, reports, and sync queue.
final localCacheProvider = Provider<LocalCacheStore>((ref) => LocalCacheStore());

class FormFactorController extends Notifier<FormFactor> {
  FormFactorController([this._initial]);
  final FormFactor? _initial;

  @override
  FormFactor build() => _initial ?? FormFactor.fromPlatform();

  void set(FormFactor f) => state = f;
}

final formFactorProvider = NotifierProvider<FormFactorController, FormFactor>(FormFactorController.new);

/// Forces every screen into one state (screen gallery, screenshots).
class ForcedViewState extends Notifier<ViewState?> {
  @override
  ViewState? build() => null;
  void set(ViewState? s) => state = s;
}

final forcedViewStateProvider = NotifierProvider<ForcedViewState, ViewState?>(ForcedViewState.new);

/// Bumped whenever cloud taxonomy is refreshed so Gallery and Key screens rebuild.
class TaxonomyRevision extends Notifier<int> {
  @override
  int build() => 0;
  void bump() => state++;
}

final taxonomyRevisionProvider = NotifierProvider<TaxonomyRevision, int>(TaxonomyRevision.new);

final cloudReferenceRepositoryProvider = Provider<CloudReferenceRepository?>((ref) {
  if (!AppConfig.supabaseReady) return null;
  final repo = CloudReferenceRepository(cache: ref.watch(localCacheProvider));
  unawaited(
    repo.refreshFromCloud().then((changed) {
      if (changed) ref.read(taxonomyRevisionProvider.notifier).bump();
    }),
  );
  return repo;
});

final referenceRepositoryProvider = Provider<ReferenceRepository>((ref) {
  ref.watch(taxonomyRevisionProvider);
  final cloud = ref.watch(cloudReferenceRepositoryProvider);
  return cloud ?? const MockReferenceRepository();
});

final trainingRepositoryProvider = Provider<TrainingDatasetRepository>((ref) {
  return TrainingDatasetRepository(reference: ref.watch(referenceRepositoryProvider));
});

final mlServerClientProvider = Provider<MlServerClient>((ref) {
  return MlServerClient(
    baseUrlProvider: () => ref.read(settingsProvider).mlServerUrl,
    accessTokenProvider: () =>
        AppConfig.supabaseReady ? Supabase.instance.client.auth.currentSession?.accessToken : null,
  );
});

final hybridRepositoryProvider = Provider<HybridIdentificationRepository?>((ref) {
  if (!AppConfig.supabaseReady) return null;
  return HybridIdentificationRepository(
    cache: ref.watch(localCacheProvider),
    mlClient: ref.watch(mlServerClientProvider),
    reference: ref.watch(referenceRepositoryProvider),
    training: ref.watch(trainingRepositoryProvider),
    now: ref.watch(clockProvider),
    isOnline: () => ref.read(onlineProvider),
    trainingOptIn: () => ref.read(settingsProvider).trainingOptIn,
  );
});

final identificationRepositoryProvider = Provider<IdentificationRepository>((ref) {
  final hybrid = ref.watch(hybridRepositoryProvider);
  if (hybrid != null) return hybrid;
  return MockIdentificationRepository(now: ref.watch(clockProvider), latency: ref.watch(latencyProvider));
});

final historyProvider = FutureProvider<List<Report>>((ref) => ref.watch(identificationRepositoryProvider).history());

final specimensProvider = FutureProvider<List<Specimen>>((ref) => ref.watch(identificationRepositoryProvider).specimens());

final specimenProvider = FutureProvider.family<Specimen?, String>(
    (ref, id) => ref.watch(identificationRepositoryProvider).specimen(id));

/// Reports produced in this session before or during save.
class PendingReports extends Notifier<Map<String, Report>> {
  @override
  Map<String, Report> build() => const {};

  void put(Report r) => state = {...state, r.id: r};
}

final pendingReportsProvider = NotifierProvider<PendingReports, Map<String, Report>>(PendingReports.new);

final reportProvider = FutureProvider.family<Report?, String>((ref, id) async {
  final pending = ref.watch(pendingReportsProvider)[id];
  if (pending != null) return pending;
  return ref.watch(identificationRepositoryProvider).report(id);
});

/// Connectivity state (also toggled from Developer settings and the screen gallery).
class Connectivity extends Notifier<bool> {
  @override
  bool build() => true;
  void set(bool online) {
    state = online;
    if (online) {
      final hybrid = ref.read(hybridRepositoryProvider);
      if (hybrid != null) {
        unawaited(
          hybrid.syncPending().then((count) {
            if (count > 0) {
              ref.invalidate(historyProvider);
              ref.invalidate(specimensProvider);
            }
          }),
        );
      }
    }
  }
}

final onlineProvider = NotifierProvider<Connectivity, bool>(Connectivity.new);

@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.scanAlwaysDark = true,
    this.system = ClassificationSystem.nemys2026,
    this.language = 'English',
    this.demoFeed = false,
    this.onboarded = false,
    this.userName = '',
    this.calibrations = const [],
    this.modelVersion = 'None',
    this.modelSizeMb = 0,
    this.lastModelCheckAt,
    this.mlServerUrl = AppConfig.defaultMlServerUrl,
    this.trainingOptIn = true,
  });

  final ThemeMode themeMode;
  final bool scanAlwaysDark;
  final ClassificationSystem system;
  final String language;

  /// Developer-only demo feed toggle (OFF by default in production).
  final bool demoFeed;
  final bool onboarded;
  final String userName;
  final List<CalibrationProfile> calibrations;
  final String modelVersion;
  final double modelSizeMb;
  final DateTime? lastModelCheckAt;
  final String mlServerUrl;
  final bool trainingOptIn;

  String? get firstNameOrNull {
    final trimmed = userName.trim();
    if (trimmed.isEmpty) return null;
    return trimmed.split(RegExp(r'\s+')).first;
  }

  String get firstName => firstNameOrNull ?? 'Researcher';

  CalibrationProfile? calibrationFor(int objective) {
    for (final c in calibrations) {
      if (c.objective == objective) return c;
    }
    return null;
  }

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? scanAlwaysDark,
    ClassificationSystem? system,
    String? language,
    bool? demoFeed,
    bool? onboarded,
    String? userName,
    List<CalibrationProfile>? calibrations,
    String? modelVersion,
    double? modelSizeMb,
    DateTime? lastModelCheckAt,
    String? mlServerUrl,
    bool? trainingOptIn,
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        scanAlwaysDark: scanAlwaysDark ?? this.scanAlwaysDark,
        system: system ?? this.system,
        language: language ?? this.language,
        demoFeed: demoFeed ?? this.demoFeed,
        onboarded: onboarded ?? this.onboarded,
        userName: userName ?? this.userName,
        calibrations: calibrations ?? this.calibrations,
        modelVersion: modelVersion ?? this.modelVersion,
        modelSizeMb: modelSizeMb ?? this.modelSizeMb,
        lastModelCheckAt: lastModelCheckAt ?? this.lastModelCheckAt,
        mlServerUrl: mlServerUrl ?? this.mlServerUrl,
        trainingOptIn: trainingOptIn ?? this.trainingOptIn,
      );

  Map<String, dynamic> toJson() => {
        'theme_mode': themeMode.name,
        'scan_always_dark': scanAlwaysDark,
        'system': system.name,
        'language': language,
        'demo_feed': demoFeed,
        'onboarded': onboarded,
        'user_name': userName,
        'model_version': modelVersion,
        'model_size_mb': modelSizeMb,
        'last_model_check_at': lastModelCheckAt?.toUtc().toIso8601String(),
        'ml_server_url': mlServerUrl,
        'training_opt_in': trainingOptIn,
      };
}

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final now = ref.watch(clockProvider)();
    final cache = ref.watch(localCacheProvider);
    final saved = cache.settingsJson;
    final savedCals = cache.calibrations;

    // In headless widget tests (!AppConfig.supabaseReady), keep test fixtures deterministic.
    if (!AppConfig.supabaseReady && saved == null) {
      return AppSettings(
        demoFeed: true,
        userName: 'Ana Dela Cruz',
        modelVersion: '2.3.0',
        modelSizeMb: 48.6,
        calibrations: [
          CalibrationProfile(
            objective: 10,
            micrometresPerPixel: 1.62,
            savedAt: now.subtract(const Duration(days: 12)),
            referenceMicrometres: 1000,
          ),
          CalibrationProfile(
            objective: 40,
            micrometresPerPixel: 0.405,
            savedAt: now.subtract(const Duration(days: 12)),
            referenceMicrometres: 200,
          ),
        ],
      );
    }

    if (saved == null) {
      _syncServerHealthSoon();
      return AppSettings(calibrations: savedCals);
    }

    final modeName = saved['theme_mode'] as String? ?? 'system';
    final themeMode = ThemeMode.values.firstWhere(
      (m) => m.name == modeName,
      orElse: () => ThemeMode.system,
    );
    final sysName = saved['system'] as String? ?? 'nemys2026';
    final system = sysName == 'classic' ? ClassificationSystem.classic : ClassificationSystem.nemys2026;
    final rawCheck = saved['last_model_check_at'] as String?;

    _syncServerHealthSoon();
    return AppSettings(
      themeMode: themeMode,
      scanAlwaysDark: saved['scan_always_dark'] as bool? ?? true,
      system: system,
      language: saved['language'] as String? ?? 'English',
      demoFeed: saved['demo_feed'] as bool? ?? false,
      onboarded: saved['onboarded'] as bool? ?? false,
      userName: saved['user_name'] as String? ?? '',
      calibrations: savedCals,
      modelVersion: saved['model_version'] as String? ?? 'None',
      modelSizeMb: (saved['model_size_mb'] as num? ?? 0).toDouble(),
      lastModelCheckAt: rawCheck == null ? null : DateTime.tryParse(rawCheck)?.toLocal(),
      mlServerUrl: saved['ml_server_url'] as String? ?? AppConfig.defaultMlServerUrl,
      trainingOptIn: saved['training_opt_in'] as bool? ?? true,
    );
  }

  void _syncServerHealthSoon() {
    if (!AppConfig.supabaseReady) return;
    Future<void>.microtask(() async {
      final health = await ref.read(mlServerClientProvider).checkHealth();
      if (!ref.mounted || !health.reachable) return;
      if (health.classifierReady && health.modelVersion != 'None' && health.modelVersion != '—') {
        update((s) => s.copyWith(modelVersion: health.modelVersion));
      }
    });
  }

  void _persist() {
    if (!AppConfig.supabaseReady) return;
    final cache = ref.read(localCacheProvider);
    unawaited(cache.putSettings(state.toJson()));
  }

  void update(AppSettings Function(AppSettings s) f) {
    state = f(state);
    _persist();
  }

  void saveCalibration(CalibrationProfile p) {
    final updated = [...state.calibrations.where((c) => c.objective != p.objective), p]
      ..sort((a, b) => a.objective.compareTo(b.objective));
    state = state.copyWith(calibrations: updated);
    if (!AppConfig.supabaseReady) return;
    final cache = ref.read(localCacheProvider);
    unawaited(cache.putCalibrations(updated));
    final sb = Supabase.instance.client;
    final uid = sb.auth.currentUser?.id;
    if (uid != null && ref.read(onlineProvider)) {
      unawaited(
        sb
            .from('calibration_profiles')
            .upsert(
              {
                'user_id': uid,
                'device_label': 'Default',
                'objective': p.objective,
                'micrometres_per_pixel': p.micrometresPerPixel,
                'reference_micrometres': p.referenceMicrometres,
                'saved_at': p.savedAt.toUtc().toIso8601String(),
              },
              onConflict: 'user_id,device_label,objective',
            )
            .catchError((_) {
          cache.enqueue(
            PendingSyncOp(
              id: 'cal-${p.objective}',
              kind: SyncOpKind.upsertCalibration,
              payload: calibrationToJson(p),
              createdAt: DateTime.now(),
            ),
          );
        }),
      );
    } else {
      unawaited(
        cache.enqueue(
          PendingSyncOp(
            id: 'cal-${p.objective}',
            kind: SyncOpKind.upsertCalibration,
            payload: calibrationToJson(p),
            createdAt: DateTime.now(),
          ),
        ),
      );
    }
  }

  void deleteCalibration(int objective) {
    final updated = state.calibrations.where((c) => c.objective != objective).toList();
    state = state.copyWith(calibrations: updated);
    if (!AppConfig.supabaseReady) return;
    final cache = ref.read(localCacheProvider);
    unawaited(cache.putCalibrations(updated));
    final sb = Supabase.instance.client;
    final uid = sb.auth.currentUser?.id;
    if (uid != null && ref.read(onlineProvider)) {
      unawaited(
        sb
            .from('calibration_profiles')
            .delete()
            .eq('user_id', uid)
            .eq('objective', objective)
            .catchError((_) {
          cache.enqueue(
            PendingSyncOp(
              id: 'cal-$objective',
              kind: SyncOpKind.deleteCalibration,
              payload: {'objective': objective},
              createdAt: DateTime.now(),
            ),
          );
        }),
      );
    } else {
      unawaited(
        cache.enqueue(
          PendingSyncOp(
            id: 'cal-$objective',
            kind: SyncOpKind.deleteCalibration,
            payload: {'objective': objective},
            createdAt: DateTime.now(),
          ),
        ),
      );
    }
  }
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

/// Order name under the chosen classification system.
String displayOrder(WidgetRef ref, String nemysOrder, String family) =>
    ref.watch(settingsProvider).system.orderFor(nemysOrder, family);
