import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/router/routes.dart';
import '../../core/theme/theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import 'report_parts.dart';

/// Identification report (phone). Also the body of History Detail.
class ReportScreen extends ConsumerWidget {
  const ReportScreen({super.key, required this.reportId, this.fromHistory = false});
  final String reportId;
  final bool fromHistory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(reportProvider(reportId));
    return LargeTitleScaffold(
      title: fromHistory ? 'Identification' : 'Report',
      largeTitle: false,
      actions: [
        KIconButton(
          icon: KIcons.share,
          label: 'Share report',
          onPressed: report.value == null ? null : () => context.pushTo(Routes.reportPdf(reportId)),
        ),
      ],
      slivers: [
        SliverToBoxAdapter(
          child: AsyncView<Report?>(
            value: report,
            onRetry: () => ref.invalidate(reportProvider(reportId)),
            loading: const ReportSkeleton(),
            isEmpty: (r) => r == null,
            empty: const EmptyState(
                art: LineArt.noResults, message: 'This report isn’t on the device anymore.', detail: 'It may have been deleted from History.'),
            data: (r) => ReportBody(report: r!, showNotes: fromHistory),
          ),
        ),
      ],
    );
  }
}

class ReportBody extends ConsumerWidget {
  const ReportBody({super.key, required this.report, this.showNotes = false});
  final Report report;
  final bool showNotes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final history = ref.watch(historyProvider).value ?? const [];
    final saved = history.any((r) => r.id == report.id);
    final now = ref.watch(clockProvider)();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const OfflineNotice(),
        RegionHeader(report: report),
        const SizedBox(height: KSpace.s20),
        ReportHeadline(report: report),
        if (report.classification.isUncertain) ...[
          const SizedBox(height: KSpace.s16),
          UncertainCard(onOpenKey: () => context.pushTo(Routes.key(fromReport: report.id))),
        ],
        const SizedBox(height: KSpace.s24),
        Text('CLASSIFICATION', style: t.sectionHeader),
        const SizedBox(height: KSpace.s8),
        LadderFor(report: report),
        const SizedBox(height: KSpace.s24),
        Text('TRAITS FOUND', style: t.sectionHeader),
        const SizedBox(height: KSpace.s8),
        TraitsList(report: report),
        if (report.morphometrics != null) ...[
          const SizedBox(height: KSpace.s24),
          Text('MEASUREMENTS', style: t.sectionHeader),
          const SizedBox(height: KSpace.s8),
          MorphometricsTable(m: report.morphometrics!),
        ],
        const SizedBox(height: KSpace.s24),
        _Actions(report: report, saved: saved),
        const SizedBox(height: KSpace.s24),
        KListSection(header: 'SPECIMEN', children: [
          KListRow(title: 'Image', value: report.specimen.fileName),
          KListRow(title: 'Objective', value: '${report.specimen.objective}×'),
          KListRow(title: 'Identified', value: '${relative(report.createdAt, now)} · ${timeOnly(report.createdAt)}'),
          if (report.crop != null && report.crop!.isNotEmpty) KListRow(title: 'Crop', value: report.crop),
          if (report.sampleCode != null && report.sampleCode!.isNotEmpty) KListRow(title: 'Sample', value: report.sampleCode),
        ]),
        const SizedBox(height: KSpace.s24),
        _SampleMetadataEditor(report: report),
        const SizedBox(height: KSpace.s20),
        Text(disclaimer, style: t.caption, textAlign: TextAlign.center),
      ],
    );
  }
}

class _Actions extends ConsumerWidget {
  const _Actions({required this.report, required this.saved});
  final Report report;
  final bool saved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = context.k;
    final t = context.t;
    Widget tile(IconData icon, String label, VoidCallback? onTap) => Expanded(
          child: KCard(
            onTap: onTap,
            semanticLabel: label,
            border: false,
            padding: const EdgeInsets.symmetric(vertical: KSpace.s12, horizontal: KSpace.s4),
            child: Column(children: [
              Icon(icon, color: onTap == null ? k.textSecondary : k.primary, size: KSize.iconLg - 2),
              const SizedBox(height: 6),
              Text(label, style: t.micro.copyWith(color: k.text, fontSize: 12), textAlign: TextAlign.center, maxLines: 2),
            ]),
          ),
        );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        tile(saved ? KIcons.check : KIcons.save, saved ? 'Saved' : 'Save to history', saved
            ? null
            : () async {
                await ref.read(identificationRepositoryProvider).save(report);
                ref.invalidate(historyProvider);
                if (context.mounted) showToast(context, 'Saved to History.');
              }),
        const SizedBox(width: KSpace.s8),
        tile(KIcons.pdf, 'Export PDF', () => context.pushTo(Routes.reportPdf(report.id))),
        const SizedBox(width: KSpace.s8),
        tile(KIcons.key, 'Open in key', () => context.pushTo(Routes.key(fromReport: report.id))),
        const SizedBox(width: KSpace.s8),
        tile(KIcons.ruler, 'Measure', () => context.pushTo(Routes.measure(report.specimen.id, reportId: report.id))),
      ],
    );
  }
}

