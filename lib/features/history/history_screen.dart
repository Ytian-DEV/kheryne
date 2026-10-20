import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/layout/app_shell.dart';
import '../../core/layout/form_factor.dart';
import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/router/routes.dart';
import '../../core/theme/theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import '../report/report_screen.dart';

enum ConfidenceFilter { all, high, medium, uncertain }

enum DateFilter { any, week, month }

extension on ConfidenceFilter {
  String get label => switch (this) {
        ConfidenceFilter.all => 'Any confidence',
        ConfidenceFilter.high => '80% and up',
        ConfidenceFilter.medium => '60–79%',
        ConfidenceFilter.uncertain => 'Uncertain',
      };
  bool test(double c) => switch (this) {
        ConfidenceFilter.all => true,
        ConfidenceFilter.high => c >= 0.8,
        ConfidenceFilter.medium => c >= 0.6 && c < 0.8,
        ConfidenceFilter.uncertain => c < 0.6,
      };
}

extension on DateFilter {
  String get label => switch (this) {
        DateFilter.any => 'Any date',
        DateFilter.week => 'Last 7 days',
        DateFilter.month => 'Last 30 days',
      };
}

/// Searchable, filterable history grouped by date. Phone: list with swipe
/// actions. Desktop: master-detail with right-click menus.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  String? _genus;
  String? _crop;
  ConfidenceFilter _conf = ConfidenceFilter.all;
  DateFilter _date = DateFilter.any;
  String? _selectedId;

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  List<Report> _filter(List<Report> all, DateTime now) {
    final q = _search.text.trim().toLowerCase();
    return all.where((r) {
      if (q.isNotEmpty &&
          !('${r.genus} ${r.classification.family.name} ${r.crop ?? ''} ${r.sampleCode ?? ''} ${r.specimen.fileName}')
              .toLowerCase()
              .contains(q)) {
        return false;
      }
      if (_genus != null && r.genus != _genus) return false;
      if (_crop != null && r.crop != _crop) return false;
      if (!_conf.test(r.classification.genus.confidence)) return false;
      final age = now.difference(r.createdAt).inDays;
      if (_date == DateFilter.week && age > 7) return false;
      if (_date == DateFilter.month && age > 30) return false;
      return true;
    }).toList();
  }

  bool get _filtered => _genus != null || _crop != null || _conf != ConfidenceFilter.all || _date != DateFilter.any;

  Future<void> _delete(Report r) async {
    final repo = ref.read(identificationRepositoryProvider);
    await repo.delete(r.id);
    ref.invalidate(historyProvider);
    if (!mounted) return;
    if (_selectedId == r.id) setState(() => _selectedId = null);
    showToast(context, 'Deleted ${r.genus} identification.', action: 'Undo', onAction: () async {
      await repo.save(r);
      ref.invalidate(historyProvider);
    });
  }

  void _menu(Report r, Offset global) async {
    final pick = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(global.dx, global.dy, global.dx + 1, global.dy + 1),
      items: const [
        PopupMenuItem(value: 'open', child: Text('Open full report')),
        PopupMenuItem(value: 'pdf', child: Text('Export PDF')),
        PopupMenuItem(value: 'key', child: Text('Open in dichotomous key')),
        PopupMenuDivider(),
        PopupMenuItem(value: 'delete', child: Text('Delete')),
      ],
    );
    if (!mounted) return;
    switch (pick) {
      case 'open':
        context.pushTo(Routes.reportFull(r.id));
      case 'pdf':
        context.pushTo(Routes.reportPdf(r.id));
      case 'key':
        context.pushTo(Routes.key(fromReport: r.id));
      case 'delete':
        if (await confirmAction(context, title: 'Delete this identification?', message: 'The photo and report will be removed from this device.', confirm: 'Delete', destructive: true)) {
          await _delete(r);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(historyProvider);
    final now = ref.watch(clockProvider)();
    final desktop = FormFactor.of(context).isDesktop;
    final all = history.value ?? const <Report>[];

    final searchField = Actions(
      actions: {SearchIntent: CallbackAction<SearchIntent>(onInvoke: (_) => _searchFocus.requestFocus())},
      child: TextField(
        controller: _search,
        focusNode: _searchFocus,
        onChanged: (_) => setState(() {}),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search genus, crop or sample',
          prefixIcon: const Icon(KIcons.search, size: KSize.icon),
          suffixIcon: _search.text.isEmpty
              ? null
              : KIconButton(icon: KIcons.close, label: 'Clear search', size: 16, onPressed: () => setState(_search.clear)),
        ),
      ),
    );

    final filters = SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _FilterChip(
            label: _genus ?? 'Genus',
            italic: _genus != null,
            active: _genus != null,
            onTap: () => _pickFrom('Genus', {for (final r in all) r.genus}.toList()..sort(), _genus, (v) => setState(() => _genus = v), italic: true),
          ),
          _FilterChip(
            label: _date.label,
            active: _date != DateFilter.any,
            onTap: () => _pickFrom('Date', DateFilter.values.map((d) => d.label).toList(), _date.label,
                (v) => setState(() => _date = DateFilter.values.firstWhere((d) => d.label == v, orElse: () => DateFilter.any))),
          ),
          _FilterChip(
            label: _conf.label,
            active: _conf != ConfidenceFilter.all,
            onTap: () => _pickFrom('Confidence', ConfidenceFilter.values.map((d) => d.label).toList(), _conf.label,
                (v) => setState(() => _conf = ConfidenceFilter.values.firstWhere((d) => d.label == v, orElse: () => ConfidenceFilter.all))),
          ),
          _FilterChip(
            label: _crop ?? 'Crop',
            active: _crop != null,
            onTap: () => _pickFrom('Crop', {for (final r in all) ?r.crop}.toList()..sort(), _crop, (v) => setState(() => _crop = v)),
          ),
          if (_filtered)
            KButton.tertiary(
              label: 'Clear',
              size: KButtonSize.compact,
              onPressed: () => setState(() {
                _genus = null;
                _crop = null;
                _conf = ConfidenceFilter.all;
                _date = DateFilter.any;
              }),
            ),
        ],
      ),
    );

    final list = AsyncView<List<Report>>(
      value: history,
      onRetry: () => ref.invalidate(historyProvider),
      loading: const _HistorySkeleton(),
      isEmpty: (l) => l.isEmpty,
      empty: EmptyState(
        art: LineArt.emptySlide,
        message: 'No identifications yet.',
        action: desktop ? 'Import images' : 'Start a scan',
        onAction: () => context.pushTo(desktop ? Routes.import : Routes.scan),
      ),
      data: (all) {
        final rows = _filter(all, now);
        if (rows.isEmpty) {
          return EmptyState(
            art: LineArt.noResults,
            message: _search.text.isNotEmpty ? 'No matches for “${_search.text}”.' : 'Nothing matches these filters.',
            action: 'Clear search and filters',
            onAction: () => setState(() {
              _search.clear();
              _genus = null;
              _crop = null;
              _conf = ConfidenceFilter.all;
              _date = DateFilter.any;
            }),
          );
        }
        final groups = <String, List<Report>>{};
        for (final r in rows) {
          (groups[dayBucket(r.createdAt, now)] ??= []).add(r);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final g in groups.entries) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(KSpace.s16, KSpace.s16, KSpace.s16, KSpace.s8),
                child: Text(g.key.toUpperCase(), style: context.t.sectionHeader),
              ),
              ClipRRect(
                borderRadius: KRadius.cardAll,
                child: ColoredBox(
                  color: context.k.surface,
                  child: Column(children: [
                    for (var i = 0; i < g.value.length; i++) ...[
                      _Row(
                        report: g.value[i],
                        now: now,
                        selected: desktop && g.value[i].id == _selectedId,
                        swipe: !desktop,
                        onTap: () => desktop ? setState(() => _selectedId = g.value[i].id) : context.goTo(Routes.historyDetail(g.value[i].id)),
                        onDelete: () => _delete(g.value[i]),
                        onExport: () => context.pushTo(Routes.reportPdf(g.value[i].id)),
                        onSecondary: (pos) => _menu(g.value[i], pos),
                      ),
                      if (i < g.value.length - 1)
                        Padding(
                          padding: const EdgeInsets.only(left: 84),
                          child: Divider(height: KSize.hairline, thickness: KSize.hairline, color: context.k.separator),
                        ),
                    ],
                  ]),
                ),
              ),
            ],
          ],
        );
      },
    );

    if (!desktop) {
      return LargeTitleScaffold(
        title: 'History',
        showBack: false,
        onRefresh: () async => ref.invalidate(historyProvider),
        header: Column(children: [searchField, const SizedBox(height: KSpace.s12), filters]),
        slivers: [
          const SliverToBoxAdapter(child: OfflineNotice()),
          SliverToBoxAdapter(child: list),
          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      );
    }

    final selected = all.where((r) => r.id == _selectedId).firstOrNull ?? (all.isEmpty || ViewStateScope.of(context) != null ? null : all.first);
    final k = context.k;
    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 420,
            child: DecoratedBox(
              decoration: BoxDecoration(border: Border(right: BorderSide(color: k.separator))),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(KSpace.s16, KSpace.s24, KSpace.s16, KSpace.s24),
                children: [
                  Text('History', style: context.t.title1),
                  const SizedBox(height: KSpace.s16),
                  searchField,
                  const SizedBox(height: KSpace.s12),
                  filters,
                  const SizedBox(height: KSpace.s8),
                  const OfflineNotice(padding: EdgeInsets.only(top: KSpace.s8)),
                  list,
                ],
              ),
            ),
          ),
          Expanded(
            child: selected == null
                ? (history.isLoading || ViewStateScope.of(context) == ViewState.loading
                    ? const Padding(padding: EdgeInsets.all(KSpace.s32), child: ReportSkeleton())
                    : const EmptyState(art: LineArt.microscope, message: 'Select an identification to see its report.'))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(KSpace.s32, KSpace.s24, KSpace.s32, KSpace.s40),
                    children: [
                      Row(children: [
                        Expanded(child: Text('Report', style: context.t.title2)),
                        KButton.secondary(label: 'Export PDF', icon: KIcons.pdf, size: KButtonSize.compact, onPressed: () => context.pushTo(Routes.reportPdf(selected.id))),
                        const SizedBox(width: KSpace.s8),
                        KButton.secondary(label: 'Open full report', icon: KIcons.external, size: KButtonSize.compact, onPressed: () => context.pushTo(Routes.reportFull(selected.id))),
                      ]),
                      const SizedBox(height: KSpace.s16),
                      Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: ReportBody(key: ValueKey(selected.id), report: selected, showNotes: true))),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFrom(String title, List<String> options, String? current, ValueChanged<String?> onPick, {bool italic = false}) async {
    final picked = await showKBottomSheet<String>(
      context,
      title: title,
      initial: 0.5,
      detents: const [0.5, 0.9],
      builder: (ctx, c) => ListView(
        controller: c,
        padding: const EdgeInsets.fromLTRB(KSpace.s16, KSpace.s8, KSpace.s16, KSpace.s24),
        children: [
          KListSection(children: [
            KListRow(
              title: 'All',
              trailing: current == null ? Icon(KIcons.check, color: ctx.k.primary, size: KSize.icon) : null,
              chevron: false,
              onTap: () => Navigator.of(ctx).pop(''),
            ),
            for (final o in options)
              KListRow(
                title: o,
                titleWidget: italic ? GenusName(o, style: ctx.t.bodyStyle) : null,
                trailing: o == current ? Icon(KIcons.check, color: ctx.k.primary, size: KSize.icon) : null,
                chevron: false,
                onTap: () => Navigator.of(ctx).pop(o),
              ),
          ]),
        ],
      ),
    );
    if (picked != null) onPick(picked.isEmpty ? null : picked);
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.active, required this.onTap, this.italic = false});
  final String label;
  final bool active;
  final bool italic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final t = context.t;
    return Padding(
      padding: const EdgeInsets.only(right: KSpace.s8),
      child: Pressable(
        onTap: onTap,
        semanticLabel: 'Filter: $label',
        borderRadius: KRadius.pill,
        child: Container(
          padding: const EdgeInsets.fromLTRB(KSpace.s12, 0, KSpace.s8, 0),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? k.container : k.surface,
            borderRadius: KRadius.pill,
            border: Border.all(color: active ? Colors.transparent : k.separator),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label,
                style: t.captionStrong.copyWith(
                    color: active ? k.primaryStrong : k.text, fontStyle: italic ? FontStyle.italic : null)),
            const SizedBox(width: 2),
            Icon(KIcons.chevronDown, size: 14, color: active ? k.primaryStrong : k.textSecondary),
          ]),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.report,
    required this.now,
    required this.selected,
    required this.swipe,
    required this.onTap,
    required this.onDelete,
    required this.onExport,
    required this.onSecondary,
  });
  final Report report;
  final DateTime now;
  final bool selected;
  final bool swipe;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onExport;
  final ValueChanged<Offset> onSecondary;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final t = context.t;
    final c = report.classification;
    final row = Pressable(
      onTap: onTap,
      onSecondaryTapDown: (d) => onSecondary(d.globalPosition),
      selected: selected,
      semanticLabel: '${report.genus}, ${c.family.name}, ${percent(c.genus.confidence)}${c.isUncertain ? ', uncertain' : ''}, ${timeOnly(report.createdAt)}',
      borderRadius: BorderRadius.zero,
      pressScale: 1,
      child: Container(
        color: selected ? k.container : null,
        padding: const EdgeInsets.symmetric(horizontal: KSpace.s16, vertical: KSpace.s12),
        child: Row(
          children: [
            ClipRRect(borderRadius: KRadius.smAll, child: SizedBox.square(dimension: 56, child: Micrograph(specimen: report.specimen))),
            const SizedBox(width: KSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GenusName(report.genus, style: t.headline),
                  const SizedBox(height: 2),
                  Text([c.family.name, ?report.crop].join(' · '), style: t.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  ConfidencePill(c.genus.confidence, compact: true),
                ],
              ),
            ),
            const SizedBox(width: KSpace.s8),
            Text(dayBucket(report.createdAt, now) == 'Today' || dayBucket(report.createdAt, now) == 'Yesterday' ? timeOnly(report.createdAt) : shortDate(report.createdAt),
                style: t.caption.copyWith(fontFeatures: KType.tabular)),
          ],
        ),
      ),
    );
    if (!swipe) return row;
    return Dismissible(
      key: ValueKey(report.id),
      background: _SwipeBg(color: k.success, icon: KIcons.export, label: 'Export', alignLeft: true),
      secondaryBackground: _SwipeBg(color: k.error, icon: KIcons.trash, label: 'Delete', alignLeft: false),
      confirmDismiss: (dir) async {
        if (dir == DismissDirection.startToEnd) {
          onExport();
          return false;
        }
        return true;
      },
      onDismissed: (_) => onDelete(),
      child: row,
    );
  }
}

