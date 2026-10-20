import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/layout/form_factor.dart';
import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/router/routes.dart';
import '../../core/theme/theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import 'batch_controller.dart';

/// Pick several images, watch the queue, then review a summary and export.
class BatchScreen extends ConsumerWidget {
  const BatchScreen({super.key, this.embedded = false});

  /// Desktop sidebar branch (no back button).
  final bool embedded;

  Future<void> _pick(BuildContext context, WidgetRef ref, {bool folder = false}) async {
    final all = await ref.read(identificationRepositoryProvider).specimens();
    ref.read(batchProvider.notifier).add(folder ? all : all.take(6).toList());
  }

  void _export(BuildContext context, String format) => showToast(context, 'Exported batch as $format.');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(batchProvider);
    final desktop = FormFactor.of(context).isDesktop;
    final forced = ViewStateScope.of(context);
    final empty = st.isEmpty || forced == ViewState.empty;

    final actions = <Widget>[
      if (st.finished && forced != ViewState.empty) ...[
        if (desktop) ...[
          KButton.tertiary(label: 'CSV', icon: KIcons.csv, size: KButtonSize.compact, onPressed: () => _export(context, 'CSV')),
          KButton.tertiary(label: 'Excel', icon: KIcons.xls, size: KButtonSize.compact, onPressed: () => _export(context, 'Excel')),
          KButton.tertiary(label: 'PDF', icon: KIcons.pdf, size: KButtonSize.compact, onPressed: () => _export(context, 'PDF')),
        ] else
          KIconButton(icon: KIcons.export, label: 'Export results', onPressed: () => _exportSheet(context)),
      ],
    ];

    return LargeTitleScaffold(
      title: 'Batch analysis',
      showBack: !embedded,
      actions: actions,
      maxContentWidth: desktop ? null : 640,
      header: empty
          ? null
          : _Progress(st: st, onStart: () => ref.read(batchProvider.notifier).start(), onCancel: () => ref.read(batchProvider.notifier).cancel(),
              onAdd: () => _pick(context, ref), onClear: () => ref.read(batchProvider.notifier).clear(), desktop: desktop),
      slivers: [
        if (empty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: KSpace.s40),
              child: desktop
                  ? _DesktopEmpty(onFiles: () => _pick(context, ref), onFolder: () => _pick(context, ref, folder: true))
                  : EmptyState(
                      art: LineArt.slides,
                      message: 'Analyze several slides at once.',
                      detail: 'Kheryne finds the clearest nematode in each image and identifies it.',
                      action: 'Choose images',
                      onAction: () => _pick(context, ref),
                    ),
            ),
          )
        else if (desktop)
          SliverToBoxAdapter(child: BatchGrid(items: st.items))
        else ...[
          SliverList.separated(
            itemCount: st.items.length,
            separatorBuilder: (_, _) => const SizedBox(height: KSpace.s8),
            itemBuilder: (context, i) => _QueueRow(item: st.items[i]),
          ),
          if (st.finished) ...[
            const SliverToBoxAdapter(child: SizedBox(height: KSpace.s24)),
            SliverToBoxAdapter(child: _Summary(items: st.items)),
          ],
        ],
      ],
    );
  }

  void _exportSheet(BuildContext context) => showKBottomSheet<void>(
        context,
        title: 'Export results',
        initial: 0.4,
        detents: const [0.4],
        builder: (ctx, c) => ListView(
          controller: c,
          padding: const EdgeInsets.all(KSpace.s16),
          children: [
            KListSection(children: [
              KListRow(title: 'CSV spreadsheet', leading: KIcons.csv, onTap: () {
                Navigator.of(ctx).pop();
                _export(context, 'CSV');
              }),
              KListRow(title: 'PDF summary', leading: KIcons.pdf, onTap: () {
                Navigator.of(ctx).pop();
                _export(context, 'PDF');
              }),
            ]),
          ],
        ),
      );
}

