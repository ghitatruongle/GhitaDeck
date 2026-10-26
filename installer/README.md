# Installer — GhitaDeck

Everything in this folder builds and verifies the Windows installer.

## Build

```powershell
flutter build windows --release          # required first (the .iss packs that output)
./installer/build_installer.ps1 -Clean
```

Produces in `installer/output/`:

| File | Purpose |
|---|---|
| `GhitaDeck-Setup-<version>.exe` | x64 installer |
| `GhitaDeck-Setup-<version>.sha256` | checksum for distribution |
| `GhitaDeck-Setup-<version>.release.json` | manifest (version, hashes, signature status, source revision) |

Version numbers come from `pubspec.yaml` — never edit them in the `.iss`.

## Install options (T18)

| Option | Default | Notes |
|---|---|---|
| Install location | `Program Files\GhitaDeck` | The directory page is **always shown**; on upgrade the previously chosen directory is offered |
| Per-user install (no admin) | off | Requires the wizard's "install for me only" choice; works on standard accounts |
| Desktop shortcut | **off** (opt-in) | Tasks page |
| Start with Windows | **off** (opt-in) | Writes `HKCU\...\Run` only when ticked; removed on uninstall |
| Free-space check | 300 MB | Warns (does not block) before copying if the drive is low |

Installer runs in **admin mode** by default (Program Files). Windows shows one
UAC prompt. The wizard language defaults to **Vietnamese**; English is
selectable.

## Uninstall — what gets removed, what is kept

The installer separates two data groups. **This is a contract with the user.**

### Group A — your data (KEPT by default)

| Location | Contents |
|---|---|
| `Documents\GhitaDeck\decks` | saved decks |
| `Documents\GhitaDeck\audio` | slide narration recordings |
| `Documents\GhitaDeck\drafts` | auto-saved drafts (may hold unsaved work) |
| `%APPDATA%\Ghita\GhitaDeck\shared_preferences.json` | settings, theme, shortcuts |
| `%APPDATA%\Ghita\GhitaDeck\flutter_secure_storage.dat` | **AI provider API keys** |
| `Documents\GhitaPPT\*`, `%APPDATA%\Ghita\GhitaPPT Converter\*` | pre-rename locations — moved to the rows above automatically on first launch |

The pre-rename "GhitaPPT" locations are migrated to the `GhitaDeck` locations on
first launch of a renamed build (folders renamed when the target is empty, merged
file-by-file otherwise). Both name sets are listed in Group A and both are
removed when the user opts into deleting their data.

### Group B — regenerable data (ALWAYS removed)

| Location | Contents |
|---|---|
| `%LOCALAPPDATA%\GhitaDeck\image_cache` | processed-image cache |
| `%APPDATA%\GhitaDeck\engine.log` | engine audit log |
| `%LOCALAPPDATA%\GhitaPPT\image_cache`, `%APPDATA%\GhitaPPT\engine.log` | pre-rename leftovers, cleaned too |

### Uninstall flows

- **Normal uninstall** → removes the app, shortcuts, registry entries and
  **Group B**. Group A is untouched; reinstalling brings your projects,
  settings and API keys back.
- **"Also delete all my data"** → the confirmation dialog asks explicitly
  (default answer is *keep*); choosing *yes* also removes Group A. Silent
  uninstalls (`/VERYSILENT`) **always keep** Group A — unattended runs never
  destroy documents.

## Verify

```powershell
./installer/verify_release.ps1 -SmokeInstall -SmokeLaunch
```

Checks the manifest/checksums/signature status, then optionally installs to a
temp dir and asserts:

- the installed tree contains the exe, DLLs, Flutter assets and the uninstaller;
- the installed exe reports the expected product/version;
- auto-start stays off when the task was not selected;
- after a default uninstall: installation directory gone, **Group A markers
  survive**, **Group B markers are cleaned**, Run key removed.

## Signature status

Artifacts are **NotSigned** unless a certificate thumbprint is supplied:

```powershell
./installer/build_installer.ps1 -SigningCertificateThumbprint <SHA1>
```

Unsigned installers trigger SmartScreen ("Windows protected your PC") — choose
*More info* → *Run anyway*. This is expected and unchanged from earlier
releases.

## Uninstall from the command line

```powershell
./installer/uninstall.ps1            # finds the registered uninstaller
./installer/uninstall.ps1 -Silent    # unattended (keeps your data)
```
