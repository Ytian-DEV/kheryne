import 'dart:async';

import 'package:camera/camera.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/layout/scan_theme.dart';
import '../../core/models/serialization.dart';
import '../../core/providers.dart';
import '../../core/router/routes.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import '../auth/auth_controller.dart';

enum PhonePairStep { scan, streaming }

/// Android counterpart: enter the 6-digit pairing code shown on the computer,
/// then capture & send real microscope frames directly to the computer Workspace.
class PhonePairScreen extends ConsumerStatefulWidget {
  const PhonePairScreen({super.key, this.initial = PhonePairStep.scan});
  final PhonePairStep initial;

  @override
  ConsumerState<PhonePairScreen> createState() => _PhonePairScreenState();
}

class _PhonePairScreenState extends ConsumerState<PhonePairScreen> {
  late PhonePairStep _step = widget.initial;
  final _codeCtrl = TextEditingController();
  CameraController? _camera;
  bool _cameraFailed = false;
  bool _joining = false;
  bool _sending = false;
  int _objective = 40;
  int _sentCount = 0;
  String? _sessionId;
  String _desktopName = 'Computer';

  SupabaseClient? get _sb => AppConfig.supabaseReady ? Supabase.instance.client : null;

  @override
  void initState() {
    super.initState();
    if (_step == PhonePairStep.streaming) {
      unawaited(_initCamera());
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _camera?.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) throw StateError('no camera');
      final ctrl = CameraController(cams.first, ResolutionPreset.high, enableAudio: false);
      await ctrl.initialize();
      if (!mounted) {
        await ctrl.dispose();
        return;
      }
      setState(() => _camera = ctrl);
    } catch (_) {
      if (mounted) setState(() => _cameraFailed = true);
    }
  }

  Future<void> _joinWithCode() async {
    final sb = _sb;
    final uid = sb?.auth.currentUser?.id;
    if (sb == null || uid == null) {
      context.pushTo(Routes.auth);
      return;
    }

    final code = _codeCtrl.text.replaceAll(RegExp(r'\s+'), '');
    if (code.length != 6) {
      showToast(context, 'Enter the 6-digit code shown on your computer.');
      return;
    }

    setState(() => _joining = true);
    try {
      final session = await sb
          .from('pairing_sessions')
          .select()
          .eq('code', code)
          .eq('status', 'waiting')
          .maybeSingle();

      if (session == null) {
        if (mounted) showToast(context, 'Code not found or expired. Generate a fresh code on your computer.');
        return;
      }

      final sessionId = session['id'] as String;
      final desktopName = session['desktop_name'] as String? ?? 'Computer';
      final firstName = ref.read(settingsProvider).firstNameOrNull;
      final phoneLabel = firstName == null ? 'Android Phone' : '$firstName’s Phone';

      await sb.from('pairing_sessions').update({
        'phone_user_id': uid,
        'phone_name': phoneLabel,
        'status': 'connected',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', sessionId);

      if (!mounted) return;
      setState(() {
        _sessionId = sessionId;
        _desktopName = desktopName;
        _step = PhonePairStep.streaming;
      });
      await _initCamera();
    } catch (_) {
      if (mounted) showToast(context, 'Could not join pairing session.');
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<void> _sendFrame({bool fromFile = false}) async {
    final sb = _sb;
    final uid = sb?.auth.currentUser?.id;
    final sid = _sessionId;
    if (sb == null || uid == null || sid == null || _sending) return;

    setState(() => _sending = true);
    try {
      Uint8List? bytes;
      var fileName = 'frame_${DateTime.now().millisecondsSinceEpoch}.jpg';

      if (!fromFile && _camera != null && _camera!.value.isInitialized) {
        final shot = await _camera!.takePicture();
        bytes = await shot.readAsBytes();
      } else {
        final picked = await openFile(
          acceptedTypeGroups: const [
            XTypeGroup(label: 'Images', extensions: ['jpg', 'jpeg', 'png', 'webp']),
          ],
        );
        if (picked == null) {
          if (mounted) setState(() => _sending = false);
          return;
        }
        fileName = picked.name;
        bytes = await picked.readAsBytes();
      }

      final frameId = newUuid();
      final storagePath = '$uid/${sid}_$frameId.jpg';
      await sb.storage.from('pairing-frames').uploadBinary(
            storagePath,
            bytes,
            fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
          );

      await sb.from('pairing_frames').insert({
        'id': frameId,
        'session_id': sid,
        'sender_user_id': uid,
        'storage_path': storagePath,
        'file_name': fileName,
        'objective': _objective,
      });

      if (!mounted) return;
      setState(() => _sentCount++);
      showToast(context, 'Sent frame #$_sentCount to $_desktopName.');
    } catch (_) {
      if (mounted) showToast(context, 'Could not send frame to computer.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _stopSession() async {
    final sb = _sb;
    final sid = _sessionId;
    if (sb != null && sid != null) {
      try {
        await sb.from('pairing_sessions').update({'status': 'closed'}).eq('id', sid);
      } catch (_) {}
    }
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    return ScanTheme(
      child: Builder(builder: (context) {
        final k = context.k;
        final t = context.t;
        final streaming = _step == PhonePairStep.streaming;

        if (AppConfig.supabaseReady && !auth.isSignedIn) {
          return Scaffold(
            backgroundColor: k.canvas,
            appBar: const KNavBar(title: 'Pair with computer', onDark: true),
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: EmptyState(
                  art: LineArt.pairing,
                  message: 'Sign in first to pair with your computer.',
                  action: 'Sign in',
                  onAction: () => context.pushTo(Routes.auth),
                ),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: k.canvas,
          appBar: KNavBar(title: streaming ? 'Connected to $_desktopName' : 'Pair with computer', onDark: true),
          body: Column(
            children: [
              Expanded(
                child: streaming
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          if (_camera != null && _camera!.value.isInitialized)
                            ClipRect(
                              child: FittedBox(
                                fit: BoxFit.cover,
                                child: SizedBox(
                                  width: _camera!.value.previewSize?.height ?? 1080,
                                  height: _camera!.value.previewSize?.width ?? 1920,
                                  child: CameraPreview(_camera!),
                                ),
                              ),
                            )
                          else
                            Center(
                              child: Text(
                                _cameraFailed
                                    ? 'Camera unavailable · Use "Send image file" below'
                                    : 'Opening eyepiece camera…',
                                style: t.callout.copyWith(color: k.overlayText),
                              ),
                            ),
                          Positioned(
                            top: KSpace.s16,
                            left: KSpace.s16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: KSpace.s12, vertical: 6),
                              decoration: BoxDecoration(color: k.canvas.withValues(alpha: 0.72), borderRadius: KRadius.pill),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Container(width: 8, height: 8, decoration: BoxDecoration(color: k.success, shape: BoxShape.circle)),
                                const SizedBox(width: KSpace.s8),
                                Text('Paired · $_sentCount sent', style: t.captionStrong.copyWith(color: k.overlayText)),
                              ]),
                            ),
                          ),
                        ],
                      )
                    : Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(KSpace.s24),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 380),
                            child: KCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text('Enter 6-digit computer code', style: t.headline),
                                  const SizedBox(height: KSpace.s8),
                                  Text(
                                    'On your computer, open Kheryne → Live (phone) and enter the 6-digit pairing code shown on screen.',
                                    style: t.caption,
                                  ),
                                  const SizedBox(height: KSpace.s16),
                                  TextField(
                                    controller: _codeCtrl,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    maxLength: 6,
                                    style: t.title1.copyWith(letterSpacing: 6, fontFeatures: KType.tabular),
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    onSubmitted: (_) => _joinWithCode(),
                                    decoration: const InputDecoration(
                                      counterText: '',
                                      hintText: '000000',
                                    ),
                                  ),
                                  const SizedBox(height: KSpace.s16),
                                  KButton(
                                    label: 'Connect to computer',
                                    icon: KIcons.pair,
                                    expand: true,
                                    loading: _joining,
                                    onPressed: _joining ? null : _joinWithCode,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
              if (streaming)
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(color: k.surface, borderRadius: KRadius.sheetTop),
                  padding: EdgeInsets.fromLTRB(KSpace.s20, KSpace.s20, KSpace.s20, MediaQuery.paddingOf(context).bottom + KSpace.s16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      KSegmentedControl<int>(
                        segments: const [(10, '10×', null), (40, '40×', null), (100, '100×', null)],
                        value: _objective,
                        onChanged: (v) => setState(() => _objective = v),
                      ),
                      const SizedBox(height: KSpace.s12),
                      KButton(
                        label: _camera != null && _camera!.value.isInitialized
                            ? 'Send frame to $_desktopName'
                            : 'Send image file to $_desktopName',
                        icon: KIcons.frame,
                        expand: true,
                        loading: _sending,
                        onPressed: _sending ? null : () => _sendFrame(fromFile: _camera == null || !_camera!.value.isInitialized),
                      ),
                      const SizedBox(height: KSpace.s8),
                      KButton.secondary(
                        label: 'Stop session',
                        expand: true,
                        onPressed: _stopSession,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}
