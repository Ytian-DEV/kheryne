import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/data/local_cache_store.dart';
import '../../core/models/models.dart';
import '../../core/models/serialization.dart';
import '../../core/providers.dart';
import '../../mock/taxonomy.dart';

@immutable
class AuthViewState {
  const AuthViewState({
    this.user,
    this.institution = 'Visayas State University',
    this.busy = false,
    this.errorMessage,
    this.infoMessage,
  });

  final User? user;
  final String institution;
  final bool busy;
  final String? errorMessage;
  final String? infoMessage;

  bool get isSignedIn => user != null;
  String? get email => user?.email;

  AuthViewState copyWith({
    User? user,
    bool clearUser = false,
    String? institution,
    bool? busy,
    String? errorMessage,
    bool clearError = false,
    String? infoMessage,
    bool clearInfo = false,
  }) =>
      AuthViewState(
        user: clearUser ? null : (user ?? this.user),
        institution: institution ?? this.institution,
        busy: busy ?? this.busy,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        infoMessage: clearInfo ? null : (infoMessage ?? this.infoMessage),
      );
}

class AuthController extends Notifier<AuthViewState> {
  StreamSubscription<AuthState>? _sub;

  SupabaseClient? get _sb => AppConfig.supabaseReady ? Supabase.instance.client : null;

  @override
  AuthViewState build() {
    final sb = _sb;
    if (sb == null) return const AuthViewState();

    _sub?.cancel();
    _sub = sb.auth.onAuthStateChange.listen((data) {
      final nextUser = data.session?.user;
      state = state.copyWith(
        user: nextUser,
        clearUser: nextUser == null,
        clearError: true,
      );
      if (nextUser != null) {
        unawaited(_hydrateUserProfileAndSync(nextUser));
      }
    });
    ref.onDispose(() => _sub?.cancel());

    final current = sb.auth.currentUser;
    if (current != null) {
      Future.microtask(() => _hydrateUserProfileAndSync(current));
    }
    return AuthViewState(user: current);
  }

  Future<void> _hydrateUserProfileAndSync(User user) async {
    final sb = _sb;
    if (sb == null) return;
    try {
      final profile = await sb.from('profiles').select().eq('id', user.id).maybeSingle();
      if (profile != null) {
        final fullName = profile['full_name'] as String?;
        final inst = profile['institution'] as String?;
        final prefSys = profile['preferred_system'] as String?;
        final scanDark = profile['scan_always_dark'] as bool?;
        state = state.copyWith(institution: inst ?? 'Visayas State University');
        ref.read(settingsProvider.notifier).update(
              (s) => s.copyWith(
                userName: (fullName != null && fullName.trim().isNotEmpty) ? fullName.trim() : s.userName,
                system: prefSys == 'classic' ? ClassificationSystem.classic : ClassificationSystem.nemys2026,
                scanAlwaysDark: scanDark ?? s.scanAlwaysDark,
              ),
            );
      }

      final calRows = await sb
          .from('calibration_profiles')
          .select()
          .eq('user_id', user.id)
          .order('objective');
      if (calRows.isNotEmpty) {
        final cals = [
          for (final r in calRows) calibrationFromJson(Map<String, dynamic>.from(r)),
        ];
        ref.read(settingsProvider.notifier).update((s) => s.copyWith(calibrations: cals));
        await ref.read(localCacheProvider).putCalibrations(cals);
      }

      final hybrid = ref.read(hybridRepositoryProvider);
      if (hybrid != null) {
        await hybrid.syncPending();
        ref.invalidate(historyProvider);
        ref.invalidate(specimensProvider);
      }
    } catch (_) {
      // Offline during startup: local cached profile & calibrations stay active.
    }
  }

