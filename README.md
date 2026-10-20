# Kheryne

*Kheryne: An AI-Assisted Mobile and Desktop Application for Identifying Plant-Parasitic Nematodes from Order to Genus Through Morphological Analysis of Microscope Images* (Visayas State University, BS Computer Science).

This is the **UI layer**: every screen, state and flow for Android and Windows, wired to mock data. There is no real camera ML or backend yet. iOS and macOS folders are generated so those platforms can be built later from the same code.

Design system and screen list: [`docs/DESIGN.md`](docs/DESIGN.md). Screenshots: [`docs/screenshots/`](docs/screenshots/).

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

## What is mocked, and where the real parts plug in

| Area | Now | Replace with |
|---|---|---|
| Detection, box check, classification | `MockIdentificationRepository` (`lib/mock/mock_repository.dart`) returns deterministic results with simulated latency. | An implementation of `IdentificationRepository` (`lib/core/data/repositories.dart`) that runs the on-device detector and classifier (e.g. TFLite / ONNX). Swap it in `identificationRepositoryProvider` (`lib/core/providers.dart`). The UI depends only on the interface. |
| Storage (history, notes, calibrations) | In memory | SQLite (e.g. `drift`), behind the same repository and `SettingsController`. |
| Micrograph images | Painted in code (`Micrograph`, `SpecimenPortrait`). | **Replace with real dataset images.** `Specimen` gets an image path; `Micrograph` renders it. Boxes already use normalised coordinates. |
| Image filters | Colour-matrix approximations; CLAHE, sharpen and edge are simulated. | OpenCV / image processing. The filter list is config-driven (`features/scan/filters.dart`). |
| Camera | `camera` package preview on Android when Settings → "Demo feed" is off; falls back to the mock feed when no camera is available. | Frame stream into the detector. |
| Pairing | State machine with a mock QR pattern. | Local-network service (mDNS + WebSocket/WebRTC) and a real QR encoder. |
| File import / drag-and-drop / export | Pickers pick mock specimens; exports show a confirmation. | `file_selector`, `desktop_drop`, and `pdf` / CSV / Excel writers. |
| NeMys link | Opens `nemys.ugent.be` search with `url_launcher`. | — |

## Notes and deviations from the brief

- **Fonts:** Inter is bundled as an asset rather than fetched by `google_fonts`. The app must work offline in the lab, and golden screenshots need deterministic fonts.
- **Icons:** the Phosphor font is bundled directly because `phosphor_flutter` 2.1.0 no longer compiles on Flutter 3.47 (`IconData` became a final class).
- **Typed routes:** typed routes are hand-written helpers (`Routes.report(id)`), not code-generated, which avoids a build_runner step for the thesis team.
- **"Scan always dark":** this is a Settings toggle, on by default. Off, Live Scan and the Workspace follow the app theme.
- **Classic taxonomy:** "Classic: Tylenchida" changes only the order name (Aphelenchoididae → Aphelenchida). Families and genera are the same.
- **Disclaimer:** Kheryne supports identification. Confirm important results with a qualified nematologist.
