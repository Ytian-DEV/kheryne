# Kheryne design system

Apple-level craft in the visual language (large titles, inset grouped lists, sheets with detents, calm hierarchy) with native behaviour on each platform (Android back gesture and edge-to-edge; Windows shortcuts, hover, right-click, resizable panels).

Figma: **Kheryne — UI design** (`https://www.figma.com/design/KWcNyL3Ehh9ayQ09f7QB1n`). It holds the colour variables (Light/Dark modes), spacing and radius variables, the core components (KButton, ConfidencePill, DetectionBox, ListRow) and the reference frames for Android Home, Live Scan, Identification Mode, Report and the Windows Workspace. The code is the source of truth for every other screen; see `docs/screenshots/`.

## Tokens (`lib/core/theme/`)

All colours come from `KheryneColors` (`context.k`). No hex values exist outside `lib/core/theme/` (checked with `grep -rnE "Color\(0x" lib | grep -v core/theme`). The mock micrograph uses `MicrographPalette`, which describes a brightfield slide, not UI chrome.

| Token | Light | Dark | Use |
|---|---|---|---|
| primary | `#C2185B` | `#F48FB1` | Primary button, active tab, Identify |
| primaryStrong | `#880E4F` | `#F8BBD0` | Pressed, accents on container |
| accent | `#F06292` | `#F06292` | Kheryne candidate boxes, progress |
| container | `#FCE4EC` | `#4A1F33` | Chips, selected rows, secondary buttons |
| background | `#FFF5F8` | `#1C1418` | App background |
| surface | `#FFFFFF` | `#2A1F24` | Cards, sheets, panels |
| text | `#2D1B24` | `#F5E9EE` | Body text |
| textSecondary | `#6E5A64` | `#BFAAB4` | Captions |
| success | `#2E7D5B` | `#6FCF97` | ≥ 80%, confirmed (green box) |
| warning | `#B7791F` | `#F2C94C` | 60–79%, guidance (icons/borders only, never body text) |
| error | `#B3261E` | `#F28B82` | Errors, < 60% |
| userBox | `#7C4DFF` | `#B39DDB` | User-drawn box |
| notNematode | `#D32F2F` | `#EF5350` | Rejected box (always with X + "Not a nematode") |
| separator | black 8% | white 10% | Hairlines |
| onPrimary | `#FFFFFF` | `#2D1B24` | Text on primary (white on `#F48FB1` is only 2:1) |

Measured contrast (WCAG): text/background 15.2:1 (light) and 15.3:1 (dark); textSecondary 5.9:1 and 7.3:1; white on primary 5.9:1; dark text on dark primary 7.3:1. Box labels pick dark or white text by contrast (`onFill`); the lowest is 4.7:1 (dark label on dark-mode red).

- **Spacing:** 4, 8, 12, 16, 20, 24, 32, 40 (`KSpace`). The phone gutter is 16; desktop pages use 32.
- **Radius:** 8 small, 12 cards, 16 sheets, 24 hero, full pills, 6 detection boxes (`KRadius`).
- **Motion:** 200/250/300 ms with ease-out and a soft spring (`KMotion`). Every duration goes through `KMotion.of(context, …)`, which returns zero when the OS asks to reduce motion.
- **Hit targets:** 48 px minimum (`KSize.hit`).

## Type (`KType`, `context.t`)

| Style | Size | Weight | Family |
|---|---|---|---|
| largeTitle | 34 | 600 | Inter Display |
| title1 | 28 | 600 | Inter Display |
| title2 | 22 | 600 | Inter Display |
| headline | 17 | 600 | Inter |
| body | 17 | 400 | Inter |
| callout | 15 | 400 | Inter |
| caption | 13 | 400 | Inter |
| micro | 11 | 500 | Inter |

**Why Inter Display and not Poppins.** Inter Display is the optical-size cut of the same family. It tightens spacing at large sizes, so titles stay calm and the app keeps a single typeface voice; Poppins would add a second, rounder personality.

Measurements use tabular figures (`KType.tabular`). Inter (OFL) and the Phosphor icon font (MIT) are bundled, so the app works offline and screenshots are deterministic. Genus names are always italic, through `GenusName`, `genusSpan` or `italicTitle`; a test walks every rendered text span to check this.

## Icons

Phosphor Regular only (`KIcons`), at 20 and 24 px. The `phosphor_flutter` package doesn't compile on Flutter 3.47, so the font is bundled and `KIcons` holds the codepoints. No Material icons are used.

## Components (`lib/core/widgets/`)

