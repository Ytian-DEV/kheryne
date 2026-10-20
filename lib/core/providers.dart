import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mock/mock_repository.dart';
import '../mock/taxonomy.dart';
import 'data/repositories.dart';
import 'layout/form_factor.dart';
import 'models/models.dart';
import 'widgets/async_view.dart' show ViewState;

/// Current time. Overridden with a fixed date in tests and screenshots.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Simulated repository latency. Zero in tests.
final latencyProvider = Provider<Duration>((ref) => const Duration(milliseconds: 450));

class FormFactorController extends Notifier<FormFactor> {
  FormFactorController([this._initial]);
  final FormFactor? _initial;

  @override
  FormFactor build() => _initial ?? FormFactor.fromPlatform();

  /// Screen gallery: preview the other layout.
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

final referenceRepositoryProvider = Provider<ReferenceRepository>((ref) => const MockReferenceRepository());

final identificationRepositoryProvider = Provider<IdentificationRepository>(
  (ref) => MockIdentificationRepository(now: ref.watch(clockProvider), latency: ref.watch(latencyProvider)),
);

final historyProvider = FutureProvider<List<Report>>((ref) => ref.watch(identificationRepositoryProvider).history());

final specimensProvider = FutureProvider<List<Specimen>>((ref) => ref.watch(identificationRepositoryProvider).specimens());

final specimenProvider = FutureProvider.family<Specimen?, String>(
    (ref, id) => ref.watch(identificationRepositoryProvider).specimen(id));

/// Reports produced in this session but not saved yet.
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

/// Mock connectivity, toggled from Settings and the screen gallery.
class Connectivity extends Notifier<bool> {
  @override
  bool build() => true;
  void set(bool online) => state = online;
}

final onlineProvider = NotifierProvider<Connectivity, bool>(Connectivity.new);

@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.scanAlwaysDark = true,
    this.system = ClassificationSystem.nemys2026,
    this.language = 'English',
    this.demoFeed = true,
    this.onboarded = false,
    this.userName = 'Ana Dela Cruz',
    this.calibrations = const [],
    this.modelVersion = '2.3.0',
    this.modelSizeMb = 48.6,
  });

  final ThemeMode themeMode;

  /// Live Scan and Workspace stay dark for dim labs regardless of theme.
  final bool scanAlwaysDark;
  final ClassificationSystem system;
  final String language;

  /// Show the looping mock micrograph instead of the real camera.
  final bool demoFeed;
  final bool onboarded;
  final String userName;
  final List<CalibrationProfile> calibrations;
  final String modelVersion;
  final double modelSizeMb;

  String get firstName => userName.split(' ').first;

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
        modelVersion: modelVersion,
        modelSizeMb: modelSizeMb,
      );
}

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final now = ref.watch(clockProvider)();
    return AppSettings(calibrations: [
      CalibrationProfile(objective: 10, micrometresPerPixel: 1.62, savedAt: now.subtract(const Duration(days: 12)), referenceMicrometres: 1000),
      CalibrationProfile(objective: 40, micrometresPerPixel: 0.405, savedAt: now.subtract(const Duration(days: 12)), referenceMicrometres: 200),
    ]);
  }

  void update(AppSettings Function(AppSettings s) f) => state = f(state);

  void saveCalibration(CalibrationProfile p) => state = state.copyWith(
        calibrations: [...state.calibrations.where((c) => c.objective != p.objective), p]
          ..sort((a, b) => a.objective.compareTo(b.objective)),
      );

  void deleteCalibration(int objective) =>
      state = state.copyWith(calibrations: state.calibrations.where((c) => c.objective != objective).toList());
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

/// Order name under the chosen classification system.
String displayOrder(WidgetRef ref, String nemysOrder, String family) =>
    ref.watch(settingsProvider).system.orderFor(nemysOrder, family);
