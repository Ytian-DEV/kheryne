import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/layout/app_shell.dart';
import '../../core/layout/form_factor.dart';
import '../../core/providers.dart';
import '../../core/router/routes.dart';
import '../../core/theme/theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import '../../mock/taxonomy.dart';

/// Developer tools (screen gallery, simulate offline) unlock after tapping
/// the version five times in About.
class DevUnlocked extends Notifier<bool> {
  @override
  bool build() => false;
  void unlock() => state = true;
}

final devUnlockedProvider = NotifierProvider<DevUnlocked, bool>(DevUnlocked.new);

const appVersion = '0.1.0 (1)';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final c = ref.read(settingsProvider.notifier);
    final dev = ref.watch(devUnlockedProvider);
    final online = ref.watch(onlineProvider);
    final desktop = FormFactor.of(context).isDesktop;
    final t = context.t;

    return LargeTitleScaffold(
      title: 'Settings',
      showBack: false,
      maxContentWidth: 720,
      slivers: [
        SliverList.list(children: [
          const OfflineNotice(),
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
            header: 'IDENTIFICATION',
            children: [
              KListRow(
                title: 'Classification system',
                leading: KIcons.key,
                value: s.system == ClassificationSystem.nemys2026 ? 'NeMys 2026' : 'Classic',
                onTap: () => _pickSystem(context, ref),
              ),
              KListRow(title: 'Offline models', leading: KIcons.cpu, value: '${s.modelSizeMb} MB', onTap: () => context.goTo(Routes.settingsModels)),
              KListRow(
                title: 'Calibration profiles',
                leading: KIcons.ruler,
                value: '${s.calibrations.length}',
                onTap: () => context.goTo(Routes.settingsCalibration),
              ),
              if (!desktop)
                KListRow(
                  title: 'Demo feed in Live Scan',
                  subtitle: 'Use sample micrographs instead of the camera',
                  leading: KIcons.images,
                  trailing: Switch(value: s.demoFeed, onChanged: (v) => c.update((x) => x.copyWith(demoFeed: v))),
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
              KListRow(title: 'Name on reports', leading: KIcons.user, value: s.userName),
              KListRow(title: 'Privacy', leading: KIcons.shield, onTap: () => context.goTo(Routes.settingsPrivacy)),
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
    if (picked != null) ref.read(settingsProvider.notifier).update((x) => x.copyWith(system: picked));
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

class ModelsScreen extends ConsumerWidget {
  const ModelsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final online = ref.watch(onlineProvider) && ViewStateScope.of(context) != ViewState.offline;
    final now = ref.watch(clockProvider)();
    return LargeTitleScaffold(
      title: 'Offline models',
      maxContentWidth: 720,
      slivers: [
        SliverList.list(children: [
          KListSection(
            header: 'ON THIS DEVICE',
            footer: 'Identification runs entirely on this device. No images are uploaded.',
            children: [
              const KListRow(title: 'Nematode detector', subtitle: 'Finds candidates in the field of view', value: '21.4 MB'),
              const KListRow(title: 'Genus classifier', subtitle: '19 genera recorded in the Philippines', value: '27.2 MB'),
              KListRow(title: 'Version', value: s.modelVersion),
              KListRow(title: 'Last checked', value: shortDate(now.subtract(const Duration(days: 3)))),
            ],
          ),
          const SizedBox(height: KSpace.s24),
          KButton.secondary(
            label: online ? 'Check for updates' : 'Updates need a connection',
            icon: KIcons.download,
            expand: true,
            onPressed: online ? () => showToast(context, 'You have the latest models.') : null,
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
                  detail: 'Calibrate once per objective with a stage micrometer.',
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
                        value: '${p.micrometresPerPixel.toStringAsFixed(3)} µm/px',
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

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final k = context.k;
    Widget p(String s) => Padding(padding: const EdgeInsets.only(bottom: KSpace.s12), child: Text(s, style: t.callout.copyWith(color: k.textSecondary)));
    return LargeTitleScaffold(
      title: 'Privacy',
      maxContentWidth: 720,
      slivers: [
        SliverList.list(children: [
          KCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Icon(KIcons.shield, color: k.success), const SizedBox(width: KSpace.s8), Text('Your data stays on this device', style: t.headline)]),
            const SizedBox(height: KSpace.s8),
            p('Photos, reports, notes and calibration profiles are stored only on this device. Kheryne does not upload images or results.'),
            p('Exports (PDF, CSV, Excel) leave the device only when you share or save them yourself.'),
            p('Pairing streams the camera view over your local Wi-Fi to your own computer. Nothing passes through a server.'),
            p('Kheryne follows the Data Privacy Act of 2012 (Republic Act No. 10173). Names you add to reports are personal data; delete reports from History to remove them.'),
          ])),
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
            const KListRow(title: 'Models', value: '2.3.0'),
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
