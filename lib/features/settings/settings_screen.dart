import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/layout/app_shell.dart';
import '../../core/layout/form_factor.dart';
import '../../core/models/serialization.dart';
import '../../core/providers.dart';
import '../../core/router/routes.dart';
import '../../core/theme/theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import '../../mock/taxonomy.dart';
import '../auth/auth_controller.dart';

/// Developer tools (screen gallery, demo feed, simulate offline) unlock after
/// tapping the version five times in About.
class DevUnlocked extends Notifier<bool> {
  @override
  bool build() => false;
  void unlock() => state = true;
}

final devUnlockedProvider = NotifierProvider<DevUnlocked, bool>(DevUnlocked.new);

const appVersion = '0.2.0 (2)';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final c = ref.read(settingsProvider.notifier);
    final auth = ref.watch(authProvider);
    final pendingCount = AppConfig.supabaseReady ? ref.watch(localCacheProvider).pendingCount : 0;
    final dev = ref.watch(devUnlockedProvider);
    final online = ref.watch(onlineProvider);
    final desktop = FormFactor.of(context).isDesktop;
    final t = context.t;

    final modelsValue = s.modelSizeMb > 0 ? '${s.modelSizeMb} MB' : 'OpenCV';

    return LargeTitleScaffold(
      title: 'Settings',
      showBack: false,
      maxContentWidth: 720,
      slivers: [
        SliverList.list(children: [
          const OfflineNotice(),
          KListSection(
            header: 'ACCOUNT & CLOUD SYNC',
            footer: auth.isSignedIn
                ? 'Reports, micrographs, notes and calibrations sync automatically across your phone and computer.'
                : 'Sign in to back up reports and micrographs to Supabase and sync between Android and Windows.',
            children: [
              if (auth.isSignedIn) ...[
                KListRow(
                  title: auth.email ?? s.firstName,
                  subtitle: pendingCount > 0
                      ? '${auth.roleLabel} · ${auth.institution} · $pendingCount queued offline'
                      : '${auth.roleLabel} · ${auth.institution} · Synced',
                  leading: KIcons.user,
                  chevron: false,
                ),
                KListRow(
                  title: 'Sync now',
                  leading: KIcons.retry,
                  value: pendingCount > 0 ? '$pendingCount pending' : 'Up to date',
                  onTap: () async {
                    final hybrid = ref.read(hybridRepositoryProvider);
                    final count = await hybrid?.syncPending() ?? 0;
                    await ref.read(cloudReferenceRepositoryProvider)?.refreshFromCloud();
                    ref.invalidate(historyProvider);
                    ref.invalidate(specimensProvider);
                    if (context.mounted) {
                      showToast(context, count > 0 ? 'Synced $count queued item${count == 1 ? '' : 's'}.' : 'Everything is up to date.');
                    }
                  },
                ),
                KListRow(
                  title: 'Sign out',
                  leading: KIcons.close,
                  leadingColor: context.k.error,
                  chevron: false,
                  onTap: () async {
                    await ref.read(authProvider.notifier).signOut();
                    if (context.mounted) showToast(context, 'Signed out.');
                  },
                ),
              ] else ...[
                KListRow(
                  title: 'Sign in or create account',
                  subtitle: pendingCount > 0
                      ? '$pendingCount offline scan${pendingCount == 1 ? '' : 's'} ready to sync after sign-in'
                      : 'Email & password or Google Sign-In',
                  leading: KIcons.user,
                  onTap: () => context.pushTo(Routes.auth),
                ),
              ],
            ],
          ),
          const SizedBox(height: KSpace.s24),
          KListSection(
            header: 'APPEARANCE',
            footer: 'Live Scan and the Workspace stay dark for dim labs unless you turn this off.',
            children: [
              Padding(
                padding: const EdgeInsets.all(KSpace.s12),
                child: KSegmentedControl<ThemeMode>(
                  segments: const [
                    (ThemeMode.system, 'System', KIcons.contrast),
                    (ThemeMode.light, 'Light', KIcons.sun),
                    (ThemeMode.dark, 'Dark', KIcons.moon),
                  ],
                  value: s.themeMode,
                  onChanged: (m) => c.update((x) => x.copyWith(themeMode: m)),
                ),
              ),
              KListRow(
                title: 'Scan always dark',
                leading: KIcons.moon,
                trailing: Switch(value: s.scanAlwaysDark, onChanged: (v) => c.update((x) => x.copyWith(scanAlwaysDark: v))),
              ),
            ],
          ),
          const SizedBox(height: KSpace.s24),
          KListSection(
            header: 'IDENTIFICATION & DATASET',
            children: [
              KListRow(
                title: 'Classification system',
                leading: KIcons.key,
                value: s.system == ClassificationSystem.nemys2026 ? 'NeMys 2026' : 'Classic',
                onTap: () => _pickSystem(context, ref),
              ),
              KListRow(
                title: 'Models & ML server',
                leading: KIcons.cpu,
                value: modelsValue,
                onTap: () => context.goTo(Routes.settingsModels),
              ),
              KListRow(
                title: 'Lab dataset & review queue',
                subtitle: auth.isScientistOrOwner
                    ? 'Curate Gold lab samples and verify user submissions'
                    : 'Submit slides for scientist verification',
                leading: KIcons.flask,
                onTap: () => desktop
                    ? StatefulNavigationShell.maybeOf(context)?.goBranch(Branch.training)
                    : context.pushTo(Routes.training),
              ),
              KListRow(
                title: 'Calibration profiles',
                leading: KIcons.ruler,
                value: '${s.calibrations.length}',
                onTap: () => context.goTo(Routes.settingsCalibration),
              ),
            ],
          ),
          const SizedBox(height: KSpace.s24),
          KListSection(
            header: 'DEVICES',
            children: [
              if (desktop)
                KListRow(title: 'Pair a phone', leading: KIcons.phone, onTap: () => StatefulNavigationShell.maybeOf(context)?.goBranch(Branch.live))
              else
                KListRow(title: 'Pair with computer', leading: KIcons.pair, onTap: () => context.pushTo(Routes.pairPhone)),
            ],
          ),
          const SizedBox(height: KSpace.s24),
          KListSection(
            header: 'GENERAL',
            children: [
              KListRow(title: 'Language', leading: KIcons.language, value: s.language, onTap: () => _pickLanguage(context, ref)),
              KListRow(
                title: 'Name on reports',
                leading: KIcons.user,
                value: s.userName.trim().isEmpty ? 'Not set' : s.userName,
                onTap: () => _editName(context, ref),
              ),
              KListRow(title: 'Privacy & training consent', leading: KIcons.shield, onTap: () => context.goTo(Routes.settingsPrivacy)),
              KListRow(title: 'About Kheryne', leading: KIcons.info, value: appVersion, onTap: () => context.goTo(Routes.settingsAbout)),
            ],
          ),
          if (dev) ...[
            const SizedBox(height: KSpace.s24),
            KListSection(
              header: 'DEVELOPER',
              children: [
                KListRow(title: 'Screen gallery', leading: KIcons.grid, onTap: () => context.pushTo(Routes.screenGallery)),
                KListRow(title: 'Component sheet', leading: KIcons.layout, onTap: () => context.pushTo(Routes.components)),
                KListRow(
                  title: 'Demo feed in Live Scan',
                  subtitle: 'Use painted sample slide instead of camera',
                  leading: KIcons.images,
                  trailing: Switch(value: s.demoFeed, onChanged: (v) => c.update((x) => x.copyWith(demoFeed: v))),
                ),
                KListRow(
                  title: 'Simulate offline',
                  leading: KIcons.wifiOff,
                  trailing: Switch(value: !online, onChanged: (v) => ref.read(onlineProvider.notifier).set(!v)),
                ),
                KListRow(title: 'Show onboarding', leading: KIcons.book, onTap: () => context.pushTo(Routes.onboarding)),
              ],
            ),
          ],
          const SizedBox(height: KSpace.s24),
          Text('Kheryne supports identification. Confirm important results with a qualified nematologist.',
              style: t.caption, textAlign: TextAlign.center),
          const SizedBox(height: 96),
        ]),
      ],
    );
  }

  Future<void> _editName(BuildContext context, WidgetRef ref) async {
    final current = ref.read(settingsProvider).userName;
    final ctrl = TextEditingController(text: current);
    final saved = await showKBottomSheet<String>(
      context,
      title: 'Name on reports',
      initial: 0.42,
      detents: const [0.42],
      builder: (ctx, scrollCtrl) => ListView(
        controller: scrollCtrl,
        padding: const EdgeInsets.all(KSpace.s16),
        children: [
          TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Full name',
              prefixIcon: Icon(KIcons.user, size: KSize.icon),
            ),
            onSubmitted: (v) => Navigator.of(ctx).pop(v),
          ),
          const SizedBox(height: KSpace.s16),
          KButton(
            label: 'Save name',
            expand: true,
            onPressed: () => Navigator.of(ctx).pop(ctrl.text),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (saved != null) {
      ref.read(settingsProvider.notifier).update((s) => s.copyWith(userName: saved.trim()));
      if (saved.trim().isNotEmpty) {
        await ref.read(authProvider.notifier).updateProfile(fullName: saved.trim());
      }
    }
  }

  Future<void> _pickSystem(BuildContext context, WidgetRef ref) async {
    final current = ref.read(settingsProvider).system;
    final picked = await showKBottomSheet<ClassificationSystem>(
      context,
      title: 'Classification system',
      initial: 0.5,
      detents: const [0.5],
      builder: (ctx, c) => ListView(
        controller: c,
        padding: const EdgeInsets.fromLTRB(KSpace.s16, KSpace.s8, KSpace.s16, KSpace.s24),
        children: [
          KListSection(
            footer: 'Only the order name changes. Families and genera are the same in both systems.',
            children: [
              for (final s in ClassificationSystem.values)
                KListRow(
                  title: s.label,
                  subtitle: s == ClassificationSystem.nemys2026
                      ? 'Current accepted names. Plant parasites sit under Rhabditida.'
                      : 'Older textbooks: Tylenchida and Aphelenchida.',
                  trailing: s == current ? Icon(KIcons.check, color: ctx.k.primary, size: KSize.icon) : null,
                  chevron: false,
                  onTap: () => Navigator.of(ctx).pop(s),
                ),
            ],
          ),
        ],
      ),
    );
    if (picked != null) {
      ref.read(settingsProvider.notifier).update((x) => x.copyWith(system: picked));
      await ref.read(authProvider.notifier).updateProfile();
    }
  }

  Future<void> _pickLanguage(BuildContext context, WidgetRef ref) => showKBottomSheet<void>(
        context,
        title: 'Language',
        initial: 0.4,
        detents: const [0.4],
        builder: (ctx, c) => ListView(
          controller: c,
          padding: const EdgeInsets.fromLTRB(KSpace.s16, KSpace.s8, KSpace.s16, KSpace.s24),
          children: [
            KListSection(children: [
              KListRow(title: 'English', trailing: Icon(KIcons.check, color: ctx.k.primary, size: KSize.icon), chevron: false),
              const KListRow(title: 'Filipino', subtitle: 'Coming in a later version', leading: KIcons.lock, leadingColor: null),
            ]),
          ],
        ),
      );
}

class ModelsScreen extends ConsumerStatefulWidget {
  const ModelsScreen({super.key});

  @override
  ConsumerState<ModelsScreen> createState() => _ModelsScreenState();
}

class _ModelsScreenState extends ConsumerState<ModelsScreen> {
  bool _checkingUpdates = false;
  bool _checkingServer = false;
  String? _serverStatus;
  List<MlModelRelease> _releases = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadReleases());
  }

  Future<void> _loadReleases() async {
    final hybrid = ref.read(hybridRepositoryProvider);
    if (hybrid == null) return;
    final list = await hybrid.fetchActiveModelReleases();
    if (mounted) setState(() => _releases = list);
  }

  Future<void> _checkUpdates() async {
    final hybrid = ref.read(hybridRepositoryProvider);
    final now = ref.read(clockProvider)();
    if (hybrid == null) {
      showToast(context, 'Checked model status.');
      return;
    }
    setState(() => _checkingUpdates = true);
    final releases = await hybrid.fetchActiveModelReleases();
    if (!mounted) return;
    setState(() {
      _checkingUpdates = false;
      _releases = releases;
    });
    if (releases.isEmpty) {
      ref.read(settingsProvider.notifier).update(
            (s) => s.copyWith(modelVersion: 'None', modelSizeMb: 0, lastModelCheckAt: now),
          );
      showToast(context, 'No trained ONNX releases published in Supabase yet.');
      return;
    }
    final latestVersion = releases.first.version;
    final totalSize = releases.fold<double>(0, (sum, r) => sum + r.sizeMb);
    ref.read(settingsProvider.notifier).update(
          (s) => s.copyWith(
            modelVersion: latestVersion,
            modelSizeMb: double.parse(totalSize.toStringAsFixed(1)),
            lastModelCheckAt: now,
          ),
        );
    showToast(context, 'Synced active model release v$latestVersion.');
  }

  Future<void> _testServer() async {
    setState(() => _checkingServer = true);
    final health = await ref.read(mlServerClientProvider).checkHealth();
    if (!mounted) return;
    setState(() {
      _checkingServer = false;
      _serverStatus = health.reachable
          ? 'Connected · Detector: ${health.detectorEngine} · Classifier: ${health.classifierEngine}'
          : 'Unreachable · Start server/ or set Hugging Face Space URL';
    });
  }

  Future<void> _editServerUrl() async {
    final current = ref.read(settingsProvider).mlServerUrl;
    final ctrl = TextEditingController(text: current);
    final saved = await showKBottomSheet<String>(
      context,
      title: 'Python ML server URL',
      initial: 0.45,
      detents: const [0.45],
      builder: (ctx, scrollCtrl) => ListView(
        controller: scrollCtrl,
        padding: const EdgeInsets.all(KSpace.s16),
        children: [
          TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Server URL (local or Hugging Face Space)',
              hintText: 'https://your-space.hf.space',
              prefixIcon: Icon(KIcons.globe, size: KSize.icon),
            ),
            onSubmitted: (v) => Navigator.of(ctx).pop(v),
          ),
          const SizedBox(height: KSpace.s16),
          KButton(
            label: 'Save URL',
            expand: true,
            onPressed: () => Navigator.of(ctx).pop(ctrl.text),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (saved != null && saved.trim().isNotEmpty) {
      ref.read(settingsProvider.notifier).update((s) => s.copyWith(mlServerUrl: saved.trim()));
      await _testServer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    final online = ref.watch(onlineProvider) && ViewStateScope.of(context) != ViewState.offline;
    final detRel = _releases.where((r) => r.modelType == 'detector').firstOrNull;
    final clsRel = _releases.where((r) => r.modelType == 'classifier').firstOrNull;

    return LargeTitleScaffold(
      title: 'Models & ML server',
      maxContentWidth: 720,
      slivers: [
        SliverList.list(children: [
          KListSection(
            header: 'PUBLISHED MODEL WEIGHTS (SUPABASE)',
            footer: 'Once you train detector.onnx and classifier.onnx from your curated dataset, publish them to ml_model_releases.',
            children: [
              KListRow(
                title: 'Nematode detector',
                subtitle: detRel == null ? 'Using OpenCV morphological detector until trained' : 'Published v${detRel.version}',
                value: detRel == null ? 'OpenCV' : '${detRel.sizeMb} MB',
              ),
              KListRow(
                title: 'Genus classifier',
                subtitle: clsRel == null ? 'Not trained yet · Collect samples in Lab dataset' : 'Published v${clsRel.version}',
                value: clsRel == null ? 'Pending' : '${clsRel.sizeMb} MB',
              ),
              KListRow(
                title: 'Active release',
                value: s.modelVersion == 'None' ? 'None published' : s.modelVersion,
              ),
              KListRow(
                title: 'Last checked',
                value: s.lastModelCheckAt == null ? 'Never' : shortDate(s.lastModelCheckAt!),
              ),
            ],
          ),
          const SizedBox(height: KSpace.s24),
          KButton.secondary(
            label: online ? 'Check Supabase for published models' : 'Updates need a connection',
            icon: KIcons.download,
            expand: true,
            loading: _checkingUpdates,
            onPressed: online && !_checkingUpdates ? _checkUpdates : null,
          ),
          const SizedBox(height: KSpace.s24),
          KListSection(
            header: 'HYBRID PYTHON ML SERVER',
            footer: 'Deploy server/ to Hugging Face Spaces (Docker) or run locally with uvicorn on port 7860.',
            children: [
              KListRow(
                title: 'Server endpoint',
                subtitle: _serverStatus ?? s.mlServerUrl,
                leading: KIcons.globe,
                onTap: _editServerUrl,
              ),
              KListRow(
                title: 'Check server connection',
                leading: KIcons.cpu,
                value: _checkingServer ? 'Checking…' : 'Test',
                onTap: online && !_checkingServer ? _testServer : null,
              ),
            ],
          ),
        ]),
      ],
    );
  }
}

class CalibrationProfilesScreen extends ConsumerWidget {
  const CalibrationProfilesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final now = ref.watch(clockProvider)();
    final forcedEmpty = ViewStateScope.of(context) == ViewState.empty;
    return LargeTitleScaffold(
      title: 'Calibration',
      maxContentWidth: 720,
      actions: [KIconButton(icon: KIcons.plus, label: 'Add calibration', onPressed: () => context.pushTo(Routes.calibrate))],
      slivers: [
        SliverToBoxAdapter(
          child: s.calibrations.isEmpty || forcedEmpty
              ? EmptyState(
                  art: LineArt.microscope,
                  message: 'No calibration profiles yet.',
                  detail: 'Calibrate once per objective with a stage micrometer photo.',
                  action: 'Calibrate',
                  onAction: () => context.pushTo(Routes.calibrate),
                )
              : KListSection(
                  header: 'ONE PROFILE PER OBJECTIVE',
                  footer: 'Measurements use the profile for the objective the image was taken with.',
                  children: [
                    for (final p in s.calibrations)
                      KListRow(
                        title: '${p.objective}× objective',
                        subtitle: 'Saved ${relative(p.savedAt, now)} · ${p.referenceMicrometres.toStringAsFixed(0)} µm reference',
                        value: '${p.micrometresPerPixel.toStringAsFixed(4)} µm/px',
                        trailing: KIconButton(
                          icon: KIcons.trash,
                          label: 'Delete ${p.objective}× profile',
                          color: context.k.error,
                          size: 18,
                          onPressed: () => ref.read(settingsProvider.notifier).deleteCalibration(p.objective),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final k = context.k;
    final s = ref.watch(settingsProvider);
    Widget p(String txt) => Padding(
          padding: const EdgeInsets.only(bottom: KSpace.s12),
          child: Text(txt, style: t.callout.copyWith(color: k.textSecondary)),
        );
    return LargeTitleScaffold(
      title: 'Privacy',
      maxContentWidth: 720,
      slivers: [
        SliverList.list(children: [
          KListSection(
            header: 'MODEL TRAINING CONTRIBUTION',
            footer: 'When enabled, saved scans enter the VSU Scientist Verification Queue so verified specimens can improve future nematode models.',
            children: [
              KListRow(
                title: 'Contribute scans to model training',
                leading: KIcons.flask,
                trailing: Switch(
                  value: s.trainingOptIn,
                  onChanged: (v) async {
                    ref.read(settingsProvider.notifier).update((x) => x.copyWith(trainingOptIn: v));
                    await ref.read(authProvider.notifier).updateProfile();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: KSpace.s24),
          KCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(KIcons.shield, color: k.success),
                const SizedBox(width: KSpace.s8),
                Text('Your research data stays protected', style: t.headline),
              ]),
              const SizedBox(height: KSpace.s8),
              p('Photos, reports, notes and calibration profiles are saved locally first so you never lose work offline. When signed in, they sync over TLS to your Supabase account protected by PostgreSQL Row-Level Security.'),
              p('Exports (PDF, CSV, Excel) are shared externally only when you save or send them yourself.'),
              p('Kheryne follows the Data Privacy Act of 2012 (Republic Act No. 10173). Deleting a report in History removes it from both this device and your cloud account.'),
            ]),
          ),
        ]),
      ],
    );
  }
}

class AboutScreen extends ConsumerStatefulWidget {
  const AboutScreen({super.key});

  @override
  ConsumerState<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends ConsumerState<AboutScreen> {
  int _taps = 0;

  void _tapVersion() {
    _taps++;
    if (_taps >= 5) {
      _taps = 0;
      ref.read(devUnlockedProvider.notifier).unlock();
      context.push(Routes.screenGallery);
    } else if (_taps >= 3) {
      showToast(context, '${5 - _taps} more taps to open the screen gallery.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final k = context.k;
    final modelVer = ref.watch(settingsProvider).modelVersion;
    return LargeTitleScaffold(
      title: 'About',
      maxContentWidth: 720,
      slivers: [
        SliverList.list(children: [
          Center(
            child: Column(children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: k.primary, width: 3)),
                child: Container(width: 18, height: 18, decoration: BoxDecoration(color: k.primary, shape: BoxShape.circle)),
              ),
              const SizedBox(height: KSpace.s12),
              Text('Kheryne', style: t.title1),
              const SizedBox(height: KSpace.s4),
              Text('Plant-parasitic nematode identification', style: t.caption),
            ]),
          ),
          const SizedBox(height: KSpace.s24),
          KListSection(children: [
            KListRow(title: 'Version', value: appVersion, onTap: _tapVersion, chevron: false),
            KListRow(title: 'Models', value: modelVer == 'None' ? 'OpenCV baseline' : modelVer),
            const KListRow(title: 'Taxonomy', value: 'NeMys 2026'),
          ]),
          const SizedBox(height: KSpace.s24),
          KListSection(header: 'THESIS', children: [
            KListRow(
              title: 'Kheryne: An AI-Assisted Mobile and Desktop Application for Identifying Plant-Parasitic Nematodes from Order to Genus Through Morphological Analysis of Microscope Images',
              titleWidget: Text(
                'Kheryne: An AI-Assisted Mobile and Desktop Application for Identifying Plant-Parasitic Nematodes from Order to Genus Through Morphological Analysis of Microscope Images',
                style: t.callout,
              ),
              leading: KIcons.graduation,
            ),
            const KListRow(title: 'Visayas State University', subtitle: 'BS Computer Science'),
          ]),
          const SizedBox(height: KSpace.s24),
          KListSection(header: 'DISCLAIMER', children: [
            Padding(
              padding: const EdgeInsets.all(KSpace.s16),
              child: Text(
                'Kheryne supports identification. Confirm important results with a qualified nematologist. Results show a confidence level; when Kheryne is unsure it says so.',
                style: t.callout,
              ),
            ),
          ]),
          const SizedBox(height: KSpace.s24),
          const KListSection(header: 'ACKNOWLEDGEMENTS', children: [
            KListRow(title: 'Inter typeface', subtitle: 'Rasmus Andersson · SIL Open Font License 1.1'),
            KListRow(title: 'Phosphor Icons', subtitle: 'Helena Zhang and Tobias Fried · MIT License'),
            KListRow(title: 'NeMys', subtitle: 'Nematode species database, Ghent University'),
          ]),
        ]),
      ],
    );
  }
}