class _Progress extends StatelessWidget {
  const _Progress({required this.st, required this.onStart, required this.onCancel, required this.onAdd, required this.onClear, required this.desktop});
  final BatchState st;
  final VoidCallback onStart;
  final VoidCallback onCancel;
  final VoidCallback onAdd;
  final VoidCallback onClear;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final k = context.k;
    final status = st.running
        ? 'Analyzing ${st.doneCount + 1} of ${st.items.length}'
        : st.finished
            ? 'Done · ${st.items.length} images'
            : '${st.items.length} images ready';
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(child: Semantics(liveRegion: true, child: Text(status, style: t.headline))),
            Text(percent(st.overall), style: t.calloutStrong.copyWith(fontFeatures: KType.tabular)),
          ]),
          const SizedBox(height: KSpace.s8),
          ClipRRect(borderRadius: KRadius.pill, child: LinearProgressIndicator(value: st.overall, minHeight: 6, color: k.accent)),
          const SizedBox(height: KSpace.s12),
          Row(children: [
            if (!st.running && !st.finished) ...[
              Expanded(child: KButton(label: 'Start analysis', icon: KIcons.scan, expand: true, onPressed: onStart, size: desktop ? KButtonSize.compact : KButtonSize.regular)),
              const SizedBox(width: KSpace.s8),
              KButton.secondary(label: 'Add images', onPressed: onAdd, size: desktop ? KButtonSize.compact : KButtonSize.regular),
            ] else if (st.running)
              Expanded(child: KButton.secondary(label: 'Cancel', expand: true, onPressed: onCancel, size: desktop ? KButtonSize.compact : KButtonSize.regular))
            else
              Expanded(child: KButton.secondary(label: 'New batch', expand: true, onPressed: onClear, size: desktop ? KButtonSize.compact : KButtonSize.regular)),
          ]),
        ],
      ),
    );
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({required this.item});
  final BatchItem item;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final t = context.t;
    final r = item.report;
    final (IconData icon, Color color, String label) = switch (item.status) {
      BatchStatus.queued => (KIcons.clock, k.textSecondary, 'Queued'),
      BatchStatus.running => (KIcons.scan, k.accent, 'Analyzing'),
      BatchStatus.done => (KIcons.checkCircle, k.success, 'Done'),
      BatchStatus.noNematode => (KIcons.info, k.textSecondary, 'No nematode found'),
      BatchStatus.failed => (KIcons.xCircle, k.error, 'Couldn’t analyze'),
    };
    return KCard(
      padding: const EdgeInsets.all(KSpace.s12),
      onTap: r == null ? null : () => context.pushTo(Routes.report(r.id)),
      semanticLabel: '${item.specimen.fileName}, $label${r != null ? ', ${r.genus} ${percent(r.classification.genus.confidence)}' : ''}',
      child: Row(
        children: [
          ClipRRect(borderRadius: KRadius.smAll, child: SizedBox.square(dimension: 52, child: Micrograph(specimen: item.specimen))),
          const SizedBox(width: KSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.specimen.fileName, style: t.subhead, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                if (r != null && item.status == BatchStatus.done)
                  Row(children: [
                    Flexible(child: GenusName(r.genus, style: t.calloutStrong, maxLines: 1)),
                    const SizedBox(width: KSpace.s8),
                    ConfidencePill(r.classification.genus.confidence, compact: true),
                  ])
                else
                  Row(children: [
                    Icon(icon, size: 14, color: color),
                    const SizedBox(width: KSpace.s4),
                    Text(label, style: t.caption),
                  ]),
                if (item.status == BatchStatus.running) ...[
                  const SizedBox(height: 6),
                  ClipRRect(borderRadius: KRadius.pill, child: LinearProgressIndicator(value: item.progress, minHeight: 3, color: k.accent)),
                ],
              ],
            ),
          ),
          if (item.status == BatchStatus.done) Icon(icon, color: color, size: KSize.icon),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.items});
  final List<BatchItem> items;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final done = items.where((i) => i.status == BatchStatus.done && i.report != null).toList();
    final counts = <String, int>{};
    for (final i in done) {
      counts[i.report!.genus] = (counts[i.report!.genus] ?? 0) + 1;
    }
    final uncertain = done.where((i) => i.report!.classification.isUncertain).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('SUMMARY', style: t.sectionHeader),
        const SizedBox(height: KSpace.s8),
        KListSection(
          footer: uncertain > 0 ? '$uncertain result${uncertain == 1 ? ' is' : 's are'} uncertain. Confirm with an expert.' : null,
          children: [
            for (final e in counts.entries)
              KListRow(title: e.key, titleWidget: GenusName(e.key, style: t.bodyStyle), value: '${e.value}'),
            KListRow(title: 'No nematode found', value: '${items.where((i) => i.status == BatchStatus.noNematode).length}'),
          ],
        ),
      ],
    );
  }
}

class _DesktopEmpty extends StatelessWidget {
  const _DesktopEmpty({required this.onFiles, required this.onFolder});
  final VoidCallback onFiles;
  final VoidCallback onFolder;

  @override
  Widget build(BuildContext context) => EmptyState(
        art: LineArt.slides,
        message: 'Import a folder of slide images.',
        detail: 'Kheryne analyzes each image and fills a table you can sort and export.',
        action: 'Choose folder',
        onAction: onFolder,
      );
}

enum _Col { file, genus, confidence, order, family, date }

/// Desktop data grid with sortable columns.
class BatchGrid extends ConsumerStatefulWidget {
  const BatchGrid({super.key, required this.items});
  final List<BatchItem> items;

  @override
  ConsumerState<BatchGrid> createState() => _BatchGridState();
}

