import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/data/training_repository.dart';
import '../../core/layout/form_factor.dart';
import '../../core/models/models.dart';
import '../../core/models/serialization.dart';
import '../../core/providers.dart';
import '../../core/router/routes.dart';
import '../../core/theme/theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import '../auth/auth_controller.dart';

const _labImageGroup = XTypeGroup(
  label: 'Microscope images',
  extensions: ['jpg', 'jpeg', 'png', 'webp', 'tif', 'tiff'],
);

enum _TrainingTab { labGroundTruth, reviewQueue, datasetBalance }

final trainingSummaryProvider = FutureProvider<DatasetSummary>(
  (ref) => ref.watch(trainingRepositoryProvider).fetchSummary(),
);

final reviewQueueSamplesProvider = FutureProvider<List<TrainingSample>>(
  (ref) => ref.watch(trainingRepositoryProvider).listSamples(
        statuses: const [
          ReviewStatus.priorityReview,
          ReviewStatus.pendingReview,
          ReviewStatus.quarantinedQuality,
        ],
      ),
);

/// 2-Way Nematode Model Training & Curation Hub:
/// 1. Scientist / Owner Lab Ground-Truth Uploader & Box Annotator (`verified_gold`)
/// 2. Scientist Verification Queue for User-Submitted Scans (`verified_silver`)
/// 3. Dataset Balance & YOLO / Classifier Export Guide
class TrainingScreen extends ConsumerStatefulWidget {
  const TrainingScreen({super.key, this.embedded = false});
  final bool embedded;

  @override
  ConsumerState<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends ConsumerState<TrainingScreen> {
  _TrainingTab _tab = _TrainingTab.labGroundTruth;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isCurator = auth.isScientistOrOwner;

    if (AppConfig.supabaseReady && !auth.isSignedIn) {
      return LargeTitleScaffold(
        title: 'Lab dataset',
        showBack: !widget.embedded,
        maxContentWidth: 860,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: KSpace.s32),
              child: EmptyState(
                art: LineArt.microscope,
                message: 'Sign in to manage training samples and review user scans.',
                detail: 'Owner and Scientist accounts can annotate gold ground-truth slides and verify user submissions.',
                action: 'Sign in',
                onAction: () => context.pushTo(Routes.auth),
              ),
            ),
          ),
        ],
      );
    }

    return LargeTitleScaffold(
      title: 'Lab dataset & review queue',
      showBack: !widget.embedded,
      maxContentWidth: 920,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KSegmentedControl<_TrainingTab>(
            segments: [
              (_TrainingTab.labGroundTruth, isCurator ? 'Lab ground truth' : 'Submit slide', KIcons.flask),
              (_TrainingTab.reviewQueue, isCurator ? 'Review queue' : 'My submissions', KIcons.checkCircle),
              (_TrainingTab.datasetBalance, 'Dataset stats', KIcons.table),
            ],
            value: _tab,
            onChanged: (t) => setState(() => _tab = t),
          ),
        ],
      ),
      slivers: [
        SliverToBoxAdapter(
          child: switch (_tab) {
            _TrainingTab.labGroundTruth => _LabSampleComposer(isCurator: isCurator),
            _TrainingTab.reviewQueue => _ReviewQueueView(isCurator: isCurator),
            _TrainingTab.datasetBalance => const _DatasetBalanceView(),
          },
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 96)),
      ],
    );
  }
}

class _LabSampleComposer extends ConsumerStatefulWidget {
  const _LabSampleComposer({required this.isCurator});
  final bool isCurator;

  @override
  ConsumerState<_LabSampleComposer> createState() => _LabSampleComposerState();
}

class _LabSampleComposerState extends ConsumerState<_LabSampleComposer> {
  Uint8List? _bytes;
  String? _fileName;
  Specimen? _tempSpecimen;
  List<Detection> _boxes = const [];
  String? _selectedBoxId;
  CanvasTool _tool = CanvasTool.draw;
  String _genus = 'Meloidogyne';
  int _objective = 40;
  String _lifeStage = 'adult_female';
  final _crop = TextEditingController();
  final _sampleCode = TextEditingController();
  final _locality = TextEditingController();
  final _notes = TextEditingController();
  bool _detecting = false;
  bool _submitting = false;

