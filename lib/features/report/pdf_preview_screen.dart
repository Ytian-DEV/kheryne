import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/layout/form_factor.dart';
import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/theme/theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import 'report_parts.dart';

/// A4 PDF preview. The page is always rendered light, like paper.
class PdfPreviewScreen extends ConsumerStatefulWidget {
  const PdfPreviewScreen({super.key, required this.reportId});
  final String reportId;

  @override
  ConsumerState<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends ConsumerState<PdfPreviewScreen> {
  late final _name = TextEditingController(text: ref.read(settingsProvider).userName);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final report = ref.watch(reportProvider(widget.reportId));
    final desktop = FormFactor.of(context).isDesktop;
    return Scaffold(
      appBar: KNavBar(title: 'Export PDF', subtitle: 'A4 · 1 page', actions: [
        if (desktop)
          Padding(
            padding: const EdgeInsets.only(right: KSpace.s8),
            child: KButton.secondary(
                label: 'Save', icon: KIcons.download, size: KButtonSize.compact, onPressed: () => showToast(context, 'Saved to Documents › Kheryne.')),
          ),
      ]),
      body: AsyncView<Report?>(
        value: report,
        loading: const Center(child: SkeletonBlock(width: 300, height: 424, radius: KRadius.sm)),
        isEmpty: (r) => r == null,
        empty: const EmptyState(art: LineArt.noResults, message: 'This report isn’t on the device anymore.'),
        data: (r) => ListView(
          padding: const EdgeInsets.fromLTRB(KSpace.s16, KSpace.s8, KSpace.s16, KSpace.s24),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _name,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(labelText: 'Name on report', prefixIcon: Icon(KIcons.pencil, size: KSize.icon)),
                    ),
                    const SizedBox(height: KSpace.s16),
                    Theme(data: KheryneTheme.light(), child: A4Page(report: r!, name: _name.text)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: desktop
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(KSpace.s16, KSpace.s8, KSpace.s16, KSpace.s12),
                child: Row(children: [
                  Expanded(
                      child: KButton.secondary(
                          label: 'Save', icon: KIcons.download, expand: true, onPressed: () => showToast(context, 'Saved to Downloads.'))),
                  const SizedBox(width: KSpace.s12),
                  Expanded(
                      child: KButton(
                          label: 'Share', icon: KIcons.share, expand: true, onPressed: () => showToast(context, 'Opening share sheet…'))),
                ]),
              ),
            ),
    );
  }
}

/// The printable page. Used by PDF preview and the desktop full report.
class A4Page extends StatelessWidget {
  const A4Page({super.key, required this.report, required this.name});
  final Report report;
  final String name;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final t = context.t;
    final c = report.classification;
    TextStyle s(TextStyle x) => x.copyWith(fontSize: (x.fontSize ?? 14) * 0.62, height: 1.3);
    return AspectRatio(
      aspectRatio: 1 / 1.4142,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: k.surface,
          borderRadius: BorderRadius.circular(2),
          boxShadow: [BoxShadow(color: k.canvas.withValues(alpha: 0.18), blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 420,
            height: 594,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 26, 28, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: k.primary, width: 1.6)),
                    ),
                    const SizedBox(width: 6),
                    Text('Kheryne', style: s(t.headline).copyWith(color: k.primary)),
                    const Spacer(),
                    Text('Identification report', style: s(t.caption)),
                  ]),
                  const SizedBox(height: 6),
                  Divider(height: 1, color: k.separator),
                  const SizedBox(height: 12),
                  SizedBox(height: 120, width: double.infinity, child: ClipRRect(borderRadius: BorderRadius.circular(4), child: SpecimenPortrait(genus: report.genus, seed: report.specimen.seed))),
                  const SizedBox(height: 12),
                  Text.rich(TextSpan(style: s(t.title2), children: [
                    TextSpan(text: c.isUncertain ? 'Possibly ' : 'Likely '),
                    genusSpan(c.genus.name),
                    TextSpan(text: ' (${percent(c.genus.confidence)})'),
                  ])),
                  if (c.isUncertain)
                    Text('Uncertain — confirm with an expert.', style: s(t.calloutStrong).copyWith(color: k.warning)),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Classification', style: s(t.sectionHeader)),
                          const SizedBox(height: 3),
                          for (final r in c.ladder)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Row(children: [
                                SizedBox(width: 38, child: Text(r.rank.label, style: s(t.caption))),
                                Expanded(
                                    child: Text(r.name,
                                        style: s(t.subhead).copyWith(fontStyle: r.rank == Rank.genus ? FontStyle.italic : null))),
                                Text(percent(r.confidence), style: s(t.subhead).copyWith(fontFeatures: KType.tabular)),
                              ]),
                            ),
                          const SizedBox(height: 8),
                          Text('Traits', style: s(t.sectionHeader)),
                          const SizedBox(height: 3),
                          for (final tr in report.traits)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text('${tr.name}: ${tr.value}', style: s(t.callout)),
                            ),
                        ]),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 130,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Measurements', style: s(t.sectionHeader)),
                          const SizedBox(height: 3),
                          if (report.morphometrics == null)
                            Text('Not measured', style: s(t.caption))
                          else
                            for (final (a, b) in [
                              ('L', um(report.morphometrics!.bodyLength)),
                              ('a', ratio(report.morphometrics!.a)),
                              ('b', ratio(report.morphometrics!.b)),
                              ('c', ratio(report.morphometrics!.c)),
                              ('V', '${report.morphometrics!.vPercent.toStringAsFixed(0)}%'),
                              ('Stylet', um(report.morphometrics!.styletLength)),
                            ])
                              Row(children: [
                                Expanded(child: Text(a, style: s(t.caption))),
                                Text(b, style: s(t.subhead).copyWith(fontFeatures: KType.tabular)),
                              ]),
                        ]),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Divider(height: 1, color: k.separator),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(child: Text('Identified by: ${name.isEmpty ? '________________' : name}', style: s(t.callout))),
                    Text(dateTime(report.createdAt), style: s(t.caption)),
                  ]),
                  const SizedBox(height: 2),
                  Text('Image ${report.specimen.fileName} · ${report.specimen.objective}× objective${report.crop != null ? ' · ${report.crop}' : ''}',
                      style: s(t.caption)),
                  const SizedBox(height: 6),
                  Text(disclaimer, style: s(t.caption).copyWith(fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