class _BatchGridState extends ConsumerState<BatchGrid> {
  _Col _sort = _Col.file;
  bool _asc = true;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final t = context.t;
    final rows = [...widget.items];
    int cmp(BatchItem a, BatchItem b) {
      final ra = a.report, rb = b.report;
      final c = switch (_sort) {
        _Col.file => a.specimen.fileName.compareTo(b.specimen.fileName),
        _Col.genus => (ra?.genus ?? '~').compareTo(rb?.genus ?? '~'),
        _Col.confidence => (ra?.classification.genus.confidence ?? -1).compareTo(rb?.classification.genus.confidence ?? -1),
        _Col.order => (ra?.classification.order.name ?? '~').compareTo(rb?.classification.order.name ?? '~'),
        _Col.family => (ra?.classification.family.name ?? '~').compareTo(rb?.classification.family.name ?? '~'),
        _Col.date => a.specimen.capturedAt.compareTo(b.specimen.capturedAt),
      };
      return _asc ? c : -c;
    }

    rows.sort(cmp);
    const widths = {_Col.file: 3, _Col.genus: 3, _Col.confidence: 2, _Col.order: 2, _Col.family: 3, _Col.date: 2};
    const labels = {_Col.file: 'File', _Col.genus: 'Genus', _Col.confidence: 'Confidence', _Col.order: 'Order', _Col.family: 'Family', _Col.date: 'Captured'};

    Widget header(_Col c) => Expanded(
          flex: widths[c]!,
          child: Pressable(
            onTap: () => setState(() {
              if (_sort == c) {
                _asc = !_asc;
              } else {
                _sort = c;
                _asc = true;
              }
            }),
            semanticLabel: 'Sort by ${labels[c]}',
            borderRadius: KRadius.smAll,
            pressScale: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: KSpace.s8),
              child: Row(children: [
                Text(labels[c]!, style: t.captionStrong.copyWith(color: _sort == c ? k.text : k.textSecondary)),
                if (_sort == c) ...[
                  const SizedBox(width: KSpace.s4),
                  Icon(_asc ? KIcons.sortUp : KIcons.sortDown, size: 14, color: k.text),
                ],
              ]),
            ),
          ),
        );

    Widget cell(_Col c, Widget child) => Expanded(
        flex: widths[c]!, child: Padding(padding: const EdgeInsets.symmetric(horizontal: KSpace.s8), child: child));

    return KCard(
      padding: EdgeInsets.zero,
      clip: true,
      child: Column(
        children: [
          ColoredBox(
            color: k.background,
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: KSpace.s8), child: Row(children: [for (final c in _Col.values) header(c)])),
          ),
          for (final it in rows)
            Pressable(
              onTap: it.report == null ? null : () => context.pushTo(Routes.reportFull(it.report!.id)),
              semanticLabel: it.specimen.fileName,
              borderRadius: BorderRadius.zero,
              pressScale: 1,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: KSpace.s8, vertical: 10),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: k.separator, width: KSize.hairline))),
                child: Row(children: [
                  cell(_Col.file, Row(children: [
                    ClipRRect(borderRadius: BorderRadius.circular(6), child: SizedBox.square(dimension: 32, child: Micrograph(specimen: it.specimen))),
                    const SizedBox(width: KSpace.s8),
                    Expanded(child: Text(it.specimen.fileName, style: t.subhead.copyWith(fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ])),
                  cell(
                      _Col.genus,
                      it.report != null && it.status == BatchStatus.done
                          ? GenusName(it.report!.genus, style: t.subhead.copyWith(fontSize: 14))
                          : Text(switch (it.status) {
                              BatchStatus.queued => 'Queued',
                              BatchStatus.running => 'Analyzing…',
                              BatchStatus.noNematode => 'No nematode',
                              BatchStatus.failed => 'Failed',
                              BatchStatus.done => '—',
                            }, style: t.caption)),
                  cell(
                      _Col.confidence,
                      it.status == BatchStatus.running
                          ? ClipRRect(borderRadius: KRadius.pill, child: LinearProgressIndicator(value: it.progress, minHeight: 4, color: k.accent))
                          : it.report != null && it.status == BatchStatus.done
                              ? Align(alignment: Alignment.centerLeft, child: ConfidencePill(it.report!.classification.genus.confidence, compact: true))
                              : const SizedBox()),
                  cell(_Col.order, Text(it.status == BatchStatus.done ? displayOrder(ref, it.report?.classification.order.name ?? '', it.report?.classification.family.name ?? '') : '', style: t.caption)),
                  cell(_Col.family, Text(it.status == BatchStatus.done ? it.report?.classification.family.name ?? '' : '', style: t.caption)),
                  cell(_Col.date, Text(shortDate(it.specimen.capturedAt), style: t.caption.copyWith(fontFeatures: KType.tabular))),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

/// Mock specimens for gallery previews.
List<BatchItem> demoBatch(List<Specimen> specimens, List<Report> reports) => [
      for (var i = 0; i < specimens.length && i < 8; i++)
        BatchItem(
          specimen: specimens[i],
          status: i == 3 ? BatchStatus.noNematode : BatchStatus.done,
          progress: 1,
          report: i == 3 ? null : reports[i % reports.length],
        ),
    ];