| Widget | Notes |
|---|---|
| `KButton` | Primary / secondary / tertiary / destructive / overlay; regular 48 px and compact 40 px; loading state. One primary per screen. |
| `KIconButton` | Requires a label (semantics + tooltip). Overlay variant for controls over images. |
| `KCard` | Surface, 12 px radius, hairline border, no shadow. |
| `KListSection` / `KListRow` | Inset grouped list with hairline separators inset 16 px. |
| `ConfidencePill` | ≥80% success + check, 60–79% warning + info, <60% error + warning + "Uncertain". |
| `TraitChip` | Toggle chip for regions and filters. |
| `DetectionBox` | 2 px stroke, 6 px corners, label pill outside top-left, 12 px handles with a white border, 20% glow when selected. |
| `BoxCanvas` | Pinch/scroll zoom, pan, draw (one finger), move/resize user boxes, right-click, screen-reader targets per box. Boxes are drawn in viewport space so strokes stay crisp at any zoom. |
| `ClassificationLadder` | Order → Family → Genus with bars and runner-up genera. |
| `CaptureGuidanceBanner` / `StatusBanner` | Tone colour + icon + text. |
| `EmptyState` | Line illustration, one sentence, one action. |
| `SkeletonBlock` | Shimmer that stops with reduce motion; skeletons match the final layout. |
| `KSegmentedControl` | iOS-style; on-dark variant for camera views. |
| `showKBottomSheet` | Grabber and medium/large detents; centred sheet window on desktop. |
| `LargeTitleScaffold` | Large title that collapses into a blurred compact bar; back is a chevron icon only. |
| `Micrograph`, `SpecimenPortrait`, `TraitIllustration`, `LineArtView` | Mock imagery and line drawings, painted in code. |

All of these are shown on the Component sheet (Settings → About → tap the version 5 times → Developer → Component sheet).

## Do / don't

- **Do** keep pink to one or two elements per view. **Don't** use pink backgrounds or gradients.
- **Do** pair every status colour with an icon and words. **Don't** rely on red vs pink alone.
- **Do** say "Uncertain — confirm with an expert" below 60%. **Don't** round any rank up to 100% (mock confidences are capped at 99%).
- **Do** use blur only on bars floating over images or scrolling content. **Don't** use glass cards.
- **Do** write short, specific, sentence-case copy with verbs on buttons. **Don't** use "AI-powered", "smart", "magic", sparkles or emoji. (Checked with grep.)

## Screens

**Android**

| Screen | Purpose |
|---|---|
| Onboarding (3) | What Kheryne does; clipping the phone to the eyepiece; offline models. |
| Home | Greeting, Start live scan, Upload / Batch, recent identifications, tools, offline status. |
| Live Scan | Dark camera view with eyepiece guide, candidate boxes, zoom, light, focus meter, guidance, filter toggle, Take photo, Live/Identification. |
| Zoomed specimen | Animated zoom into a candidate; Identify nematode or Take photo. |
| Capture review | Quality checklist (focus, light, nematode in frame); Retake / Use photo. |
| Image editor | Before/after slider; filters built from `filterConfig`; "Highlight nematodes" preset. |
| Identification mode | Pink → purple → check → green ✓ / red ✕ → analyze; count chip. |
| Analysis | Live step list, cancel, error with retry. |
| Report | Region overlays, ladder, traits with "why this matters", uncertain card, actions. |
| Trait detail sheet | Zoomed region crop beside the reference drawing. |
| Calibration | Stage micrometer, two handles, known µm, one profile per objective. |
| Measure | Polyline length, width, stylet; de Man a, b, c, V% table. |
| Dichotomous key | One question per screen, picture choices, breadcrumb, result; pre-fill from a report. |
| Batch | Pick images, queue with progress, summary, export. |
| History / History detail | Search, filters, grouped by date, swipe to export or delete; report with notes. |
| Reference gallery / Genus detail | Order → Family → Genus; Philippines filter; traits, look-alikes, crops, NeMys. |
| PDF preview | A4 page with name field, disclaimer; Save / Share. |
| Settings (+ models, calibration, privacy, about) | Theme, Scan always dark, classification system, language, RA 10173. |
| Pair with computer | Scan the code; stream to LAPTOP-NAME; stop. |

**Windows**

| Screen | Purpose |
|---|---|
| Workspace | Filmstrip, canvas with zoom/minimap/box tools, resizable inspector (Adjust, Detections, Report, Measure). |
| Import | Drop zone, file/folder pickers, recent files. |
| Live (phone) | Pairing code → connecting → stream with latency and "Analyze this frame" / error. |
| Compare | Specimen beside a reference genus with linked zoom. |
| Batch | Folder import, sortable data grid, CSV / Excel / PDF. |
| History, Gallery, Key, Settings | Master-detail and wide layouts. |
| Full report | Report beside a print preview. |

Screenshots of all of these, in light and dark at 390×844 and 1440×900, are in `docs/screenshots/` (`phone/`, `desktop/`, plus `states/` for loading, empty, error and offline).
