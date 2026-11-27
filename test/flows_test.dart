import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kheryne/core/models/models.dart';
import 'package:kheryne/core/widgets/widgets.dart';
import 'package:kheryne/mock/genera.dart';

import 'helpers/harness.dart';

Future<void> settle(WidgetTester tester, [int frames = 10]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('box flow: pink → check → green → analyze → report', (tester) async {
    await pumpApp(tester, '/identify/sp-39');

    // Two pink candidates are plotted.
    final boxes = tester.widgetList<DetectionBox>(find.byType(DetectionBox)).toList();
    expect(boxes.where((b) => b.detection.kind == BoxKind.ai), hasLength(2));
    expect(find.text('2 detected'), findsOneWidget);

    // Analyze is disabled until a box is confirmed.
    expect(find.text('Analyze nematode'), findsOneWidget);

    // Tap the first candidate → popover → Check if nematode.
    await tester.tapAt(tester.getCenter(find.byType(DetectionBox).first));
    await settle(tester);
    expect(find.text('Check if nematode'), findsOneWidget);
    await tester.tap(find.text('Check if nematode'));
    await settle(tester);

    final confirmed = tester.widgetList<DetectionBox>(find.byType(DetectionBox)).where((b) => b.detection.kind == BoxKind.confirmed);
    expect(confirmed, hasLength(1), reason: 'checked candidate turns green');

    // Tap the green box → Analyze nematode → report.
    await tester.tapAt(tester.getCenter(find.byWidget(confirmed.first)));
    await settle(tester);
    await tester.tap(find.text('Analyze nematode').first);
    await settle(tester, 30);
    expect(find.textContaining('CLASSIFICATION'), findsOneWidget);
    expect(find.textContaining('Kheryne supports identification'), findsWidgets);
  });

  testWidgets('drawing a purple box in draw mode', (tester) async {
    await pumpApp(tester, '/identify/sp-39');
    await tester.tap(find.text('Draw box'));
    await settle(tester);
    final canvas = tester.getRect(find.byType(BoxCanvas));
    final start = canvas.topLeft + Offset(canvas.width * 0.12, canvas.height * 0.15);
    final g = await tester.startGesture(start);
    await g.moveBy(const Offset(40, 30));
    await g.moveBy(const Offset(40, 30));
    await g.up();
    await settle(tester);
    final user = tester.widgetList<DetectionBox>(find.byType(DetectionBox)).where((b) => b.detection.kind == BoxKind.user);
    expect(user, hasLength(1));
    expect(find.textContaining('1 marked by you'), findsOneWidget);
  });

  testWidgets('a box far from any body is rejected with an X and label', (tester) async {
    await pumpApp(tester, '/identify/sp-39');
    await tester.tap(find.text('Draw box'));
    await settle(tester);
    final canvas = tester.getRect(find.byType(BoxCanvas));
    final g = await tester.startGesture(canvas.topLeft + Offset(canvas.width * 0.12, canvas.height * 0.12));
    await g.moveBy(const Offset(30, 30));
    await g.moveBy(const Offset(10, 10));
    await g.up();
    await settle(tester);
    await tester.tap(find.text('Check if nematode'));
    await settle(tester);
    expect(find.text('Not a nematode'), findsOneWidget);
    expect(find.byIcon(KIcons.close), findsWidgets);
  });

  testWidgets('Android back returns from a pushed screen', (tester) async {
    await pumpApp(tester, '/home');
    await tester.tap(find.text('Upload photo'));
    await settle(tester);
    expect(find.text('Choose a photo'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.text('Choose a photo'), findsNothing);
    expect(find.text('Start live scan'), findsWidgets);
  });

  testWidgets('Windows: Ctrl+O opens Import', (tester) async {
    await pumpApp(tester, '/workspace', desktop: true);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyO);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester);
    expect(find.text('Drop micrographs or a folder here'), findsOneWidget);
  });

  testWidgets('Windows: + zooms the workspace canvas', (tester) async {
    await pumpApp(tester, '/workspace', desktop: true);
    expect(find.text('100%'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.equal);
    await settle(tester);
    expect(find.text('125%'), findsOneWidget);
  });

  testWidgets('genus names render in italics everywhere', (tester) async {
    final genera = {for (final g in philippineGenera) g.name};
    var checked = 0;
    for (final route in [
      '/home',
      '/report/r-100',
      '/history',
      '/gallery',
      '/gallery/genus/Pratylenchus',
      '/tools/key?from=r-100',
      '/tools/training',
      '/report/r-100/pdf',
    ]) {
      await pumpApp(tester, route);
      for (final rt in tester.widgetList<RichText>(find.byType(RichText))) {
        void visit(InlineSpan span, TextStyle inherited) {
          if (span is! TextSpan) return;
          final style = inherited.merge(span.style);
          final text = span.text ?? '';
          for (final g in genera) {
            // Family names (Pratylenchidae) contain the genus stem; match whole words only.
            if (RegExp(r'\b' '$g' r'\b').hasMatch(text)) {
              checked++;
              expect(style.fontStyle, FontStyle.italic, reason: '"$text" on $route');
            }
          }
          for (final c in span.children ?? const <InlineSpan>[]) {
            visit(c, style);
          }
        }

        visit(rt.text, const TextStyle());
      }
    }
    expect(checked, greaterThan(20), reason: 'the check must actually see genus names');
  });

  testWidgets('text scaling to 130% does not overflow key screens', (tester) async {
    for (final route in ['/home', '/report/r-107', '/history', '/settings', '/tools/key', '/tools/training', '/auth']) {
      await pumpApp(tester, route, textScale: 1.3);
      expect(tester.takeException(), isNull, reason: route);
    }
  });

  testWidgets('lab dataset & review queue switches between curation, review queue, and stats', (tester) async {
    await pumpApp(tester, '/tools/training');
    expect(find.text('Select a microscope slide image'), findsOneWidget);

    await tester.tap(find.text('My submissions'));
    await settle(tester);
    expect(find.textContaining('submitted any slides yet'), findsOneWidget);

    await tester.tap(find.text('Dataset stats'));
    await settle(tester);
    expect(find.text('TRAINING PIPELINE SUMMARY'), findsOneWidget);
    expect(find.text('Export YOLO + Classifier Dataset'), findsOneWidget);
  });

  testWidgets('auth screen switches between sign in and create account and supports offline mode', (tester) async {
    await pumpApp(tester, '/auth');
    expect(find.text('Sync across phone and lab computer'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);

    await tester.tap(find.text('Create account').first);
    await settle(tester);
    expect(find.text('Full name (shown on reports)'), findsOneWidget);

    await tester.tap(find.text('Use offline'));
    await settle(tester);
    expect(find.text('Start live scan'), findsWidgets);
  });
}
