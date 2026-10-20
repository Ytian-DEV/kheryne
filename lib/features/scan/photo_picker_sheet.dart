import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/theme/theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';

/// Mock system photo picker: shows micrographs "on the device". The real
/// app opens the OS picker here.
Future<Specimen?> pickPhoto(BuildContext context, {String title = 'Choose a photo'}) {
  return showKBottomSheet<Specimen>(
    context,
    title: title,
    initial: 0.7,
    detents: const [0.7, 0.95],
    builder: (ctx, controller) => _PickerGrid(controller: controller),
  );
}

class _PickerGrid extends ConsumerWidget {
  const _PickerGrid({required this.controller});
  final ScrollController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final specimens = ref.watch(specimensProvider);
    final now = ref.watch(clockProvider)();
    return AsyncView(
      value: specimens,
      loading: GridView.count(
        crossAxisCount: 3,
        padding: const EdgeInsets.all(KSpace.s16),
        mainAxisSpacing: KSpace.s8,
        crossAxisSpacing: KSpace.s8,
        children: List.generate(9, (_) => const SkeletonBlock(height: double.infinity)),
      ),
      isEmpty: (l) => l.isEmpty,
      empty: const EmptyState(art: LineArt.camera, message: 'No photos on this device yet.'),
      data: (list) => GridView.builder(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(KSpace.s16, KSpace.s8, KSpace.s16, KSpace.s32),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 140, mainAxisSpacing: KSpace.s8, crossAxisSpacing: KSpace.s8, childAspectRatio: 0.82),
        itemCount: list.length,
        itemBuilder: (context, i) {
          final s = list[i];
          return Pressable(
            onTap: () => Navigator.of(context).pop(s),
            semanticLabel: '${s.fileName}, ${relative(s.capturedAt, now)}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(borderRadius: KRadius.smAll, child: Micrograph(specimen: s)),
                ),
                const SizedBox(height: KSpace.s4),
                Text(s.fileName, style: context.t.micro, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          );
        },
      ),
    );
  }
}
