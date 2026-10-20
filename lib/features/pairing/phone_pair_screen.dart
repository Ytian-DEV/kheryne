import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/layout/scan_theme.dart';
import '../../core/providers.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../mock/specimens.dart';
import 'desktop_live_screen.dart' show laptopName;

enum PhonePairStep { scan, streaming }

/// Android counterpart: scan the code on the computer, then stream the
/// eyepiece view to it.
class PhonePairScreen extends ConsumerStatefulWidget {
  const PhonePairScreen({super.key, this.initial = PhonePairStep.scan});
  final PhonePairStep initial;

  @override
  ConsumerState<PhonePairScreen> createState() => _PhonePairScreenState();
}

class _PhonePairScreenState extends ConsumerState<PhonePairScreen> {
  late PhonePairStep _step = widget.initial;

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(clockProvider)();
    return ScanTheme(
      child: Builder(builder: (context) {
        final k = context.k;
        final t = context.t;
        final streaming = _step == PhonePairStep.streaming;
        return Scaffold(
          backgroundColor: k.canvas,
          appBar: KNavBar(title: streaming ? 'Streaming' : 'Pair with computer', onDark: true),
          body: Column(
            children: [
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: Opacity(
                        opacity: streaming ? 1 : 0.55,
                        child: Micrograph(specimen: makeSpecimen(83, capturedAt: now, nematodes: 2), fit: BoxFit.cover),
                      ),
                    ),
                    if (!streaming)
                      Semantics(
                        label: 'Viewfinder. Point it at the code on your computer',
                        child: Pressable(
                          onTap: () => setState(() => _step = PhonePairStep.streaming),
                          borderRadius: KRadius.heroAll,
                          child: Container(
                            width: 240,
                            height: 240,
                            decoration: BoxDecoration(
                              borderRadius: KRadius.heroAll,
                              border: Border.all(color: k.overlayText, width: 3),
                            ),
                          ),
                        ),
                      ),
                    if (streaming)
                      Positioned(
                        top: KSpace.s16,
                        left: KSpace.s16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: KSpace.s12, vertical: 6),
                          decoration: BoxDecoration(color: k.canvas.withValues(alpha: 0.7), borderRadius: KRadius.pill),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Container(width: 8, height: 8, decoration: BoxDecoration(color: k.error, shape: BoxShape.circle)),
                            const SizedBox(width: KSpace.s8),
                            Text('Live', style: t.captionStrong.copyWith(color: k.overlayText)),
                          ]),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(color: k.surface, borderRadius: KRadius.sheetTop),
                padding: EdgeInsets.fromLTRB(KSpace.s20, KSpace.s20, KSpace.s20, MediaQuery.paddingOf(context).bottom + KSpace.s16),
                child: streaming
                    ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Text('Streaming to $laptopName', style: t.headline),
                        const SizedBox(height: KSpace.s4),
                        Text('38 ms delay · Keep the phone on the eyepiece. Detection runs on the computer.', style: t.caption),
                        const SizedBox(height: KSpace.s16),
                        KButton(label: 'Stop streaming', expand: true, onPressed: () => Navigator.of(context).maybePop()),
                      ])
                    : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Text('Scan the code on your computer', style: t.headline),
                        const SizedBox(height: KSpace.s4),
                        Text('On the computer, open Kheryne → Live (phone). Both devices must be on the same Wi-Fi.', style: t.caption),
                        const SizedBox(height: KSpace.s16),
                        KButton.secondary(label: 'Enter code instead', expand: true, onPressed: () => showToast(context, 'Code entry is coming with the pairing service.')),
                      ]),
              ),
            ],
          ),
        );
      }),
    );
  }
}
