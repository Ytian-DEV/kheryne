# Kheryne

*Kheryne: An AI-Assisted Mobile and Desktop Application for Identifying Plant-Parasitic Nematodes from Order to Genus Through Morphological Analysis of Microscope Images* (Visayas State University, BS Computer Science).

Cross-platform **Flutter** client (Android & Windows, with iOS/macOS scaffolded) connected to **Supabase** (PostgreSQL + Row-Level Security, Auth, and Storage), an **offline-first local cache & sync queue**, and a pluggable **Python FastAPI + OpenCV/ONNX ML server** (`server/`).

Design system and screen list: [`docs/DESIGN.md`](docs/DESIGN.md). Screenshots: [`docs/screenshots/`](docs/screenshots/). Python ML Server: [`server/README.md`](server/README.md).

## Run

You need Flutter 3.47 or newer (Dart 3.13). Check your setup with `flutter doctor`.

```bash
flutter pub get
```

On Android, use a device or emulator. This needs the Android SDK (Android Studio).

```bash
flutter run -d android
```

On Windows, Flutter needs Visual Studio 2022 with the "Desktop development with C++" workload, and Windows Developer Mode turned on so plugin symlinks work.

```bash
flutter run -d windows
```

To open the hidden Screen Gallery at launch:

```bash
flutter run --dart-define=GALLERY=true
```

Inside the app, the gallery is at **Settings → About → tap the version 5 times**. It lists every screen and its states (loading, empty, error, offline), plus switches for phone or desktop layout and light or dark theme.

## Tests and screenshots

```bash
flutter analyze
```

```bash
flutter test
```

To regenerate `docs/screenshots/` (160 images):

```bash
flutter test test/screenshots_test.dart --update-goldens
```

`test/flows_test.dart` covers:

- the box flow (pink → check → green → analyze → report)
- drawing a purple box, and a rejected red box with an ✕
- the Android back gesture
- the Ctrl+O and +/- shortcuts on Windows
- italic genus names on every screen
- 130% text scaling without overflow

## Folder structure

```
lib/
  main.dart, app.dart        window setup (min 1024×700), theme, router
  core/
    theme/                   tokens: colours, spacing, radius, type, motion
    widgets/                 KButton, KCard, BoxCanvas, DetectionBox, ... (see DESIGN.md)
    layout/                  AppShell (bottom tabs / sidebar), FormFactor, ScanTheme
    router/                  typed routes (Routes.*) and go_router config
    models/                  Specimen, Detection, Report, Classification, ...
    data/repositories.dart   IdentificationRepository, ReferenceRepository interfaces
    providers.dart           Riverpod providers and app settings
    utils/                   formatting, haptics
  features/
    home  scan  identify  report  morphometrics  key  batch
    history  gallery  pairing  settings  workspace
  mock/                      taxonomy (NeMys 2026), 19 Philippine genera, specimens,
                             dichotomous key, MockIdentificationRepository
assets/fonts/                Inter + Inter Display (OFL), Phosphor icons (MIT)
test/                        flows, screenshot generator, harness
docs/                        DESIGN.md, screenshots/
```

## Backend & Hybrid AI Architecture

| Area | Implementation | Notes |
|---|---|---|
| Cloud database & Auth | **Supabase** (`supabase_flutter`, project `wxdacmoxlvblmakrwkog`, `ap-southeast-1`) | PostgreSQL with RLS on every table (`profiles`, `calibration_profiles`, `taxonomy_*`, `genera`, `specimens`, `detections`, `reports`, `training_samples`, `training_annotations`, `pairing_sessions`, `pairing_frames`, `ml_model_releases`), Email/Password + Google Sign-In, Realtime phone-to-PC pairing, and Storage buckets (`specimens`, `training-dataset`, `pairing-frames`, `reference-gallery`, `ml-models`). SQL migrations live in `supabase/migrations/`. |
| 2-way training pipeline | `TrainingDatasetRepository` + `TrainingScreen` (`lib/features/training/`) + `server/export_dataset.py` | **Source 1 (Gold):** Scientists/Owners upload lab micrographs, draw ground-truth nematode & negative debris bounding boxes, and tag verified genus/stage. **Source 2 (Silver):** User scans are triaged by quality & confidence (`< 0.80` or dichotomous-key disagreement → priority queue) for scientist verification before exporting Ultralytics YOLO + 19-genus classifier datasets. |
| Offline-first persistence & sync | `LocalCacheStore` + `HybridIdentificationRepository` (`lib/core/data/`) | Imported micrographs, detections, reports, morphometrics, metadata, and calibrations are saved locally first under `ApplicationSupportDirectory` and queued in `sync_queue.json` when lab Wi-Fi is down, syncing automatically once online and signed in. |
| Hybrid AI server | `server/` (Python **FastAPI + OpenCV + ONNX Runtime**) | Ready to run locally (`uvicorn app.main:app --port 7860`) or free on **Hugging Face Spaces (Docker, 16 GB RAM)**. Drop trained `detector.onnx` and `classifier.onnx` into `server/models/`; never fabricates fake genus predictions when untrained. |
| File import & CSV export | `file_selector` (`photo_picker_sheet.dart`, `import_screen.dart`, `batch_screen.dart`) | Real single-file, multi-file, and folder micrograph imports (JPEG, PNG, WebP, TIFF) plus CSV batch export. |

## Notes and deviations from the brief

- **Fonts:** Inter is bundled as an asset rather than fetched by `google_fonts`. The app must work offline in the lab, and golden screenshots need deterministic fonts.
- **Icons:** the Phosphor font is bundled directly because `phosphor_flutter` 2.1.0 no longer compiles on Flutter 3.47 (`IconData` became a final class).
- **Typed routes:** typed routes are hand-written helpers (`Routes.report(id)`), not code-generated, which avoids a build_runner step for the thesis team.
- **"Scan always dark":** this is a Settings toggle, on by default. Off, Live Scan and the Workspace follow the app theme.
- **Classic taxonomy:** "Classic: Tylenchida" changes only the order name (Aphelenchoididae → Aphelenchida). Families and genera are the same.
- **Disclaimer:** Kheryne supports identification. Confirm important results with a qualified nematologist.
