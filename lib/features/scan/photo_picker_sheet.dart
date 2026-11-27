import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/theme/theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';

const _micrographTypeGroup = XTypeGroup(
  label: 'Microscope images',
  extensions: ['jpg', 'jpeg', 'png', 'webp', 'tif', 'tiff'],
);

/// Photo picker sheet: lets the user pick a real microscope image file from
/// their device OR select a saved/sample slide already on the device.
Future<Specimen?> pickPhoto(BuildContext context, {String title = 'Choose a photo'}) {
  return showKBottomSheet<Specimen>(
    context,
    title: title,
    initial: 0.72,
    detents: const [0.72, 0.95],
    builder: (ctx, controller) => _PickerGrid(controller: controller),
  );
}

class _PickerGrid extends ConsumerStatefulWidget {
  const _PickerGrid({required this.controller});
  final ScrollController controller;

  @override
  ConsumerState<_PickerGrid> createState() => _PickerGridState();
}

class _PickerGridState extends ConsumerState<_PickerGrid> {
  bool _importing = false;

  Future<void> _pickFromDevice() async {
    final hybrid = ref.read(hybridRepositoryProvider);
    setState(() => _importing = true);
    try {
      final file = await openFile(acceptedTypeGroups: const [_micrographTypeGroup]);
      if (file == null) {
        if (mounted) setState(() => _importing = false);
        return;
      }
      final bytes = await file.readAsBytes();
      if (hybrid != null) {
        final imported = await hybrid.importImageBytes(
          fileName: file.name,
          bytes: bytes,
        );
        ref.invalidate(specimensProvider);
        if (mounted) Navigator.of(context).pop(imported);
      } else {
        final list = await ref.read(identificationRepositoryProvider).specimens();
        if (mounted) Navigator.of(context).pop(list.isEmpty ? null : list.first);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _importing = false);
        showToast(context, 'Could not open that image file.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final specimens = ref.watch(specimensProvider);
    final now = ref.watch(clockProvider)();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(KSpace.s16, KSpace.s4, KSpace.s16, KSpace.s8),
          child: KButton(
            label: 'Browse device files',
            icon: KIcons.upload,
            expand: true,
            loading: _importing,
            onPressed: _importing ? null : _pickFromDevice,
          ),
        ),
        Expanded(
          child: AsyncView(
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
              controller: widget.controller,
              padding: const EdgeInsets.fromLTRB(KSpace.s16, KSpace.s8, KSpace.s16, KSpace.s32),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 140,
                mainAxisSpacing: KSpace.s8,
                crossAxisSpacing: KSpace.s8,
                childAspectRatio: 0.82,
              ),
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
          ),
        ),
      ],
    );
  }
}