class _SampleMetadataEditor extends ConsumerStatefulWidget {
  const _SampleMetadataEditor({required this.report});
  final Report report;

  @override
  ConsumerState<_SampleMetadataEditor> createState() => _SampleMetadataEditorState();
}

class _SampleMetadataEditorState extends ConsumerState<_SampleMetadataEditor> {
  late final _crop = TextEditingController(text: widget.report.crop ?? '');
  late final _code = TextEditingController(text: widget.report.sampleCode ?? '');
  late final _notes = TextEditingController(text: widget.report.notes);
  bool _saving = false;
  bool _dirty = false;

  @override
  void dispose() {
    _crop.dispose();
    _code.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _saveDetails() async {
    setState(() => _saving = true);
    final updated = widget.report.copyWith(
      crop: _crop.text.trim().isEmpty ? null : _crop.text.trim(),
      sampleCode: _code.text.trim().isEmpty ? null : _code.text.trim(),
      notes: _notes.text.trim(),
    );
    ref.read(pendingReportsProvider.notifier).put(updated);
    await ref.read(identificationRepositoryProvider).save(updated);
    ref.invalidate(historyProvider);
    ref.invalidate(reportProvider(updated.id));
    if (!mounted) return;
    setState(() {
      _saving = false;
      _dirty = false;
    });
    showToast(context, 'Saved sample details and notes.');
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('SAMPLE DETAILS & NOTES', style: context.t.sectionHeader),
          const SizedBox(height: KSpace.s8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _crop,
                  onChanged: (_) => setState(() => _dirty = true),
                  decoration: const InputDecoration(
                    labelText: 'Host crop (e.g. Banana, Rice)',
                    prefixIcon: Icon(KIcons.plant, size: KSize.icon),
                  ),
                ),
              ),
              const SizedBox(width: KSpace.s12),
              Expanded(
                child: TextField(
                  controller: _code,
                  onChanged: (_) => setState(() => _dirty = true),
                  decoration: const InputDecoration(
                    labelText: 'Sample code',
                    prefixIcon: Icon(KIcons.flask, size: KSize.icon),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: KSpace.s12),
          TextField(
            controller: _notes,
            minLines: 3,
            maxLines: 6,
            onChanged: (_) => setState(() => _dirty = true),
            decoration: const InputDecoration(hintText: 'Add notes about the sample, site or slide'),
          ),
          if (_dirty) ...[
            const SizedBox(height: KSpace.s12),
            KButton.secondary(
              label: 'Save sample details',
              icon: KIcons.save,
              expand: true,
              loading: _saving,
              onPressed: _saving ? null : _saveDetails,
            ),
          ],
        ],
      );
}

/// Skeleton matching the report layout.
class ReportSkeleton extends StatelessWidget {
  const ReportSkeleton({super.key});

  @override
  Widget build(BuildContext context) => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBlock(height: 256, radius: KRadius.sheet),
          SizedBox(height: KSpace.s20),
          SkeletonBlock(width: 240, height: 30),
          SizedBox(height: KSpace.s8),
          SkeletonBlock(width: 64, height: 22, radius: KRadius.full),
          SizedBox(height: KSpace.s8),
          SkeletonBlock(height: 16),
          SizedBox(height: KSpace.s4),
          SkeletonBlock(width: 200, height: 16),
          SizedBox(height: KSpace.s24),
          SkeletonBlock(height: 200, radius: KRadius.card),
          SizedBox(height: KSpace.s24),
          SkeletonBlock(height: 150, radius: KRadius.card),
        ],
      );
}
