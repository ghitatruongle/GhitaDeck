# GhitaDeck

Flutter application for creating PowerPoint presentations with HTML support and AI-powered content generation.

## Version
- **Current version:** `0.0.2+3` (0.0.2 stable — data-integrity fixes; installs over every previous GhitaDeck / GhitaPPT Converter build)
- **Release status:** Official stable (data-integrity release: export-safe promotion, no silent deck/draft loss, truthful UI feedback)

## Features

### 1. **HTML to PPTX Conversion**
Write custom HTML for slides — the engine preserves rich content in the output:
- Bold, italic, underline, strikethrough, headings, lists, tables, line breaks
- Inline styling: `color`, `background-color`, `font-size`, `font-family`, `text-align`
- Images (`<img>` with base64 data URIs or local file paths)
- Hyperlinks (`<a href>`)
- Speaker notes (notes field or `<aside class="notes">`)
- Slide background via `data-bg-color`
- Drag-to-reorder, edit, duplicate, delete slides with undo/redo
- Export as 16:9 (default) or 4:3 PPTX with a proper Office theme and document properties

### 2. **Export Formats**
- **PPTX** — full OOXML package (theme, notes slides, embedded media)
- **PDF** — one landscape page per slide, same HTML interpretation as PPTX, with embedded Unicode system font (full Vietnamese support); optional **PDF bookmarks** (outline panel, one entry per slide) and **dedicated speaker-notes pages** interleaved after their slides
- **HTML** — standalone browser deck with keyboard/touch navigation, progress bar, fullscreen
- **Word report (.docx)** — v2.0.5: deck → Word report (outline + speaker notes, optional numbered slide index, heading size follows the outline level), minimal ECMA-376 package that opens without a repair prompt; runs on the worker isolate with real cancel + per-slide progress
- **Diagram blocks** — themed flowchart/mindmap inserts (Insert ribbon → Diagram) carried across all three export formats

**Export experience (v2.0.5 beta):** image optimizer tallies real savings in the success snackbar (images only — the DOCX report has no images); the export dialog is locale-aware (formats/ratios/qualities in EN or VI) and hides options the selected format ignores; progress is announced to screen readers and always ends at 100%.

### 3. **Live Preview & Present Mode**
- Live rendered preview beside the HTML editor (WebView2)
- Per-slide preview dialog in the slide list
- **Present mode**: fullscreen in-app playback (arrow keys, progress bar, Esc to exit)

### 4. **Slide Transition Effects**
61 transition effects across 6 groups (Basic / Entrance / Emphasis / Exit / Motion Path / Advanced): every effect plays for real in the HTML player and Present mode with per-effect easing, and maps to native PPTX transitions on export. Deck-wide default plus per-slide overrides with 0.1–3 s duration, auto-advance and transition sound.

### 5. **AI Assistant**
Chat interface to generate presentation HTML using **OpenAI**, **Anthropic**, **Google Gemini**, or **Ollama** (local, no API key needed).
- **Streaming responses** with a Stop button
- **Outline mode**: AI drafts an editable outline, then generates each slide with progress
- **Multi-slide generation**: Ask "Create 3 slides about Machine Learning"
- Customizable system prompt
- API keys stored encrypted via `flutter_secure_storage`

### 6. **Smart Auto-Save**
- Background draft auto-saves every 3-5 seconds when working on unsaved projects
- Temporary drafts automatically purged after saving to `.ghita`

### 7. **Project Management**
- `.ghita` project bundles (ZIP with manifest, slides, history, media)
- Recent projects hub with search and tagging
- Undo/redo time machine history (up to 30 snapshots)

### 8. **Slide Templates**
20 bundled templates in 6 categories (Business, Creative, Academic, Marketing and more) with recommended transitions and accent colors, plus user-saved templates.

### 9. **Dark Mode**
Toggle between Light, Dark, and System theme mode. Persisted across restarts.

### 10. **Wi-Fi Live Presentation**
Broadcast live slides over local Wi-Fi to audience devices via HTTP server.

### 11. **Command Palette**
Quick action launcher (`Ctrl+K`) and keyboard shortcuts cheat sheet (`Ctrl+/`).

### 12. **Windows Desktop**
Native Windows application with Material Design 3.

## Project Structure

