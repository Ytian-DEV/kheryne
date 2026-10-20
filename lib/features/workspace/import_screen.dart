import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/theme/theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import 'workspace_controller.dart';

/// Drag-and-drop zone, file and folder pickers, and recent files.
///
/// The drop zone is UI only in this pass; OS drag-and-drop plugs in with
/// the file-access layer (see README).
class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  bool _hover = false;

  Future<void> _import({required bool folder}) async {
    final all = await ref.read(identificationRepositoryProvider).specimens();
    ref.read(workspaceProvider.notifier).importAll(folder ? all : all.skip(8).take(2).toList());
    if (!mounted) return;
    showToast(context, folder ? 'Imported ${all.length} images from the folder.' : 'Imported 2 images.');
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final t = context.t;
    final recent = ref.watch(specimensProvider);
    final now = ref.watch(clockProvider)();
    return Scaffold(
      appBar: const KNavBar(title: 'Import images'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(KSpace.s32, KSpace.s16, KSpace.s32, KSpace.s40),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MouseRegion(
                    onEnter: (_) => setState(() => _hover = true),
                    onExit: (_) => setState(() => _hover = false),
                    child: CustomPaint(
                      painter: _DashedBorder(color: _hover ? k.primary : k.textSecondary.withValues(alpha: 0.5)),
                      child: AnimatedContainer(
                        duration: KMotion.of(context, KMotion.fast),
                        height: 260,
                        decoration: BoxDecoration(color: _hover ? k.container.withValues(alpha: 0.5) : k.surface, borderRadius: KRadius.heroAll),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(KIcons.fileUp, size: 40, color: _hover ? k.primary : k.textSecondary),
                            const SizedBox(height: KSpace.s12),
                            Text('Drop micrographs or a folder here', style: t.title2),
                            const SizedBox(height: KSpace.s4),
                            Text('JPEG, PNG or TIFF · up to 50 MB each', style: t.caption),
                            const SizedBox(height: KSpace.s20),
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              KButton(label: 'Choose files', icon: KIcons.images, onPressed: () => _import(folder: false)),
                              const SizedBox(width: KSpace.s12),
                              KButton.secondary(label: 'Choose folder', icon: KIcons.folder, onPressed: () => _import(folder: true)),
                            ]),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: KSpace.s32),
                  AsyncView<List<Specimen>>(
                    value: recent,
                    loading: const SkeletonBlock(height: 240, radius: KRadius.card),
                    isEmpty: (l) => l.isEmpty,
                    empty: Text('No recent files.', style: t.caption),
                    data: (list) => KListSection(
                      header: 'RECENT FILES',
                      children: [
                        for (final s in list.take(6))
                          KListRow(
                            title: s.fileName,
                            subtitle: '${s.objective}× objective · ${relative(s.capturedAt, now)}',
                            leading: KIcons.image,
                            onTap: () {
                              ref.read(workspaceProvider.notifier).importAll([s]);
                              Navigator.of(context).maybePop();
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  _DashedBorder({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(KRadius.hero)));
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 12) {
        canvas.drawPath(m.extractPath(d, d + 7), p);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color;
}
