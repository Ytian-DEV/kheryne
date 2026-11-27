import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_screen.dart';
import '../../features/batch/batch_screen.dart';
import '../../features/gallery/gallery_screen.dart';
import '../../features/gallery/genus_detail_screen.dart';
import '../../features/history/history_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/home/onboarding_screen.dart';
import '../../features/identify/analysis_screen.dart';
import '../../features/identify/identification_screen.dart';
import '../../features/key/key_screen.dart';
import '../../features/morphometrics/calibration_screen.dart';
import '../../features/morphometrics/measure_screen.dart';
import '../../features/pairing/desktop_live_screen.dart';
import '../../features/pairing/phone_pair_screen.dart';
import '../../features/report/full_report_screen.dart';
import '../../features/report/pdf_preview_screen.dart';
import '../../features/report/report_screen.dart';
import '../../features/scan/capture_review_screen.dart';
import '../../features/scan/image_editor_screen.dart';
import '../../features/scan/live_scan_screen.dart';
import '../../features/scan/zoomed_specimen_screen.dart';
import '../../features/settings/component_sheet.dart';
import '../../features/settings/screen_gallery.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/workspace/compare_screen.dart';
import '../../features/workspace/import_screen.dart';
import '../../features/workspace/workspace_screen.dart';
import '../layout/app_shell.dart';
import '../layout/form_factor.dart';
import '../theme/theme.dart';
import 'routes.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

GoRouter buildRouter({required FormFactor formFactor, String? initialLocation, required bool Function() onboarded}) {
  final start = initialLocation ??
      (formFactor.isDesktop ? Routes.workspace : (onboarded() ? Routes.home : Routes.onboarding));

  GoRoute full(String path, Widget Function(GoRouterState s) build, {bool fade = false}) => GoRoute(
        path: path,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => fade
            ? CustomTransitionPage(
                key: state.pageKey,
                child: build(state),
                transitionDuration: KMotion.of(context, KMotion.base),
                transitionsBuilder: (context, a, _, child) => FadeTransition(opacity: a, child: child),
              )
            : MaterialPage(key: state.pageKey, child: build(state)),
      );

  String p(GoRouterState s, String k) => s.pathParameters[k]!;

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: start,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen())]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.history, builder: (_, _) => const HistoryScreen(), routes: [
              GoRoute(path: ':id', builder: (_, s) => ReportScreen(reportId: p(s, 'id'), fromHistory: true)),
            ]),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.gallery, builder: (_, _) => const GalleryScreen(), routes: [
              GoRoute(path: 'genus/:name', builder: (_, s) => GenusDetailScreen(name: p(s, 'name'))),
            ]),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.settings, builder: (_, _) => const SettingsScreen(), routes: [
              GoRoute(path: 'models', builder: (_, _) => const ModelsScreen()),
              GoRoute(path: 'calibration', builder: (_, _) => const CalibrationProfilesScreen()),
              GoRoute(path: 'privacy', builder: (_, _) => const PrivacyScreen()),
              GoRoute(path: 'about', builder: (_, _) => const AboutScreen()),
            ]),
          ]),
          StatefulShellBranch(routes: [GoRoute(path: Routes.workspace, builder: (_, _) => const WorkspaceScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: Routes.live, builder: (_, _) => const DesktopLiveScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: Routes.batchDesktop, builder: (_, _) => const BatchScreen(embedded: true))]),
          StatefulShellBranch(routes: [GoRoute(path: Routes.keyDesktop, builder: (_, _) => const KeyScreen(embedded: true))]),
        ],
      ),
      full(Routes.onboarding, (_) => const OnboardingScreen()),
      full(Routes.auth, (_) => const AuthScreen()),
      full(Routes.scan, (_) => const LiveScanScreen()),
      full('/scan/zoom/:sid/:did', (s) => ZoomedSpecimenScreen(specimenId: p(s, 'sid'), detectionId: p(s, 'did')), fade: true),
      full('/capture/:sid', (s) => CaptureReviewScreen(specimenId: p(s, 'sid'))),
      full('/editor/:sid', (s) => ImageEditorScreen(specimenId: p(s, 'sid'))),
      full('/identify/:sid', (s) => IdentificationScreen(specimenId: p(s, 'sid'))),
      full('/analysis/:sid/:did', (s) => AnalysisScreen(specimenId: p(s, 'sid'), detectionId: p(s, 'did'))),
      full('/report/:id', (s) => ReportScreen(reportId: p(s, 'id'))),
      full('/report/:id/pdf', (s) => PdfPreviewScreen(reportId: p(s, 'id'))),
      full('/report/:id/full', (s) => FullReportScreen(reportId: p(s, 'id'))),
      full('/measure/:sid', (s) => MeasureScreen(specimenId: p(s, 'sid'), reportId: s.uri.queryParameters['report'])),
      full(Routes.calibrate, (_) => const CalibrationScreen()),
      full('/tools/key', (s) => KeyScreen(fromReport: s.uri.queryParameters['from'])),
      full(Routes.batch, (_) => const BatchScreen()),
      full(Routes.pairPhone, (_) => const PhonePairScreen()),
      full('/compare/:sid/:genus', (s) => CompareScreen(specimenId: p(s, 'sid'), genus: p(s, 'genus'))),
      full(Routes.import, (_) => const ImportScreen()),
      full(Routes.screenGallery, (_) => const ScreenGalleryScreen()),
      full(Routes.components, (_) => const ComponentSheetScreen()),
      full('/dev/preview/:id', (s) => PreviewScreen(id: p(s, 'id'))),
    ],
  );
}
