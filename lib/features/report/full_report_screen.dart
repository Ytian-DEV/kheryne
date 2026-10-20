import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/router/routes.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import 'pdf_preview_screen.dart';
import 'report_screen.dart';

/// Desktop "Open full report" page: the interactive report beside a
/// print-ready A4 page.
class FullReportScreen extends ConsumerWidget {
  const FullReportScreen({super.key, required this.reportId});
  final String reportId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(reportProvider(reportId));
    final name = ref.watch(settingsProvider).userName;
    final k = context.k;
    final t = context.t;
    return Scaffold(
      appBar: KNavBar(title: 'Full report', actions: [
        KButton.secondary(label: 'Export PDF', icon: KIcons.pdf, size: KButtonSize.compact, onPressed: () => context.pushTo(Routes.reportPdf(reportId))),
        const SizedBox(width: KSpace.s8),
        KButton(label: 'Print', icon: KIcons.print, size: KButtonSize.compact, onPressed: () => showToast(context, 'Sending to the default printer…')),
        const SizedBox(width: KSpace.s12),
      ]),
      body: AsyncView<Report?>(
        value: report,
        loading: const Padding(padding: EdgeInsets.all(KSpace.s32), child: ReportSkeleton()),
        isEmpty: (r) => r == null,
        empty: const EmptyState(art: LineArt.noResults, message: 'This report isn’t on the device anymore.'),
        data: (r) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(KSpace.s40, KSpace.s24, KSpace.s40, KSpace.s40),
                children: [Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: ReportBody(report: r!, showNotes: true)))],
              ),
            ),
            Container(
              width: 400,
              decoration: BoxDecoration(color: k.surface, border: Border(left: BorderSide(color: k.separator))),
              child: ListView(
                padding: const EdgeInsets.all(KSpace.s24),
                children: [
                  Text('PRINT PREVIEW', style: t.sectionHeader),
                  const SizedBox(height: KSpace.s12),
                  Theme(data: KheryneTheme.light(), child: A4Page(report: r, name: name)),
                  const SizedBox(height: KSpace.s12),
                  Text('A4, portrait. Includes the disclaimer and your name.', style: t.caption),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
