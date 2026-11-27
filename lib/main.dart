import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/data/local_cache_store.dart';
import 'core/providers.dart';
import 'core/router/routes.dart';

/// `--dart-define=GALLERY=true` opens the hidden Screen Gallery at launch.
const _gallery = bool.fromEnvironment('GALLERY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final localCache = LocalCacheStore();
  await localCache.init();

  try {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabasePublishableKey,
    );
    AppConfig.supabaseReady = true;
  } catch (_) {
    AppConfig.supabaseReady = false;
  }

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

  runApp(
    ProviderScope(
      overrides: [
        localCacheProvider.overrideWithValue(localCache),
      ],
      child: const KheryneApp(initialLocation: _gallery ? Routes.screenGallery : null),
    ),
  );
}