  Future<bool> signInWithPassword({required String email, required String password}) async {
    final sb = _sb;
    if (sb == null) return false;
    state = state.copyWith(busy: true, clearError: true, clearInfo: true);
    try {
      final res = await sb.auth.signInWithPassword(email: email.trim(), password: password);
      state = state.copyWith(user: res.user, busy: false);
      return res.user != null;
    } on AuthException catch (e) {
      state = state.copyWith(busy: false, errorMessage: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(busy: false, errorMessage: 'Could not reach Supabase. Check your internet connection.');
      return false;
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
    String institution = 'Visayas State University',
  }) async {
    final sb = _sb;
    if (sb == null) return false;
    state = state.copyWith(busy: true, clearError: true, clearInfo: true);
    try {
      final res = await sb.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'full_name': fullName.trim(),
          'institution': institution.trim(),
        },
        emailRedirectTo: kIsWeb ? null : 'ph.edu.vsu.kheryne://login-callback/',
      );
      if (res.session != null && res.user != null) {
        await sb.from('profiles').upsert({
          'id': res.user!.id,
          'full_name': fullName.trim().isEmpty ? 'Researcher' : fullName.trim(),
          'institution': institution.trim().isEmpty ? 'Visayas State University' : institution.trim(),
        });
        ref.read(settingsProvider.notifier).update((s) => s.copyWith(userName: fullName.trim()));
        state = state.copyWith(
          user: res.user,
          institution: institution.trim(),
          busy: false,
        );
        return true;
      }
      state = state.copyWith(
        busy: false,
        infoMessage: 'Account created! Check your email inbox to confirm your address, then sign in.',
      );
      return false;
    } on AuthException catch (e) {
      state = state.copyWith(busy: false, errorMessage: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(busy: false, errorMessage: 'Could not create account. Check your connection.');
      return false;
    }
  }

  Future<void> signInWithGoogle() async {
    final sb = _sb;
    if (sb == null) return;
    state = state.copyWith(busy: true, clearError: true, clearInfo: true);
    try {
      final isDesktop = !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.windows ||
              defaultTargetPlatform == TargetPlatform.macOS ||
              defaultTargetPlatform == TargetPlatform.linux);
      await sb.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb || isDesktop ? null : 'ph.edu.vsu.kheryne://login-callback/',
      );
      state = state.copyWith(busy: false);
    } on AuthException catch (e) {
      state = state.copyWith(busy: false, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(
        busy: false,
        errorMessage: 'Google Sign-In could not open. Ensure Google OAuth is enabled in your Supabase dashboard.',
      );
    }
  }

  Future<void> updateProfile({String? fullName, String? institution}) async {
    final sb = _sb;
    final uid = state.user?.id;
    if (fullName != null && fullName.trim().isNotEmpty) {
      ref.read(settingsProvider.notifier).update((s) => s.copyWith(userName: fullName.trim()));
    }
    if (institution != null && institution.trim().isNotEmpty) {
      state = state.copyWith(institution: institution.trim());
    }
    if (sb == null || uid == null) return;
    try {
      await sb.from('profiles').upsert({
        'id': uid,
        'full_name': (fullName ?? ref.read(settingsProvider).userName).trim(),
        'institution': (institution ?? state.institution).trim(),
        'preferred_system': ref.read(settingsProvider).system.name,
        'scan_always_dark': ref.read(settingsProvider).scanAlwaysDark,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {}
  }

  Future<void> syncCalibrationSave(CalibrationProfile profile) async {
    final cache = ref.read(localCacheProvider);
    final currentList = ref.read(settingsProvider).calibrations;
    await cache.putCalibrations(currentList);

    final sb = _sb;
    final uid = state.user?.id;
    if (sb != null && uid != null && ref.read(onlineProvider)) {
      try {
        await sb.from('calibration_profiles').upsert(
          {
            'user_id': uid,
            'device_label': 'Default',
            'objective': profile.objective,
            'micrometres_per_pixel': profile.micrometresPerPixel,
            'reference_micrometres': profile.referenceMicrometres,
            'saved_at': profile.savedAt.toUtc().toIso8601String(),
          },
          onConflict: 'user_id,device_label,objective',
        );
        return;
      } catch (_) {}
    }
    await cache.enqueue(
      PendingSyncOp(
        id: 'cal-${profile.objective}',
        kind: SyncOpKind.upsertCalibration,
        payload: calibrationToJson(profile),
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> syncCalibrationDelete(int objective) async {
    final cache = ref.read(localCacheProvider);
    await cache.putCalibrations(ref.read(settingsProvider).calibrations);

    final sb = _sb;
    final uid = state.user?.id;
    if (sb != null && uid != null && ref.read(onlineProvider)) {
      try {
        await sb
            .from('calibration_profiles')
            .delete()
            .eq('user_id', uid)
            .eq('objective', objective);
        return;
      } catch (_) {}
    }
    await cache.enqueue(
      PendingSyncOp(
        id: 'cal-$objective',
        kind: SyncOpKind.deleteCalibration,
        payload: {'objective': objective},
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> signOut() async {
    final sb = _sb;
    if (sb == null) return;
    await sb.auth.signOut();
    state = const AuthViewState();
    ref.invalidate(historyProvider);
    ref.invalidate(specimensProvider);
  }
}

final authProvider = NotifierProvider<AuthController, AuthViewState>(AuthController.new);
