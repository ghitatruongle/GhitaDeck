# Ghita PPT Converter v2.0.0-beta

Flutter application for creating PowerPoint presentations with HTML support and AI-powered content generation.

## Version
- **Current version:** `2.0.0-beta`
- **Release status:** Internal build (no release commit/tag yet)

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
- **PDF** — one landscape page per slide, same HTML interpretation as PPTX, with embedded Unicode system font (full Vietnamese support)
- **HTML** — standalone browser deck with keyboard/touch navigation, progress bar, fullscreen

### 3. **Live Preview & Present Mode**
- Live rendered preview beside the HTML editor (WebView2)
- Per-slide preview dialog in the slide list
- **Present mode**: fullscreen in-app playback (arrow keys, progress bar, Esc to exit)

### 4. **Slide Transition Effects**
14 transition effects (fade, push, wipe, split, blinds, clock, zoom, etc.) — deck-wide default plus per-slide overrides.

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
5 bundled templates (Business, Creative, Academic, Marketing, Minimal) with recommended transitions and accent colors.

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
├── models/
│   ├── slide.dart                      # Typed Slide model + SlideEffect enum
│   └── slide_template.dart             # Slide template model
├── providers/
│   ├── app_provider.dart               # Tab navigation + theme state
│   ├── presentation_state.dart         # Slide CRUD + effects + exports (PPTX/HTML/PDF) + undo/redo
│   ├── ai_provider_manager.dart        # Providers (OpenAI/Anthropic/Gemini/Ollama) + streaming + outline
│   └── config_service.dart             # Persistence (secure + SharedPreferences)
├── screens/
│   ├── home_screen.dart                # 5-destination NavigationBar + command palette
│   ├── html_to_ppt_screen.dart         # HTML editor + live preview + slide list + export
│   ├── ai_chat_screen.dart             # AI chat + streaming + outline mode
│   ├── effects_screen.dart             # Animation preview + PPTX transition picker
│   ├── present_screen.dart             # Fullscreen in-app present mode (WebView2)
│   ├── recent_projects_screen.dart     # .ghita project management
│   ├── template_studio_screen.dart     # Template gallery
│   ├── settings_screen.dart            # Theme, API keys, editor prefs, shortcuts
│   ├── provider_settings_screen.dart   # Provider ping, model fetch, key rotation
│   └── widgets/
│       ├── slide_preview.dart          # WebView2 slide preview widget
│       ├── wysiwyg_toolbar.dart        # Visual formatting toolbar
│       ├── slide_ai_tools_dialog.dart  # Per-slide AI tools (rewrite, notes, translate)
│       ├── command_palette_dialog.dart # Ctrl+K quick actions
│       └── shortcuts_help_dialog.dart  # Keyboard shortcuts cheat sheet
├── services/
│   ├── ppt_generator.dart              # PPTX OOXML builder (images, notes, links, theme)
│   ├── pdf_export_service.dart         # PDF export (pdf package, Unicode font)
│   ├── html_export_service.dart        # Standalone HTML deck export
│   ├── html_image_loader.dart          # Image loading for exports (base64/local)
│   ├── project_bundle_service.dart     # .ghita ZIP bundle (manifest, slides, history, media)
│   ├── smart_draft_manager.dart        # Auto-save drafts, purge after official save
│   ├── time_machine_history_service.dart # Undo/redo snapshot tree
│   ├── local_ai_detector_service.dart  # Auto-discover Ollama/LM Studio/vLLM
│   ├── api_fallback_cascade_service.dart # Ping latency + provider fallback
│   ├── template_service.dart           # Template asset loader
│   ├── document_importer_service.dart  # Markdown/HTML/URL importer
│   ├── mermaid_diagram_service.dart    # Mermaid diagram HTML blocks
│   └── wifi_broadcaster_service.dart   # Live Wi-Fi HTTP broadcaster
assets/
├── config/
│   └── providers.json                  # AI provider templates (no API keys)
├── templates/                          # 5 HTML slide templates + manifest
└── images/
    └── app_logo.png
test/
├── ppt_generator_test.dart             # PPTX engine + regression tests
├── pdf_export_test.dart                # PDF export tests
├── ai_provider_test.dart               # SSE parsing, outline JSON, provider validation
├── slide_model_test.dart               # Slide model round-trip tests
├── html_export_test.dart               # HTML deck export tests
├── slide_template_test.dart            # Template + provider config tests
├── document_importer_test.dart         # Document importer tests
├── time_machine_history_test.dart      # History service tests
└── widget_test.dart                    # Placeholder widget tests
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
```

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

It produces a per-user x64 installer plus a SHA-256 checksum and release
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

## What's New in v0.7.2

| Category | Feature |
|----------|---------|
| 🐛 Fixes | removeSlide undo fix, loadProjectFromFile cast fix, notes lang fix, port fallback for broadcaster, version drift fix |
| ⚡ Perf | Debounced auto-save, PPTX generation isolate offload, single-pass HTML parse |
| 🎨 UX | exportStatus auto-reset, outline editor dispose fix, clearSlides undo snackbar |
| 🧹 Cleanup | Removed unused material_color_utilities dependency |

## What's New in v0.7.0

| Category | Feature |
|----------|---------|
| 🛡️ Auto-Save | Smart draft manager with automatic purge after official save |
| 📦 Projects | .ghita project bundles with manifest, slides, history, media |
| ⏳ History | Undo/redo time machine with 30-snapshot limit |
| ⚙️ Settings | Dedicated settings tab with theme, API vault, editor prefs |
| 🤖 AI Hub | Provider connection wizard with ping, model fetch, key rotation |
| 🔍 Discovery | Auto-detect local AI services (Ollama, LM Studio, vLLM) |
| 🎨 WYSIWYG | Visual formatting toolbar (bold, italic, lists, tables, callouts) |
| 🤖 Per-Slide AI | Rewrite, speaker notes, translate per slide |
| 📋 Templates | Template studio with 5 style presets |
| 🎙️ Broadcaster | Wi-Fi live presentation with auto port fallback |
| 📁 Projects | Recent projects hub with search and hashtag tagging |
| ⌨️ Shortcuts | Command Palette (Ctrl+K) and shortcuts cheat sheet |

See [CHANGELOG.md](CHANGELOG.md) for full details.

## Security Note
API keys for AI providers are stored using `flutter_secure_storage` (encrypted keychain on each platform). No API keys are written to `SharedPreferences` or committed to version control. Local providers (Ollama) don't require an API key.

## License
MIT
