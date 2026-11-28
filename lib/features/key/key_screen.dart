import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/layout/form_factor.dart';
import '../../core/providers.dart';
import '../../core/router/routes.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../mock/key_tree.dart';

enum KeyAnswer { yes, no, unsure }

/// One question per screen with Yes / No / Not sure, a breadcrumb of
/// answers, and a result. Can be pre-filled from a report.
class KeyScreen extends ConsumerStatefulWidget {
  const KeyScreen({super.key, this.fromReport, this.embedded = false});
  final String? fromReport;

  /// Desktop branch: no back button.
  final bool embedded;

  @override
  ConsumerState<KeyScreen> createState() => _KeyScreenState();
}

class _KeyScreenState extends ConsumerState<KeyScreen> {
  final List<(String, KeyAnswer)> _answers = [];
  String _current = keyStart;
  String? _result;
  bool _prefilled = false;
  String? _reportGenus;

  void _answer(KeyAnswer a) {
    final q = keyQuestions[_current]!;
    // "Not sure" follows the branch that matches the report when there is
    // one, otherwise the first choice, and is flagged on the result.
    final goYes = switch (a) {
      KeyAnswer.yes => true,
      KeyAnswer.no => false,
      KeyAnswer.unsure => _reportGenus == null || pathTo(_reportGenus!).any((p) => p.$1 == _current && p.$2),
    };
    final next = goYes ? q.yes : q.no;
    setState(() {
      _answers.add((_current, a));
      if (next.startsWith('=')) {
        _result = next.substring(1);
      } else {
        _current = next;
      }
    });
  }

  void _goBackTo(int index) => setState(() {
        _current = _answers[index].$1;
        _answers.removeRange(index, _answers.length);
        _result = null;
        _prefilled = false;
      });

  void _restart() => setState(() {
        _answers.clear();
        _current = keyStart;
        _result = null;
        _prefilled = false;
      });

  @override
  Widget build(BuildContext context) {
    final report = widget.fromReport == null ? null : ref.watch(reportProvider(widget.fromReport!)).value;
    if (report != null && _reportGenus == null) {
      _reportGenus = report.genus;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _prefilled = true;
          for (final (q, yes) in pathTo(report.genus)) {
            _answers.add((q, yes ? KeyAnswer.yes : KeyAnswer.no));
          }
          _result = report.genus;
        });
      });
    }
    final desktop = FormFactor.of(context).isDesktop;
    return LargeTitleScaffold(
      title: 'Dichotomous key',
      showBack: !widget.embedded,
      maxContentWidth: 760,
      actions: [
        if (_answers.isNotEmpty) KButton.tertiary(label: 'Start over', size: KButtonSize.compact, onPressed: _restart),
      ],
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_prefilled && report != null) ...[
                const StatusBanner(
                  title: 'Pre-filled from your report',
                  message: 'Answers follow the traits Kheryne read. Tap any step to change it.',
                  tone: BannerTone.info,
                  icon: KIcons.key,
                ),
                const SizedBox(height: KSpace.s16),
              ],
              _Breadcrumb(answers: _answers, onTap: _goBackTo),
              const SizedBox(height: KSpace.s16),
              AnimatedSwitcher(
                duration: KMotion.of(context, KMotion.base),
                switchInCurve: KMotion.ease,
                transitionBuilder: (child, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(position: Tween(begin: const Offset(0.04, 0), end: Offset.zero).animate(a), child: child),
                ),
                child: _result != null
                    ? _Result(
                        key: ValueKey('r$_result'),
                        genus: _result!,
                        unsure: _answers.where((a) => a.$2 == KeyAnswer.unsure).length,
                        reportGenus: _reportGenus,
                        steps: _answers.length,
                        onRestart: _restart,
                      )
                    : _Question(
                        key: ValueKey(_current),
                        q: keyQuestions[_current]!,
                        step: _answers.length + 1,
                        wide: desktop,
                        onAnswer: _answer,
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({required this.answers, required this.onTap});
  final List<(String, KeyAnswer)> answers;
  final ValueChanged<int> onTap;

  static const _short = {
    'stylet': 'Stylet',
    'flanges': 'Flanges',
    'bulb': 'Median bulb',
    'smallStylet': 'Small stylet',
    'rings': 'Rings',
    'sheath': 'Sheath',
    'longStylet': 'Long stylet',
    'retrorse': 'Retrorse',
    'swollen': 'Swollen',
    'cyst': 'Cyst',
    'pear': 'Pear',
    'kidney': 'Kidney',
    'massive': 'Massive stylet',
    'spiral': 'Spiral',
    'spiralTail': 'Tail',
    'overlap': 'Glands',
    'vulva': 'Vulva',
    'long': 'Length',
  };

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final t = context.t;
    if (answers.isEmpty) {
      return Text('Answer each question about the specimen you see. You can go back at any step.', style: t.caption);
    }
    return Wrap(
      spacing: KSpace.s4,
      runSpacing: KSpace.s8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < answers.length; i++) ...[
          Pressable(
            onTap: () => onTap(i),
            semanticLabel: 'Step ${i + 1}: ${_short[answers[i].$1]}, ${answers[i].$2.name}. Go back to this step',
            borderRadius: KRadius.pill,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: k.surface, borderRadius: KRadius.pill, border: Border.all(color: k.separator)),
              child: Text.rich(TextSpan(style: t.caption.copyWith(fontSize: 12), children: [
                TextSpan(text: '${_short[answers[i].$1]} '),
                TextSpan(
                  text: switch (answers[i].$2) { KeyAnswer.yes => 'Yes', KeyAnswer.no => 'No', KeyAnswer.unsure => 'Not sure' },
                  style: TextStyle(color: answers[i].$2 == KeyAnswer.unsure ? k.warning : k.text, fontWeight: FontWeight.w600),
                ),
              ])),
            ),
          ),
          if (i < answers.length - 1) Icon(KIcons.chevronRight, size: 12, color: k.textSecondary),
        ],
      ],
    );
  }
}

