import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/router/routes.dart';

/// `--dart-define=GALLERY=true` opens the hidden Screen Gallery at launch.
const _gallery = bool.fromEnvironment('GALLERY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      title: 'Kheryne',
      minimumSize: Size(1024, 700),
      size: Size(1440, 900),
      center: true,
      titleBarStyle: TitleBarStyle.normal,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(const ProviderScope(child: KheryneApp(initialLocation: _gallery ? Routes.screenGallery : null)));
}
