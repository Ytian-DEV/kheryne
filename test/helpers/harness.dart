import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kheryne/app.dart';
import 'package:kheryne/core/layout/form_factor.dart';
import 'package:kheryne/core/providers.dart';
import 'package:kheryne/core/widgets/async_view.dart';
import 'package:kheryne/features/settings/screen_gallery.dart' show Reader;

/// Fixed "now" for deterministic screenshots: Wednesday 21 October 2026.
final fixedNow = DateTime(2026, 10, 21, 9, 41);

const phoneSize = Size(390, 844);
const desktopSize = Size(1440, 900);

bool _fontsLoaded = false;

Future<void> loadAppFonts() async {
  if (_fontsLoaded) return;
  Future<void> load(String family, List<String> assets) async {
    final loader = FontLoader(family);
    for (final a in assets) {
      loader.addFont(rootBundle.load(a));
    }
    await loader.load();
  }

  await load('Inter', [
    'assets/fonts/Inter-Regular.ttf',
    'assets/fonts/Inter-Italic.ttf',
    'assets/fonts/Inter-Medium.ttf',
    'assets/fonts/Inter-MediumItalic.ttf',
    'assets/fonts/Inter-SemiBold.ttf',
    'assets/fonts/Inter-SemiBoldItalic.ttf',
  ]);
  await load('InterDisplay', ['assets/fonts/InterDisplay-SemiBold.ttf', 'assets/fonts/InterDisplay-SemiBoldItalic.ttf']);
  await load('Phosphor', ['assets/fonts/Phosphor.ttf']);
  _fontsLoaded = true;
}

/// Pumps the real app at [location] with deterministic overrides.
Future<void> pumpApp(
  WidgetTester tester,
  String location, {
  bool desktop = false,
  bool dark = false,
  ViewState? state,
  bool online = true,
  double textScale = 1,
  List<Override> overrides = const [],
  Future<void> Function(Reader read)? setup,
}) async {
  await loadAppFonts();
  final size = desktop ? desktopSize : phoneSize;
  final dpr = desktop ? 1.0 : 2.0;
  tester.view.physicalSize = size * dpr;
  tester.view.devicePixelRatio = dpr;
  tester.view.padding = desktop ? FakeViewPadding.zero : const FakeViewPadding(top: 48 * 2, bottom: 24 * 2);
  tester.view.viewPadding = tester.view.padding;
  tester.platformDispatcher.platformBrightnessTestValue = dark ? Brightness.dark : Brightness.light;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);

  final container = ProviderContainer(overrides: [
    clockProvider.overrideWithValue(() => fixedNow),
    latencyProvider.overrideWithValue(Duration.zero),
    formFactorProvider.overrideWith(() => FormFactorController(FormFactor(isDesktop: desktop))),
    ...overrides,
  ]);
  addTearDown(container.dispose);
  container.read(settingsProvider.notifier).update((s) => s.copyWith(onboarded: true));
  if (state != null) container.read(forcedViewStateProvider.notifier).set(state);
  if (!online) container.read(onlineProvider.notifier).set(false);
  if (setup != null) await setup(container.read);

  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: KheryneApp(initialLocation: location)));
  // Let futures resolve and one-shot animations finish without waiting on
  // repeating ones.
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}