class _SwipeBg extends StatelessWidget {
  const _SwipeBg({required this.color, required this.icon, required this.label, required this.alignLeft});
  final Color color;
  final IconData icon;
  final String label;
  final bool alignLeft;

  @override
  Widget build(BuildContext context) {
    final fg = onFill(color);
    return Container(
      color: color,
      alignment: alignLeft ? Alignment.centerLeft : Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: KSpace.s24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: fg),
        const SizedBox(height: 2),
        Text(label, style: context.t.micro.copyWith(color: fg)),
      ]),
    );
  }
}

class _HistorySkeleton extends StatelessWidget {
  const _HistorySkeleton();

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(padding: EdgeInsets.fromLTRB(KSpace.s16, KSpace.s16, 0, KSpace.s8), child: SkeletonBlock(width: 60, height: 12)),
          ClipRRect(
            borderRadius: KRadius.cardAll,
            child: ColoredBox(
              color: context.k.surface,
              child: Column(children: [
                for (var i = 0; i < 6; i++)
                  const Padding(
                    padding: EdgeInsets.all(KSpace.s12),
                    child: Row(children: [
                      SkeletonBlock(width: 56, height: 56),
                      SizedBox(width: KSpace.s12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          SkeletonBlock(width: 140, height: 16),
                          SizedBox(height: 6),
                          SkeletonBlock(width: 110, height: 12),
                          SizedBox(height: 6),
                          SkeletonBlock(width: 48, height: 18, radius: KRadius.full),
                        ]),
                      ),
                    ]),
                  ),
              ]),
            ),
          ),
        ],
      );
}
