import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/router/routes.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../mock/specimens.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, this.initialPage = 0});
  final int initialPage;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late final _pc = PageController(initialPage: widget.initialPage);
  late int _page = widget.initialPage;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _finish() {
    ref.read(settingsProvider.notifier).update((s) => s.copyWith(onboarded: true));
    context.goTo(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final t = context.t;
    final now = ref.watch(clockProvider)();
    final settings = ref.watch(settingsProvider);
    final pages = [
      _Page(
        art: SizedBox(
          height: 240,
          child: ClipRRect(
            borderRadius: KRadius.heroAll,
            child: AspectRatio(
              aspectRatio: 1,
              child: LayoutBuilder(builder: (context, c) {
                final s = makeSpecimen(41, capturedAt: now, nematodes: 2, withDebrisBody: false);
                return Stack(children: [
                  Positioned.fill(child: Micrograph(specimen: s, fit: BoxFit.contain)),
                  for (final w in s.worms)
                    Positioned.fromRect(
                      rect: Rect.fromLTRB(w.bounds.left * c.maxWidth, w.bounds.top * c.maxHeight, w.bounds.right * c.maxWidth,
                          w.bounds.bottom * c.maxHeight),
                      child: DetectionBox(
                          detection: Detection(id: 'x', rect: w.bounds, kind: BoxKind.ai, confidence: 0.88), longLabel: false),
                    ),
                ]);
              }),
            ),
          ),
        ),
        title: 'Less time at the eyepiece',
        body: 'Kheryne finds likely plant-parasitic nematodes on your slide and identifies them from order to genus, with the traits it used.',
      ),
      const _Page(
        art: LineArtView(LineArt.phoneOnEyepiece, size: 200),
        title: 'Clip your phone to the eyepiece',
        body: 'Use a phone adapter, line the camera up with the eyepiece, and start at 10×. Switch to 40× when Kheryne asks for genus-level detail.',
      ),
      _Page(
        art: const LineArtView(LineArt.offlineModels, size: 200),
        title: 'Works without internet',
        body: 'The identification models are on this device (${settings.modelSizeMb} MB). Your photos and results stay here unless you export them.',
      ),
    ];
    final last = _page == pages.length - 1;
    return Scaffold(
      backgroundColor: k.background,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.all(KSpace.s8),
                child: AnimatedOpacity(
                  opacity: last ? 0 : 1,
                  duration: KMotion.of(context, KMotion.fast),
                  child: KButton.tertiary(label: 'Skip', onPressed: last ? null : _finish, size: KButtonSize.compact),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pc,
                onPageChanged: (p) => setState(() => _page = p),
                children: pages,
              ),
            ),
            Semantics(
              label: 'Page ${_page + 1} of ${pages.length}',
              excludeSemantics: true,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < pages.length; i++)
                    AnimatedContainer(
                      duration: KMotion.of(context, KMotion.base),
                      curve: KMotion.spring,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _page ? 20 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                          color: i == _page ? k.primary : k.textSecondary.withValues(alpha: 0.3), borderRadius: KRadius.pill),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(KSpace.s24, KSpace.s24, KSpace.s24, KSpace.s16),
              child: KButton(
                label: last ? 'Get started' : 'Next',
                expand: true,
                onPressed: () => last
                    ? _finish()
                    : _pc.nextPage(duration: KMotion.of(context, KMotion.slow), curve: KMotion.ease),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: KSpace.s8),
              child: Text('Kheryne supports identification. Confirm important results with a qualified nematologist.',
                  style: t.micro, textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({required this.art, required this.title, required this.body});
  final Widget art;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: KSpace.s32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          children: [
            const SizedBox(height: KSpace.s24),
            Center(child: art),
            const SizedBox(height: KSpace.s40),
            Text(title, style: t.title1, textAlign: TextAlign.center),
            const SizedBox(height: KSpace.s12),
            Text(body, style: t.callout.copyWith(color: context.k.textSecondary), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
