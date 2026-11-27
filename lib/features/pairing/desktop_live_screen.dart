import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/layout/app_shell.dart';
import '../../core/layout/scan_theme.dart';
import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/router/routes.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import '../auth/auth_controller.dart';
import '../workspace/workspace_controller.dart';
import 'pairing_widgets.dart';

enum PairStep { code, connecting, connected, error }

@immutable
class PairingSessionInfo {
  const PairingSessionInfo({
    this.sessionId,
    this.code,
    this.desktopName = 'This computer',
    this.phoneName,
    this.latestFrameBytes,
    this.latestFileName = 'paired_frame.jpg',
    this.latestObjective = 40,
    this.latestReceivedAt,
  });

  final String? sessionId;
  final String? code;
  final String desktopName;
  final String? phoneName;
  final Uint8List? latestFrameBytes;
  final String latestFileName;
  final int latestObjective;
  final DateTime? latestReceivedAt;

  PairingSessionInfo copyWith({
    String? sessionId,
    String? code,
    String? desktopName,
    String? phoneName,
    Uint8List? latestFrameBytes,
    String? latestFileName,
    int? latestObjective,
    DateTime? latestReceivedAt,
  }) =>
      PairingSessionInfo(
        sessionId: sessionId ?? this.sessionId,
        code: code ?? this.code,
        desktopName: desktopName ?? this.desktopName,
        phoneName: phoneName ?? this.phoneName,
        latestFrameBytes: latestFrameBytes ?? this.latestFrameBytes,
        latestFileName: latestFileName ?? this.latestFileName,
        latestObjective: latestObjective ?? this.latestObjective,
        latestReceivedAt: latestReceivedAt ?? this.latestReceivedAt,
      );
}

class PairingSessionData extends Notifier<PairingSessionInfo> {
  @override
  PairingSessionInfo build() {
    var host = 'This computer';
    try {
      if (Platform.localHostname.isNotEmpty) host = Platform.localHostname;
    } catch (_) {}
    return PairingSessionInfo(desktopName: host);
  }

  void update(PairingSessionInfo Function(PairingSessionInfo s) fn) => state = fn(state);
  void reset() {
    var host = 'This computer';
    try {
      if (Platform.localHostname.isNotEmpty) host = Platform.localHostname;
    } catch (_) {}
    state = PairingSessionInfo(desktopName: host);
  }
}

final pairingSessionDataProvider = NotifierProvider<PairingSessionData, PairingSessionInfo>(PairingSessionData.new);

class PairingController extends Notifier<PairStep> {
  RealtimeChannel? _channel;

  SupabaseClient? get _sb => AppConfig.supabaseReady ? Supabase.instance.client : null;

  @override
  PairStep build() {
    ref.onDispose(() {
      final ch = _channel;
      if (ch != null) _sb?.removeChannel(ch);
    });
    return PairStep.code;
  }

  void set(PairStep s) => state = s;

  Future<void> startSession() async {
    final sb = _sb;
    final uid = sb?.auth.currentUser?.id;
    if (sb == null || uid == null) return;

    final existing = ref.read(pairingSessionDataProvider);
    if (existing.code != null && existing.sessionId != null) return;

    state = PairStep.connecting;
    try {
      final rng = math.Random.secure();
      final code = List.generate(6, (_) => rng.nextInt(10)).join();
      final host = ref.read(pairingSessionDataProvider).desktopName;

      final inserted = await sb
          .from('pairing_sessions')
          .insert({
            'code': code,
            'desktop_user_id': uid,
            'desktop_name': host,
            'status': 'waiting',
          })
          .select()
          .single();

      final sessionId = inserted['id'] as String;
      ref.read(pairingSessionDataProvider.notifier).update(
            (s) => s.copyWith(sessionId: sessionId, code: code),
          );
      state = PairStep.code;
      _subscribe(sb, sessionId);
    } catch (_) {
      state = PairStep.error;
    }
  }

  void _subscribe(SupabaseClient sb, String sessionId) {
    final prev = _channel;
    if (prev != null) sb.removeChannel(prev);

    _channel = sb
        .channel('pairing-$sessionId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'pairing_sessions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: sessionId,
          ),
          callback: (payload) {
            final rec = payload.newRecord;
            final st = rec['status'] as String? ?? 'waiting';
            final pName = rec['phone_name'] as String?;
            ref.read(pairingSessionDataProvider.notifier).update((s) => s.copyWith(phoneName: pName));
            if (st == 'connected') {
              state = PairStep.connected;
            } else if (st == 'closed') {
              disconnect();
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'pairing_frames',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'session_id',
            value: sessionId,
          ),
          callback: (payload) {
            unawaited(_loadIncomingFrame(sb, payload.newRecord));
          },
        )
        .subscribe();
  }