class _Question extends StatelessWidget {
  const _Question({super.key, required this.q, required this.step, required this.wide, required this.onAnswer});
  final KeyQuestion q;
  final int step;
  final bool wide;
  final ValueChanged<KeyAnswer> onAnswer;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    Widget choice(bool yes) => Expanded(
          child: KCard(
            onTap: () => onAnswer(yes ? KeyAnswer.yes : KeyAnswer.no),
            semanticLabel: '${yes ? 'Yes' : 'No'}: ${yes ? q.yesLabel : q.noLabel}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: TraitIllustration(yes ? q.yesIllustration : q.noIllustration, height: wide ? 96 : 64)),
                const SizedBox(height: KSpace.s12),
                Text(yes ? 'Yes' : 'No', style: t.headline),
                const SizedBox(height: 2),
                Text(yes ? q.yesLabel : q.noLabel, style: t.caption),
              ],
            ),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Question $step', style: t.captionStrong),
        const SizedBox(height: KSpace.s4),
        Semantics(header: true, child: Text(q.question, style: t.title2)),
        const SizedBox(height: KSpace.s8),
        Text(q.hint, style: t.callout.copyWith(color: context.k.textSecondary)),
        const SizedBox(height: KSpace.s20),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [choice(true), const SizedBox(width: KSpace.s12), choice(false)],
          ),
        ),
        const SizedBox(height: KSpace.s12),
        Center(child: KButton.tertiary(label: 'Not sure', onPressed: () => onAnswer(KeyAnswer.unsure))),
      ],
    );
  }
}

class _Result extends ConsumerWidget {
  const _Result({super.key, required this.genus, required this.unsure, required this.reportGenus, required this.steps, required this.onRestart});
  final String genus;
  final int unsure;
  final String? reportGenus;
  final int steps;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = context.k;
    final t = context.t;
    final info = ref.watch(referenceRepositoryProvider).genus(genus);
    final now = ref.watch(clockProvider)();
    final agrees = reportGenus == null ? null : reportGenus == genus;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KCard(
          padding: EdgeInsets.zero,
          clip: true,
          radius: KRadius.hero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 150, child: SpecimenPortrait(genus: genus, seed: info.imageSeeds.first)),
              Padding(
                padding: const EdgeInsets.all(KSpace.s20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Key result after $steps steps', style: t.captionStrong),
                    const SizedBox(height: KSpace.s4),
                    GenusName(genus, style: t.title1),
                    Text('${info.commonName} · ${info.family}', style: t.callout.copyWith(color: k.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: KSpace.s16),
        if (agrees != null)
          StatusBanner(
            title: agrees ? 'Matches Kheryne’s result' : 'Differs from Kheryne’s result',
            message: agrees ? null : 'Kheryne suggested $reportGenus. Check the steps where you answered differently, or ask an expert.',
            tone: agrees ? BannerTone.success : BannerTone.warning,
          ),
        if (unsure > 0) ...[
          const SizedBox(height: KSpace.s8),
          StatusBanner(
            title: '$unsure answer${unsure == 1 ? ' was' : 's were'} “Not sure”',
            message: 'Treat this result as uncertain and confirm with an expert.',
          ),
        ],
        const SizedBox(height: KSpace.s16),
        Row(children: [
          Expanded(child: KButton.secondary(label: 'Start over', expand: true, onPressed: onRestart)),
          const SizedBox(width: KSpace.s12),
          Expanded(child: KButton(label: 'Open in gallery', expand: true, onPressed: () => context.pushTo(Routes.genus(genus)))),
        ]),
        const SizedBox(height: KSpace.s12),
        Text('Generated ${now.day}/${now.month}/${now.year}. The key covers the target genera recorded in the Philippines.',
            style: t.caption, textAlign: TextAlign.center),
      ],
    );
  }
}