```
lib/
├── main.dart                           # App entry point, MultiProvider, global error boundary
├── config/
│   └── build_info.dart                 # Central release metadata
├── l10n/                               # EN/VI strings (app_en.arb, app_vi.arb)
├── models/                             # 20 models (slide.dart, slide_template.dart, export_options.dart, ppt_theme_setting.dart, ...)
├── providers/                          # 8 files (app_provider, presentation_state, ai_provider_manager, config_service, deck_export_actions, locale_provider, shortcuts_provider, theme_provider)
├── screens/
│   ├── home_screen.dart                # 5-destination shell + command palette
│   ├── editor/                         # EditorShell, EditorState, HTML editor / slide list / canvas panels
│   ├── ai_chat_screen.dart             # AI chat + streaming + outline mode
│   ├── present_screen.dart             # Fullscreen in-app present mode
│   ├── presenter_view_screen.dart      # Presenter view
│   ├── slide_sorter_screen.dart        # Slide sorter
│   ├── recent_projects_screen.dart     # .ghita project management
│   ├── template_studio_screen.dart     # Template gallery (20 templates)
│   ├── settings_screen.dart            # Theme, API keys, backups, editor prefs
│   ├── provider_settings_screen.dart   # Provider ping, model fetch, key rotation
│   ├── configuration_wizard.dart       # First-run wizard
│   ├── theme_settings_screen.dart      # Theme settings screen
│   └── widgets/                        # 52 widget files (export dialog, ribbon, panels, dialogs)
└── services/                           # ~100 services; key ones:
    ├── ppt_generator.dart              # PPTX OOXML builder (images, notes, links, theme)
    ├── pdf_export_service.dart         # PDF export (Unicode font, bookmarks, notes pages)
    ├── html_export_service.dart        # Standalone HTML deck export
    ├── docx_report_service.dart        # Word report export
    ├── odp_export_service.dart         # ODP export
    ├── project_bundle_service.dart     # .ghita ZIP bundle (manifest, slides, history, media)
    ├── smart_draft_manager.dart        # Auto-save drafts, purge after official save
    ├── time_machine_history_service.dart # Undo/redo snapshot tree
    ├── export_isolate.dart             # Worker-isolate export pipeline
    ├── template_service.dart           # Template asset loader
    ├── deck_translation_service.dart   # Deck translation
    ├── collaboration_service.dart      # LAN collaboration
    ├── wifi_broadcaster_service.dart   # Live Wi-Fi broadcaster
    ├── rust_engine.dart                # Engine choice (rust/dart fallback)
    └── zip_codec.dart                  # Zip engine facade
assets/
├── config/
│   └── providers.json                  # AI provider templates (no API keys)
├── templates/                          # 20 HTML slide templates + manifest
└── images/
    └── app_logo.png
test/                                   # 124 test files (unit + widget + contract)
```

## Getting Started

### Prerequisites
- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0
- **WebView2 Runtime** (preinstalled on Windows 10/11) — required for live preview and Present mode; the rest of the app works without it

### Setup
```bash
flutter pub get
```

### Running
```bash
flutter run -d windows
```

### Running Tests
```bash
flutter test
# Rust module unit tests (pure Rust — no app needed)
cd rust && cargo test
# Real-DLL integration probe (needs the Windows build)
flutter test integration_test/rust_engine_probe_test.dart -d windows
```

### Engine & Fallback Architecture (dev)

The app ships a Rust core (`ghita_core.dll`, via flutter_rust_bridge) for
three components — zip, image processing and the HTML tokenizer. The DLL is
**never required to run**: every component is a facade with the same Dart
implementation underneath, and the engine choice is per-isolate:

- `RustBridgeInit` (`lib/services/rust_bridge_init.dart`) — the **single
  single-flight init** per isolate: zip/image/htmlparse/UI service all call
  the same `ensureReady()`, so the FRB binding is never initialised twice
  (that error used to make the second caller report a permanent fallback).
- `RustEngineService` (`lib/services/rust_engine.dart`) — the UI-isolate owner
  of the Settings choice; status ∈ `rustReady | dart | fallingBack` shows in
  Settings with a user-facing hint on fallback.
- `ImageEngineConfig` / `ZipEngineConfig` / `HtmlParseEngineConfig` — worker
  isolates read the choice from the job message; the worker **awaits** the
  readiness decision at job start so one export never mixes backends.
- **Fallback contract:** a missing/broken/old DLL never throws out of
  `ensure*ReadyOnce` — it resolves to "not usable" → the Dart path runs.
  Debugging: `%APPDATA%\GhitaDeck\engine.log` (local, PII-free) records every
  init/fallback transition.
- **UI-isolate rule:** anything that renders frames (the slide-frame
  renderer) uses `HtmlImageLoader.load(dartOnly: true)` — synchronous FRB
  calls happen only in worker isolates.

Engine work follows test-before-fix: unit tests fake the DLL with injected
`rustInit`/`rustReadyProbe`, the genuine load is proven by the integration
probe above.

### Building for Release
```bash
flutter build windows --release
```

### Building the Windows installer

Install Inno Setup 6, then run the installer builder after a successful
Windows Release build:

```powershell
./installer/build_installer.ps1 -Clean
```

It produces an x64 installer (default: Program Files, UAC-elevated; the wizard
lets you pick any custom directory, or per-user mode on machines without admin
rights) plus a SHA-256 checksum and release
metadata JSON in `installer/output/`. Version data is read from `pubspec.yaml`,
and the manifest records the source revision, dirty-tree state, hashes, and
Authenticode status. The installer intentionally preserves user projects and
settings when it is uninstalled.

Verify the resulting package, including a silent install/uninstall smoke test:

```powershell
./installer/verify_release.ps1 -SmokeInstall -SmokeLaunch
```

For an externally distributed release, sign both the application and installer
with an installed code-signing certificate:

```powershell
./installer/build_installer.ps1 -Clean -SigningCertificateThumbprint "CERT_THUMBPRINT"
./installer/verify_release.ps1 -SmokeInstall -SmokeLaunch -RequireSignature
```

## What's New

See [CHANGELOG.md](CHANGELOG.md) for the full history. Latest stable: **0.0.2** — data-integrity fixes: export-safe promotion, no silent deck/draft loss, truthful UI feedback.

## Security Note
API keys for AI providers are stored using `flutter_secure_storage` (encrypted keychain on each platform). No API keys are written to `SharedPreferences` or committed to version control. Local providers (Ollama) don't require an API key.

## License
MIT