  @override
  void dispose() {
    _crop.dispose();
    _sampleCode.dispose();
    _locality.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickSlide() async {
    final file = await openFile(acceptedTypeGroups: const [_labImageGroup]);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final cache = ref.read(localCacheProvider);
    final tempId = newUuid();
    final savedPath = await cache.persistImageBytes(tempId, file.name, bytes);
    final inferred = _inferGenusFromFileName(
      file.name,
      ref.read(referenceRepositoryProvider).allGenera,
    );

    setState(() {
      _bytes = bytes;
      _fileName = file.name;
      if (inferred != null) _genus = inferred;
      _detecting = true;
      _tempSpecimen = Specimen(
        id: tempId,
        seed: 1,
        fileName: file.name,
        objective: _objective,
        worms: const [],
        capturedAt: DateTime.now(),
        localPath: savedPath,
      );
      _boxes = const [];
      _selectedBoxId = null;
    });

    // Run OpenCV / ONNX candidate pre-detection if server is online so scientist can refine boxes quickly.
    if (ref.read(onlineProvider)) {
      final mlRes = await ref.read(mlServerClientProvider).detect(imageBytes: bytes, fileName: file.name);
      if (mounted && mlRes != null && mlRes.detections.isNotEmpty) {
        setState(() {
          _boxes = [
            for (final d in mlRes.detections) d.copyWith(kind: BoxKind.confirmed),
          ];
          _selectedBoxId = _boxes.first.id;
          _tool = CanvasTool.select;
        });
      }
    }
    if (mounted) setState(() => _detecting = false);
  }

  void _addBox(Rect r) {
    final d = Detection(id: newUuid(), rect: r, kind: BoxKind.confirmed, confidence: 1.0);
    setState(() {
      _boxes = [..._boxes, d];
      _selectedBoxId = d.id;
      _tool = CanvasTool.select;
    });
  }

  void _toggleSelectedClass() {
    if (_selectedBoxId == null) return;
    setState(() {
      _boxes = [
        for (final b in _boxes)
          if (b.id == _selectedBoxId)
            b.copyWith(
              kind: b.kind == BoxKind.rejected ? BoxKind.confirmed : BoxKind.rejected,
              rejectReason: b.kind == BoxKind.rejected ? null : 'Debris (negative)',
            )
          else
            b,
      ];
    });
  }

  void _removeSelected() {
    if (_selectedBoxId == null) return;
    setState(() {
      _boxes = _boxes.where((b) => b.id != _selectedBoxId).toList();
      _selectedBoxId = _boxes.firstOrNull?.id;
    });
  }

  Future<void> _submit() async {
    final bytes = _bytes;
    final name = _fileName;
    final tempSpec = _tempSpecimen;
    if (bytes == null || name == null || tempSpec == null) {
      showToast(context, 'Choose a microscope slide image first.');
      return;
    }
    if (_boxes.isEmpty) {
      showToast(context, 'Draw at least one bounding box around the nematode on the slide.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final repo = ref.read(trainingRepositoryProvider);
      if (widget.isCurator) {
        await repo.submitScientistLabSample(
          imageBytes: bytes,
          fileName: name,
          verifiedGenus: _genus,
          objective: _objective,
          lifeStage: _lifeStage,
          crop: _crop.text,
          sampleCode: _sampleCode.text,
          locality: _locality.text,
          notes: _notes.text,
          annotations: [
            for (final b in _boxes)
              TrainingAnnotation(
                id: b.id,
                rect: b.rect,
                classLabel: b.kind == BoxKind.rejected ? 'debris' : 'nematode',
                genusLabel: b.kind == BoxKind.rejected ? null : _genus,
                confidence: 1.0,
                isGroundTruth: true,
              ),
          ],
        );
      } else {
        await repo.submitUserDetectionSample(
          specimen: tempSpec.copyWith(objective: _objective),
          detections: _boxes,
          imageBytes: bytes,
        );
      }

      ref.invalidate(trainingSummaryProvider);
      ref.invalidate(reviewQueueSamplesProvider);
      if (!mounted) return;
      setState(() {
        _bytes = null;
        _fileName = null;
        _tempSpecimen = null;
        _boxes = const [];
        _selectedBoxId = null;
        _notes.clear();
      });
      showToast(
        context,
        widget.isCurator
            ? 'Saved verified Gold ground-truth sample for $_genus.'
            : 'Submitted slide to the Scientist Review Queue.',
      );
    } catch (e) {
      if (mounted) showToast(context, 'Could not save training sample: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _pickGenus() async {
    final repo = ref.read(referenceRepositoryProvider);
    final picked = await _showGenusPickerSheet(
      context,
      title: 'Ground-truth genus',
      current: _genus,
      targetGenera: repo.targetGenera,
      allGenera: repo.allGenera,
    );
    if (picked != null) setState(() => _genus = picked);
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final t = context.t;
    final desktop = FormFactor.of(context).isDesktop;

    return Padding(
      padding: const EdgeInsets.only(top: KSpace.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StatusBanner(
            title: widget.isCurator
                ? 'Source 1 · Scientist / Owner Lab Ground-Truth Mode'
                : 'Source 2 · Submit Slide for Scientist Verification',
            message: widget.isCurator
                ? 'Upload a microscope slide, draw tight bounding boxes around every nematode (and optional negative debris boxes), and assign the verified genus. Saved directly as Gold training data.'
                : 'Upload a slide and mark candidate nematodes so a VSU scientist can verify it for future model training.',
            tone: BannerTone.info,
            icon: KIcons.flask,
          ),
          const SizedBox(height: KSpace.s16),
          if (_tempSpecimen == null)
            KCard(
              padding: const EdgeInsets.all(KSpace.s32),
              child: Column(
                children: [
                  Icon(KIcons.fileUp, size: 38, color: k.primary),
                  const SizedBox(height: KSpace.s12),
                  Text('Select a microscope slide image', style: t.title2),
                  const SizedBox(height: KSpace.s4),
                  Text('JPEG, PNG, WebP or TIFF · Draw exact bounding boxes for YOLO & Classifier training', style: t.caption, textAlign: TextAlign.center),
                  const SizedBox(height: KSpace.s20),
                  KButton(
                    label: 'Choose slide image',
                    icon: KIcons.upload,
                    onPressed: _pickSlide,
                  ),
                ],
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(child: Text('${_fileName ?? ''} · ${_boxes.length} box${_boxes.length == 1 ? '' : 'es'}', style: t.subhead)),
                KButton.tertiary(label: 'Change image', size: KButtonSize.compact, onPressed: _pickSlide),
              ],
            ),
            const SizedBox(height: KSpace.s8),
            ClipRRect(
              borderRadius: KRadius.sheetAll,
              child: SizedBox(
                height: desktop ? 440 : 340,
                child: ColoredBox(
                  color: k.canvas,
                  child: BoxCanvas(
                    specimen: _tempSpecimen!,
                    detections: _boxes,
                    selectedId: _selectedBoxId,
                    tool: _tool,
                    onSelect: (id) => setState(() => _selectedBoxId = id),
                    onCreate: _addBox,
                    onChange: (id, rect) => setState(() {
                      _boxes = [for (final b in _boxes) b.id == id ? b.copyWith(rect: rect) : b];
                    }),
                  ),
                ),
              ),
            ),
            const SizedBox(height: KSpace.s12),
            Wrap(
              spacing: KSpace.s8,
              runSpacing: KSpace.s8,
              children: [
                TraitChip(
                  label: 'Draw box',
                  selected: _tool == CanvasTool.draw,
                  onTap: () => setState(() => _tool = CanvasTool.draw),
                ),
                TraitChip(
                  label: 'Select / resize',
                  selected: _tool == CanvasTool.select,
                  onTap: () => setState(() => _tool = CanvasTool.select),
                ),
                if (_selectedBoxId != null) ...[
                  TraitChip(
                    label: _boxes.firstWhere((b) => b.id == _selectedBoxId).kind == BoxKind.rejected
                        ? 'Class: Negative debris'
                        : 'Class: Nematode',
                    selected: true,
                    onTap: _toggleSelectedClass,
                  ),
                  TraitChip(
                    label: 'Delete box',
                    selected: false,
                    onTap: _removeSelected,
                  ),
                ],
                if (_detecting) Text('Running OpenCV candidate pre-scan…', style: t.caption),
              ],
            ),
            const SizedBox(height: KSpace.s20),
            if (widget.isCurator) ...[
              KListSection(
                header: 'VERIFIED GROUND-TRUTH LABELS',
                children: [
                  KListRow(
                    title: 'Verified genus',
                    leading: KIcons.leaf,
                    trailing: GenusName(_genus, style: t.bodyStyle.copyWith(color: k.textSecondary)),
                    chevron: true,
                    onTap: _pickGenus,
                  ),
                ],
              ),
              const SizedBox(height: KSpace.s12),
              KSegmentedControl<String>(
                segments: const [
                  ('adult_female', 'Female', null),
                  ('juvenile_j2', 'J2', null),
                  ('adult_male', 'Male', null),
                  ('cyst', 'Cyst', null),
                ],
                value: _lifeStage,
                onChanged: (v) => setState(() => _lifeStage = v),
              ),
              const SizedBox(height: KSpace.s12),
            ],
            KSegmentedControl<int>(
              segments: const [(10, '10×', null), (40, '40×', null), (100, '100×', null)],
              value: _objective,
              onChanged: (v) => setState(() => _objective = v),
            ),
            const SizedBox(height: KSpace.s12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _crop,
                    decoration: const InputDecoration(labelText: 'Host crop (optional)', prefixIcon: Icon(KIcons.plant, size: KSize.icon)),
                  ),
                ),
                const SizedBox(width: KSpace.s12),
                Expanded(
                  child: TextField(
                    controller: _locality,
                    decoration: const InputDecoration(labelText: 'Site / locality (optional)', prefixIcon: Icon(KIcons.globe, size: KSize.icon)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: KSpace.s12),
            TextField(
              controller: _notes,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(hintText: 'Preparation notes, fixation or morphological observations'),
            ),
            const SizedBox(height: KSpace.s16),
            KButton(
              label: widget.isCurator ? 'Save Gold ground-truth sample' : 'Submit slide for scientist review',
              icon: KIcons.checkCircle,
              expand: true,
              loading: _submitting,
              onPressed: _submitting ? null : _submit,
            ),
          ],
        ],
      ),
    );
  }
}

class _ReviewQueueView extends ConsumerWidget {
  const _ReviewQueueView({required this.isCurator});
  final bool isCurator;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final samples = ref.watch(reviewQueueSamplesProvider);
    final now = ref.watch(clockProvider)();

    return Padding(
      padding: const EdgeInsets.only(top: KSpace.s16),
      child: AsyncView<List<TrainingSample>>(
        value: samples,
        onRetry: () => ref.invalidate(reviewQueueSamplesProvider),
        loading: Column(
          children: List.generate(
            3,
            (_) => const Padding(
              padding: EdgeInsets.only(bottom: KSpace.s12),
              child: SkeletonBlock(height: 140, radius: KRadius.card),
            ),
          ),
        ),
        isEmpty: (l) => l.isEmpty,
        empty: EmptyState(
          art: LineArt.emptySlide,
          message: isCurator ? 'No user submissions waiting for review.' : 'You haven’t submitted any slides yet.',
          detail: isCurator
              ? 'Uncertain or user-submitted scans automatically appear here for verification before retraining.'
              : 'Saved identifications (when training contribution is enabled) appear here.',
        ),
        data: (list) => Column(
          children: [
            for (final s in list)
              Padding(
                padding: const EdgeInsets.only(bottom: KSpace.s12),
                child: _QueueSampleCard(sample: s, now: now, isCurator: isCurator),
              ),
          ],
        ),
      ),
    );
  }
}

class _QueueSampleCard extends ConsumerStatefulWidget {
  const _QueueSampleCard({required this.sample, required this.now, required this.isCurator});
  final TrainingSample sample;
  final DateTime now;
  final bool isCurator;

  @override
  ConsumerState<_QueueSampleCard> createState() => _QueueSampleCardState();
}

class _QueueSampleCardState extends ConsumerState<_QueueSampleCard> {
  late String _selectedGenus = widget.sample.aiPredictedGenus ?? 'Meloidogyne';
  bool _busy = false;

  Future<void> _pickGenus() async {
    final repo = ref.read(referenceRepositoryProvider);
    final picked = await _showGenusPickerSheet(
      context,
      title: 'Assign verified genus',
      current: _selectedGenus,
      targetGenera: repo.targetGenera,
      allGenera: repo.allGenera,
    );
    if (picked != null) setState(() => _selectedGenus = picked);
  }

  Future<void> _decide(bool approve) async {
    setState(() => _busy = true);
    try {
      await ref.read(trainingRepositoryProvider).reviewSample(
            sampleId: widget.sample.id,
            approve: approve,
            verifiedGenus: approve ? _selectedGenus : null,
          );
      ref.invalidate(reviewQueueSamplesProvider);
      ref.invalidate(trainingSummaryProvider);
      if (mounted) {
        showToast(
          context,
          approve ? 'Verified as $_selectedGenus (Silver training set).' : 'Rejected sample from training set.',
        );
      }
    } catch (_) {
      if (mounted) showToast(context, 'Could not update review status.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.sample;
    final k = context.k;
    final t = context.t;

    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: KRadius.smAll,
                child: SizedBox.square(
                  dimension: 88,
                  child: s.imageUrl != null
                      ? Image.network(s.imageUrl!, fit: BoxFit.cover)
                      : ColoredBox(
                          color: k.container,
                          child: Icon(KIcons.image, color: k.primary),
                        ),
                ),
              ),
              const SizedBox(width: KSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            s.fileName,
                            style: t.headline,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        StatusChip(
                          label: s.reviewStatus.label,
                          icon: s.reviewStatus == ReviewStatus.priorityReview ? KIcons.warning : KIcons.clock,
                          color: s.reviewStatus == ReviewStatus.priorityReview ? k.warning : k.textSecondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${s.objective}× objective · ${s.annotations.length} box${s.annotations.length == 1 ? '' : 'es'} · ${relative(s.createdAt, widget.now)}',
                      style: t.caption,
                    ),
                    if (s.aiPredictedGenus != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text('Model guess: ', style: t.caption),
                          GenusName(s.aiPredictedGenus!, style: t.calloutStrong),
                          if (s.aiConfidence != null) ...[
                            const SizedBox(width: KSpace.s8),
                            ConfidencePill(s.aiConfidence!, compact: true),
                          ],
                        ],
                      ),
                    ],
                    if (s.keyDisagreed) ...[
                      const SizedBox(height: 4),
                      Text('Dichotomous key disagreed with AI prediction', style: t.micro.copyWith(color: k.warning)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (widget.isCurator) ...[
            const SizedBox(height: KSpace.s12),
            Divider(height: 1, color: k.separator),
            const SizedBox(height: KSpace.s12),
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: KSpace.s8,
                    runSpacing: KSpace.s4,
                    children: [
                      Text('Verified genus:', style: t.caption),
                      GenusName(_selectedGenus, style: t.calloutStrong),
                      KButton.secondary(
                        label: 'Change',
                        icon: KIcons.leaf,
                        size: KButtonSize.compact,
                        onPressed: _busy ? null : _pickGenus,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: KSpace.s8),
                KButton(
                  label: 'Reject',
                  icon: KIcons.close,
                  variant: KButtonVariant.destructive,
                  size: KButtonSize.compact,
                  onPressed: _busy ? null : () => _decide(false),
                ),
                const SizedBox(width: KSpace.s8),
                KButton(
                  label: 'Verify Silver',
                  icon: KIcons.check,
                  size: KButtonSize.compact,
                  loading: _busy,
                  onPressed: _busy ? null : () => _decide(true),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DatasetBalanceView extends ConsumerWidget {
  const _DatasetBalanceView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(trainingSummaryProvider);
    final genera = ref.watch(referenceRepositoryProvider).targetGenera;
    final t = context.t;
    final k = context.k;

    return Padding(
      padding: const EdgeInsets.only(top: KSpace.s16),
      child: AsyncView<DatasetSummary>(
        value: summaryAsync,
        onRetry: () => ref.invalidate(trainingSummaryProvider),
        loading: const SkeletonBlock(height: 280, radius: KRadius.card),
        data: (summary) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KListSection(
              header: 'TRAINING PIPELINE SUMMARY',
              footer: 'Only Gold (Scientist lab samples) and Silver (Scientist-verified user scans) are exported for model training.',
              children: [
                KListRow(title: 'Gold · Scientist lab ground truth', leading: KIcons.flask, leadingColor: k.success, value: '${summary.goldCount}'),
                KListRow(title: 'Silver · Verified user scans', leading: KIcons.checkCircle, leadingColor: k.primary, value: '${summary.silverCount}'),
                KListRow(title: 'Priority active-learning queue', leading: KIcons.warning, leadingColor: k.warning, value: '${summary.priorityCount}'),
                KListRow(title: 'Pending standard review', leading: KIcons.clock, value: '${summary.pendingCount}'),
                KListRow(title: 'Quarantined (blurry / too dark)', leading: KIcons.xCircle, leadingColor: k.error, value: '${summary.quarantinedCount}'),
              ],
            ),
            const SizedBox(height: KSpace.s24),
            Text('VERIFIED SAMPLES PER GENUS (${genera.length} TARGET GENERA)', style: t.sectionHeader),
            const SizedBox(height: KSpace.s8),
            KListSection(
              children: [
                for (final g in genera)
                  KListRow(
                    title: g.name,
                    titleWidget: GenusName(g.name, style: t.bodyStyle),
                    subtitle: g.family,
                    value: '${summary.perGenusVerified[g.name] ?? 0} verified',
                    chevron: false,
                  ),
              ],
            ),
            if (summary.perGenusVerified.keys.any((kName) => !genera.any((g) => g.name == kName))) ...[
              const SizedBox(height: KSpace.s24),
              Text('ADDITIONAL NEMYS GENERA IN DATASET', style: t.sectionHeader),
              const SizedBox(height: KSpace.s8),
              KListSection(
                children: [
                  for (final entry in summary.perGenusVerified.entries)
                    if (!genera.any((g) => g.name == entry.key))
                      KListRow(
                        title: entry.key,
                        titleWidget: GenusName(entry.key, style: t.bodyStyle),
                        value: '${entry.value} verified',
                        chevron: false,
                      ),
                ],
              ),
            ],
            const SizedBox(height: KSpace.s24),
            KCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Export YOLO + Classifier Dataset', style: t.headline),
                  const SizedBox(height: KSpace.s8),
                  Text(
                    'Run server/export_dataset.py with your Supabase URL and service key (or Scientist token) to export verified Gold & Silver samples into Ultralytics YOLO detection format and cropped genus classification folders:',
                    style: t.caption,
                  ),
                  const SizedBox(height: KSpace.s8),
                  SelectableText(
                    'python server/export_dataset.py --out server/dataset_out',
                    style: t.captionStrong.copyWith(fontFeatures: KType.tabular),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String? _inferGenusFromFileName(String fileName, List<GenusInfo> allGenera) {
  final lower = fileName.toLowerCase();
  final sorted = [...allGenera]..sort((a, b) => b.name.length.compareTo(a.name.length));
  for (final g in sorted) {
    final gLower = g.name.toLowerCase();
    if (RegExp('(^|[^a-z])$gLower([^a-z]|\$)').hasMatch(lower)) {
      return g.name;
    }
  }
  return null;
}

Future<String?> _showGenusPickerSheet(
  BuildContext context, {
  required String title,
  required String current,
  required List<GenusInfo> targetGenera,
  required List<GenusInfo> allGenera,
}) {
  return showKBottomSheet<String>(
    context,
    title: title,
    initial: 0.85,
    detents: const [0.65, 0.85, 0.95],
    builder: (ctx, scrollController) => _GenusPickerList(
      scrollController: scrollController,
      current: current,
      targetGenera: targetGenera,
      allGenera: allGenera,
    ),
  );
}

class _GenusPickerList extends StatefulWidget {
  const _GenusPickerList({
    required this.scrollController,
    required this.current,
    required this.targetGenera,
    required this.allGenera,
  });

  final ScrollController scrollController;
  final String current;
  final List<GenusInfo> targetGenera;
  final List<GenusInfo> allGenera;

  @override
  State<_GenusPickerList> createState() => _GenusPickerListState();
}

class _GenusPickerListState extends State<_GenusPickerList> {
  String _query = '';

  bool _matches(GenusInfo g, String q) {
    if (q.isEmpty) return true;
    return g.name.toLowerCase().contains(q) ||
        g.family.toLowerCase().contains(q) ||
        g.commonName.toLowerCase().contains(q);
  }

  String? _normalizedCustom(String raw) {
    final clean = raw.trim().replaceAll(RegExp(r'[^A-Za-z]'), '');
    if (clean.length < 3) return null;
    final cap = '${clean[0].toUpperCase()}${clean.substring(1).toLowerCase()}';
    if (widget.allGenera.any((g) => g.name.toLowerCase() == cap.toLowerCase())) {
      return null;
    }
    return cap;
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final targetNames = {for (final g in widget.targetGenera) g.name};
    final filteredTarget = [
      for (final g in widget.targetGenera)
        if (_matches(g, q)) g,
    ];
    final filteredOther = [
      for (final g in widget.allGenera)
        if (!targetNames.contains(g.name) && _matches(g, q)) g,
    ];
    final custom = _normalizedCustom(_query);

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(KSpace.s16),
      children: [
        TextField(
          autofocus: true,
          onChanged: (v) => setState(() => _query = v),
          decoration: const InputDecoration(
            hintText: 'Search genus, family or common name (e.g. Criconema)…',
            prefixIcon: Icon(KIcons.search, size: KSize.icon),
          ),
        ),
        const SizedBox(height: KSpace.s16),
        if (filteredTarget.isNotEmpty) ...[
          KListSection(
            header: 'PHILIPPINE TARGET GENERA (${filteredTarget.length})',
            children: [
              for (final g in filteredTarget)
                KListRow(
                  title: g.name,
                  titleWidget: GenusName(g.name, style: context.t.bodyStyle),
                  subtitle: '${g.commonName} · ${g.family}',
                  trailing: g.name == widget.current
                      ? Icon(KIcons.check, color: context.k.primary, size: KSize.icon)
                      : null,
                  chevron: false,
                  onTap: () => Navigator.of(context).pop(g.name),
                ),
            ],
          ),
          const SizedBox(height: KSpace.s16),
        ],
        if (filteredOther.isNotEmpty) ...[
          KListSection(
            header: 'ALL NEMYS 2026 GENERA (${filteredOther.length})',
            footer: 'Accepted plant-parasitic genera across all 14 families.',
            children: [
              for (final g in filteredOther)
                KListRow(
                  title: g.name,
                  titleWidget: GenusName(g.name, style: context.t.bodyStyle),
                  subtitle: '${g.family} · ${g.order}',
                  trailing: g.name == widget.current
                      ? Icon(KIcons.check, color: context.k.primary, size: KSize.icon)
                      : null,
                  chevron: false,
                  onTap: () => Navigator.of(context).pop(g.name),
                ),
            ],
          ),
          const SizedBox(height: KSpace.s16),
        ],
        if (custom != null)
          KListSection(
            header: 'CUSTOM GENUS LABEL',
            children: [
              KListRow(
                title: custom,
                titleWidget: Row(
                  children: [
                    Text('Use ', style: context.t.bodyStyle),
                    GenusName(custom, style: context.t.bodyStyle),
                  ],
                ),
                subtitle: 'Save ground-truth label for a genus outside the bundled list',
                leading: KIcons.plus,
                chevron: false,
                onTap: () => Navigator.of(context).pop(custom),
              ),
            ],
          ),
      ],
    );
  }
}