  Future<void> _loadIncomingFrame(SupabaseClient sb, Map<String, dynamic> rec) async {
    final storagePath = rec['storage_path'] as String?;
    if (storagePath == null || storagePath.isEmpty) return;
    try {
      final signed = await sb.storage.from('pairing-frames').createSignedUrl(storagePath, 3600);
      final resp = await http.get(Uri.parse(signed)).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return;
      ref.read(pairingSessionDataProvider.notifier).update(
            (s) => s.copyWith(
              latestFrameBytes: resp.bodyBytes,
              latestFileName: rec['file_name'] as String? ?? 'paired_frame.jpg',
              latestObjective: (rec['objective'] as num? ?? 40).toInt(),
              latestReceivedAt: DateTime.now(),
            ),
          );
    } catch (_) {}
  }

  Future<void> disconnect() async {
    final sb = _sb;
    final info = ref.read(pairingSessionDataProvider);
    final ch = _channel;
    if (ch != null && sb != null) {
      await sb.removeChannel(ch);
      _channel = null;
    }
    if (sb != null && info.sessionId != null) {
      try {
        await sb.from('pairing_sessions').update({'status': 'closed'}).eq('id', info.sessionId!);
      } catch (_) {}
    }
    ref.read(pairingSessionDataProvider.notifier).reset();
    state = PairStep.code;
  }
}

final pairingProvider = NotifierProvider<PairingController, PairStep>(PairingController.new);

/// Windows: generate a real 6-digit pairing code in Supabase and receive real
/// microscope frames captured on the paired Android phone.
class DesktopLiveScreen extends ConsumerStatefulWidget {
  const DesktopLiveScreen({super.key});

  @override
  ConsumerState<DesktopLiveScreen> createState() => _DesktopLiveScreenState();
}

class _DesktopLiveScreenState extends ConsumerState<DesktopLiveScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (AppConfig.supabaseReady && ref.read(authProvider).isSignedIn) {
        unawaited(ref.read(pairingProvider.notifier).startSession());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final step = ref.watch(pairingProvider);
    final info = ref.watch(pairingSessionDataProvider);
    final auth = ref.watch(authProvider);
    final c = ref.read(pairingProvider.notifier);

    if (step == PairStep.connected) return const ScanTheme(child: _LiveFrameReceiver());

    final t = context.t;
    final k = context.k;

