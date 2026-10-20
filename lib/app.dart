import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/layout/form_factor.dart';
import 'core/providers.dart';
import 'core/router/router.dart';
import 'core/theme/theme.dart';
import 'core/widgets/async_view.dart';

class KheryneApp extends ConsumerStatefulWidget {
  const KheryneApp({super.key, this.initialLocation});

  /// Overrides the start route (screen gallery flag, tests).
  final String? initialLocation;

  @override
  ConsumerState<KheryneApp> createState() => _KheryneAppState();
}

class _KheryneAppState extends ConsumerState<KheryneApp> {
  late final GoRouter _router = buildRouter(
    formFactor: ref.read(formFactorProvider),
    initialLocation: widget.initialLocation,
    onboarded: () => ref.read(settingsProvider).onboarded,
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(settingsProvider.select((s) => s.themeMode));
    final ff = ref.watch(formFactorProvider);
    final forced = ref.watch(forcedViewStateProvider);
    return FormFactorScope(
      value: ff,
      child: MaterialApp.router(
        title: 'Kheryne',
        debugShowCheckedModeBanner: false,
        theme: KheryneTheme.light(),
        darkTheme: KheryneTheme.dark(),
        themeMode: mode,
        routerConfig: _router,
        builder: (context, child) {
          // Cap text scaling at 130% so layouts stay intact.
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(textScaler: mq.textScaler.clamp(maxScaleFactor: 1.3)),
            child: FormFactorScope(
              value: ff,
              child: forced == null ? child! : ViewStateScope(state: forced, child: child!),
            ),
          );
        },
      ),
    );
  }
}
