// Renders every screen in the screen gallery to docs/screenshots.
//
//   flutter test test/screenshots_test.dart --update-goldens
//
// Phone 390×844 (@2x) and desktop 1440×900, light and dark. Non-content
// states (loading, empty, error, offline) are rendered in light.
@Tags(['screenshots'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kheryne/core/widgets/async_view.dart';
import 'package:kheryne/features/settings/screen_gallery.dart';

import 'helpers/harness.dart';

void main() {
  for (final desktop in [false, true]) {
    final platform = desktop ? 'desktop' : 'phone';
    for (final e in galleryEntries.where((e) => e.supports(desktop))) {
      for (final dark in [false, true]) {
        final theme = dark ? 'dark' : 'light';
        testWidgets('$platform ${e.id} $theme', (tester) async {
          await pumpApp(tester, e.route, desktop: desktop, dark: dark, setup: e.setup);
          await expectLater(find.byType(MaterialApp), matchesGoldenFile('../docs/screenshots/$platform/${e.id}_$theme.png'));
        });
      }
      for (final s in e.states.where((s) => s != ViewState.content)) {
        testWidgets('$platform ${e.id} ${s.name}', (tester) async {
          await pumpApp(tester, e.route,
              desktop: desktop, state: s == ViewState.offline ? null : s, online: s != ViewState.offline, setup: e.setup);
          await expectLater(find.byType(MaterialApp), matchesGoldenFile('../docs/screenshots/$platform/states/${e.id}_${s.name}.png'));
        });
      }
    }
  }
}