    if (AppConfig.supabaseReady && !auth.isSignedIn) {
      return Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: EmptyState(
              art: LineArt.pairing,
              message: 'Sign in to pair your phone and computer.',
              detail: 'Pairing uses an authenticated 6-digit session code to send microscope frames securely to this workspace.',
              action: 'Sign in',
              onAction: () => context.pushTo(Routes.auth),
            ),
          ),
        ),
      );
    }

    final displayCode = info.code == null
        ? '— — —  — — —'
        : '${info.code!.substring(0, 3)} ${info.code!.substring(3)}';

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(KSpace.s40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StepDots(step: step == PairStep.code ? 0 : 1, labels: const ['Enter code', 'Connect', 'Receive frames']),
                const SizedBox(height: KSpace.s32),
                if (step == PairStep.code) ...[
                  Text('Live frames from your phone', style: t.title1, textAlign: TextAlign.center),
                  const SizedBox(height: KSpace.s8),
                  Text(
                    'Open Kheryne on your phone → Settings → Pair with computer, then enter this 6-digit code.',
                    style: t.callout.copyWith(color: k.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: KSpace.s24),
                  KCard(
                    padding: const EdgeInsets.symmetric(horizontal: KSpace.s32, vertical: KSpace.s24),
                    child: Column(
                      children: [
                        if (info.code != null) ...[
                          PairingCode(seed: int.tryParse(info.code!) ?? 2026, size: 168),
                          const SizedBox(height: KSpace.s16),
                        ],
                        Text(
                          displayCode,
                          style: t.largeTitle.copyWith(letterSpacing: 4, fontFeatures: KType.tabular),
                        ),
                        const SizedBox(height: KSpace.s8),
                        Text('Pairing code for ${info.desktopName}', style: t.caption),
                      ],
                    ),
                  ),
                  const SizedBox(height: KSpace.s16),
                  KButton.secondary(
                    label: info.code == null ? 'Generate pairing code' : 'Generate new code',
                    icon: KIcons.retry,
                    onPressed: () async {
                      await c.disconnect();
                      await c.startSession();
                    },
                  ),
                ] else if (step == PairStep.connecting) ...[
                  const LineArtView(LineArt.pairing, size: 120),
                  const SizedBox(height: KSpace.s24),
                  SizedBox.square(dimension: 28, child: CircularProgressIndicator(strokeWidth: 2.5, color: k.accent)),
                  const SizedBox(height: KSpace.s16),
                  Semantics(liveRegion: true, child: Text('Creating pairing session…', style: t.title2)),
                  const SizedBox(height: KSpace.s24),
                  KButton.secondary(label: 'Cancel', onPressed: c.disconnect),
                ] else ...[
                  const LineArtView(LineArt.offline, size: 120),
                  const SizedBox(height: KSpace.s24),
                  Text('Couldn’t start pairing session', style: t.title2),
                  const SizedBox(height: KSpace.s8),
                  Text(
                    'Check your internet connection and verify both devices are signed in.',
                    style: t.callout.copyWith(color: k.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: KSpace.s24),
                  KButton(label: 'Try again', icon: KIcons.retry, onPressed: c.startSession),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LiveFrameReceiver extends ConsumerStatefulWidget {
  const _LiveFrameReceiver();

  @override
  ConsumerState<_LiveFrameReceiver> createState() => _LiveFrameReceiverState();
}

class _LiveFrameReceiverState extends ConsumerState<_LiveFrameReceiver> {
  bool _importing = false;

  Future<void> _analyzeFrame(PairingSessionInfo info) async {
    final bytes = info.latestFrameBytes;
    final hybrid = ref.read(hybridRepositoryProvider);
    if (bytes == null || hybrid == null || _importing) return;

    setState(() => _importing = true);
    try {
      final imported = await hybrid.importImageBytes(
        fileName: info.latestFileName,
        bytes: bytes,
        objective: info.latestObjective,
        source: CaptureSource.phone,
      );
      ref.invalidate(specimensProvider);
      ref.read(workspaceProvider.notifier).addFrozenFrame(imported);
      if (!mounted) return;
      StatefulNavigationShell.maybeOf(context)?.goBranch(Branch.workspace);
      showToast(context, 'Imported phone frame into the Workspace.');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final t = context.t;
    final info = ref.watch(pairingSessionDataProvider);
    final phoneLabel = info.phoneName ?? 'Paired phone';
    final hasFrame = info.latestFrameBytes != null;

    return Scaffold(
      backgroundColor: k.canvas,
      body: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: KSpace.s16, vertical: KSpace.s12),
          decoration: BoxDecoration(color: k.background, border: Border(bottom: BorderSide(color: k.separator))),
          child: Row(children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: k.success, shape: BoxShape.circle)),
            const SizedBox(width: KSpace.s8),
            Text('Connected to $phoneLabel', style: t.subhead),
            const SizedBox(width: KSpace.s16),
            if (info.latestReceivedAt != null)
              Text(
                '${info.latestObjective}× objective · Frame ready',
                style: t.caption.copyWith(fontFeatures: KType.tabular),
              ),
            const Spacer(),
            KButton.tertiary(
              label: 'Disconnect',
              size: KButtonSize.compact,
              onPressed: ref.read(pairingProvider.notifier).disconnect,
            ),
            const SizedBox(width: KSpace.s8),
            KButton(
              label: 'Analyze this frame',
              icon: KIcons.frame,
              size: KButtonSize.compact,
              loading: _importing,
              onPressed: hasFrame && !_importing ? () => _analyzeFrame(info) : null,
            ),
          ]),
        ),
        Expanded(
          child: hasFrame
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(KSpace.s16),
                    child: ClipRRect(
                      borderRadius: KRadius.cardAll,
                      child: Image.memory(info.latestFrameBytes!, fit: BoxFit.contain),
                    ),
                  ),
                )
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.all(KSpace.s32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(KIcons.phone, size: 42, color: k.overlayText.withValues(alpha: 0.7)),
                        const SizedBox(height: KSpace.s12),
                        Text(
                          'Waiting for first frame from $phoneLabel',
                          style: t.title2.copyWith(color: k.overlayText),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: KSpace.s8),
                        Text(
                          'Tap "Send frame to computer" on your phone when a nematode is in focus.',
                          style: t.callout.copyWith(color: k.overlayText.withValues(alpha: 0.75)),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ]),
    );
  }
}
