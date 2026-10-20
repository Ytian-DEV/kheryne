import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/layout/form_factor.dart';
import '../../core/layout/scan_theme.dart';
import '../../core/providers.dart';
import '../../core/router/routes.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import 'live_scan_screen.dart';

/// Shown after tapping a box in Live Scan: the candidate magnified, with
/// Identify nematode and Take photo.
class ZoomedSpecimenScreen extends ConsumerStatefulWidget {
  const ZoomedSpecimenScreen({super.key, required this.specimenId, required this.detectionId});
  final String specimenId;
  final String detectionId;

  @override
  ConsumerState<ZoomedSpecimenScreen> createState() => _ZoomedSpecimenScreenState();
}

class _ZoomedSpecimenScreenState extends ConsumerState<ZoomedSpecimenScreen> {
  final _canvas = GlobalKey<BoxCanvasState>();
  bool _framed = false;

  @override
  Widget build(BuildContext context) {
    final specimen = ref.watch(specimenProvider(widget.specimenId));
    final detections = ref.watch(liveDetectionsProvider(widget.specimenId));
    final ff = FormFactor.of(context);
    return ScanTheme(
      child: Builder(builder: (context) {
        final k = context.k;
        final t = context.t;
        final s = specimen.value;
        final d = detections.value?.where((d) => d.id == widget.detectionId).firstOrNull;
        if (s != null && d != null && !_framed) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final st = _canvas.currentState;
            if (st != null && mounted) {
              st.controller.value = st.matrixFor(d.rect, padding: 0.5);
              setState(() => _framed = true);
            }
          });
        }
        return Scaffold(
          backgroundColor: k.canvas,
          appBar: KNavBar(title: 'Candidate', subtitle: s == null ? null : 'Objective ${s.objective}×', onDark: true),
          body: s == null || d == null
              ? const Center(child: SkeletonBlock(width: 240, height: 240, radius: KRadius.hero))
              : Column(
                  children: [
                    Expanded(
                      child: BoxCanvas(
                        key: _canvas,
                        specimen: s,
                        detections: [d],
                        selectedId: d.id,
                        longLabels: true,
                        maxScale: 10,
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(color: k.surface, borderRadius: KRadius.sheetTop),
                      padding: EdgeInsets.fromLTRB(KSpace.s20, KSpace.s20, KSpace.s20, MediaQuery.paddingOf(context).bottom + KSpace.s16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text('Likely a nematode', style: t.headline)),
                              ConfidencePill(d.confidence ?? 0),
                            ],
                          ),
                          const SizedBox(height: KSpace.s4),
                          Text('Identify it now from this frame, or take a photo to review it later.', style: t.caption),
                          const SizedBox(height: KSpace.s16),
                          KButton(
                            label: 'Identify nematode',
                            icon: KIcons.scan,
                            expand: true,
                            onPressed: () => context.pushTo(Routes.analysis(s.id, d.id)),
                          ),
                          if (ff.canTakePhoto) ...[
                            const SizedBox(height: KSpace.s8),
                            KButton.secondary(
                              label: 'Take photo',
                              icon: KIcons.camera,
                              expand: true,
                              onPressed: () => context.pushTo(Routes.captureReview(s.id)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
        );
      }),
    );
  }
}
