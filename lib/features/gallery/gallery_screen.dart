import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/layout/form_factor.dart';
import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/router/routes.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../mock/taxonomy.dart';
import 'genus_detail_screen.dart';

/// Browse Order → Family → Genus. "Recorded in the Philippines" is on by
/// default; "All genera" shows the full reference taxonomy.
class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key});

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  bool _phOnly = true;
  final _search = TextEditingController();
  String? _selected = 'Pratylenchus';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final t = context.t;
    final repo = ref.watch(referenceRepositoryProvider);
    final system = ref.watch(settingsProvider).system;
    final desktop = FormFactor.of(context).isDesktop;
    final ph = {for (final g in repo.targetGenera) g.name};
    final q = _search.text.trim().toLowerCase();
    final forced = ViewStateScope.of(context);

    final header = Column(children: [
      KSegmentedControl<bool>(
        segments: const [(true, 'In the Philippines', null), (false, 'All genera', null)],
        value: _phOnly,
        onChanged: (v) => setState(() => _phOnly = v),
      ),
      const SizedBox(height: KSpace.s12),
      TextField(
        controller: _search,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Search genus or family',
          prefixIcon: const Icon(KIcons.search, size: KSize.icon),
          suffixIcon: _search.text.isEmpty
              ? null
              : KIconButton(icon: KIcons.close, label: 'Clear search', size: 16, onPressed: () => setState(_search.clear)),
        ),
      ),
    ]);

    final sections = <Widget>[];
    var shown = 0;
    for (final order in repo.taxonomy) {
      final fams = <(TaxonFamily, List<String>)>[];
      for (final f in order.families) {
        final genera = f.genera.where((g) {
          if (_phOnly && !ph.contains(g)) return false;
          if (q.isEmpty) return true;
          return g.toLowerCase().contains(q) || f.name.toLowerCase().contains(q);
        }).toList();
        if (genera.isNotEmpty) fams.add((f, genera));
      }
      if (fams.isEmpty) continue;
      sections.add(Padding(
        padding: const EdgeInsets.fromLTRB(KSpace.s4, KSpace.s16, KSpace.s4, KSpace.s4),
        child: Semantics(
          header: true,
          child: Text.rich(TextSpan(style: t.title2.copyWith(fontSize: 20), children: [
            TextSpan(text: 'Order ', style: t.callout.copyWith(color: k.textSecondary)),
            TextSpan(text: system.orderFor(order.name, fams.first.$1.name)),
          ])),
        ),
      ));
      for (final (f, genera) in fams) {
        shown += genera.length;
        sections.add(KListSection(
          header: '${f.name.toUpperCase()}  ·  ${genera.length}',
          margin: const EdgeInsets.only(top: KSpace.s12),
          children: [
            for (final g in genera)
              KListRow(
                title: g,
                titleWidget: GenusName(g, style: t.bodyStyle),
                subtitle: ph.contains(g) ? repo.genus(g).commonName : null,
                selected: desktop && _selected == g,
                trailing: ph.contains(g)
                    ? Semantics(label: 'Recorded in the Philippines', child: Icon(KIcons.leaf, size: 16, color: k.success))
                    : null,
                chevron: !desktop,
                onTap: () => desktop ? setState(() => _selected = g) : context.pushTo(Routes.genus(g)),
              ),
          ],
        ));
      }
    }

    final Widget body = switch (forced) {
      ViewState.loading => Column(children: [
          for (var i = 0; i < 4; i++) ...[
            const SizedBox(height: KSpace.s16),
            const SkeletonBlock(height: 150, radius: KRadius.card),
          ],
        ]),
      ViewState.error => ErrorState(title: 'Couldn’t load the reference gallery', onRetry: () {}),
      _ => shown == 0 || forced == ViewState.empty
          ? EmptyState(
              art: LineArt.noResults,
              message: 'No genus matches “${_search.text}”.',
              detail: _phOnly ? 'Try “All genera” to search the full taxonomy.' : null,
              action: _phOnly ? 'Search all genera' : 'Clear search',
              onAction: () => setState(() => _phOnly ? _phOnly = false : _search.clear()),
            )
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('$shown genera${_phOnly ? ' Kheryne can identify' : ' in the reference taxonomy (NeMys 2026)'}', style: t.caption),
              ...sections,
            ]),
    };

    if (!desktop) {
      return LargeTitleScaffold(
        title: 'Reference gallery',
        showBack: false,
        header: header,
        slivers: [
          const SliverToBoxAdapter(child: OfflineNotice()),
          SliverToBoxAdapter(child: body),
          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      );
    }
    return Scaffold(
      body: Row(children: [
        SizedBox(
          width: 380,
          child: DecoratedBox(
            decoration: BoxDecoration(border: Border(right: BorderSide(color: k.separator))),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(KSpace.s16, KSpace.s24, KSpace.s16, KSpace.s24),
              children: [Text('Reference gallery', style: t.title1), const SizedBox(height: KSpace.s16), header, const SizedBox(height: KSpace.s8), body],
            ),
          ),
        ),
        Expanded(
          child: _selected == null
              ? const EmptyState(art: LineArt.microscope, message: 'Select a genus to see its traits.')
              : GenusDetailScreen(key: ValueKey(_selected), name: _selected!, embedded: true),
        ),
      ]),
    );
  }
}
