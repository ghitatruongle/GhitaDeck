import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// T18 (2026-09-03) — installer/uninstaller contract.
///
/// These are static checks over `installer/ghita_deck_installer.iss`: the real
/// install/uninstall behaviour is asserted by `verify_release.ps1 -SmokeInstall`
/// (see installer/README.md). Keeping the data-group contract pinned here means
/// a future edit to the .iss cannot silently start deleting user data.
void main() {
  late String iss;

  setUpAll(() {
    final file = File('installer/ghita_deck_installer.iss');
    expect(file.existsSync(), isTrue,
        reason: 'installer definition must exist at ${file.path}');
    iss = file.readAsStringSync();
  });

  group('T18 installer contract', () {
    test('rename continuity: AppId stays the pre-rename GUID', () {
      expect(
        iss,
        contains(r'AppId={{A3F8E1C2-5B7D-4E9A-B6C1-2D3F4A5B6C7D}'),
        reason: 'changing the AppId turns the rename into a second, '
            'parallel app: existing GhitaPPT Converter installs would '
            'no longer be detected, upgraded over, or uninstalled by '
            'the new setup',
      );
    });

    test('rename continuity: setup clears the legacy auto-start value', () {
      expect(iss, contains("'GhitaPPT Converter'"),
          reason: 'the pre-rename Run value points at the old exe name '
              'and must not survive an upgrade as a dead autostart link');
    });

    test('rename continuity: setup deletes the legacy exe and shortcuts', () {
      expect(iss, contains('[InstallDelete]'),
          reason: 'Inno only overwrites the files it ships; the pre-rename '
              'ghita_ppt_converter.exe and its Start Menu shortcuts have '
              'different names and would survive every upgrade otherwise');
      expect(iss, contains(r'{app}\ghita_ppt_converter.exe'));
      expect(iss, contains(r'{group}\GhitaPPT Converter.lnk'));
      expect(iss, contains(r'{group}\Uninstall GhitaPPT Converter.lnk'));
    });

    test('T18.2: directory page is always available for a custom location', () {
      expect(iss, contains('DisableDirPage=no'),
          reason: 'the user must be able to choose the install location');
      expect(iss, contains('UsePreviousAppDir=yes'),
          reason: 'an upgrade must offer the previously chosen directory');
      expect(iss, contains('PrivilegesRequiredOverridesAllowed=dialog'),
          reason: 'per-user install (no admin) must stay possible');
    });

    test('T18.3: auto-start is opt-in and therefore unchecked by default', () {
      final taskLine = RegExp(r'Name: "autostart".*')
          .firstMatch(iss)
          ?.group(0);
      expect(taskLine, isNotNull, reason: 'autostart task must exist');
      expect(taskLine, contains('Flags: unchecked'),
          reason: 'T18.3: auto-start must default OFF');
      expect(iss, contains('Software\\Microsoft\\Windows\\CurrentVersion\\Run'),
          reason: 'the opt-in task writes the Run key');
      expect(iss, contains('uninsdeletevalue'),
          reason: 'uninstall must remove the Run value');
    });

    test('T18.3: desktop shortcut defaults to off (previous behaviour)', () {
      final taskLine =
          RegExp(r'Name: "desktopicon".*').firstMatch(iss)?.group(0);
      expect(taskLine, contains('Flags: unchecked'));
    });

    test('T18.5: Group B (regenerable) is always cleaned on uninstall', () {
      expect(iss, contains(r'{localappdata}\GhitaPPT\image_cache'),
          reason: 'image cache must be removed');
      expect(iss, contains(r'{userappdata}\GhitaPPT\engine.log'),
          reason: 'engine log must be removed');
      expect(iss, contains(r'{localappdata}\GhitaDeck\image_cache'),
          reason: 'current-name image cache must be removed too');
      expect(iss, contains(r'{userappdata}\GhitaDeck\engine.log'),
          reason: 'current-name engine log must be removed too');
    });

    test('T18.4: Group A is guarded behind the explicit opt-in branch', () {
      // Documents (decks/audio/drafts) and preferences/API keys may only be
      // deleted inside the `if RemoveUserData then` block.
      final guardIndex = iss.indexOf('if RemoveUserData then');
      expect(guardIndex, greaterThan(0),
          reason: 'the opt-in guard must exist');

      final documentsDelete = iss.indexOf("{userdocs}\\GhitaDeck");
      final documentsLegacyDelete = iss.indexOf("{userdocs}\\GhitaPPT");
      final prefsDelete = iss.indexOf("{userappdata}\\Ghita\\GhitaDeck");
      final prefsLegacyDelete =
          iss.indexOf("{userappdata}\\Ghita\\GhitaPPT Converter");

      expect(documentsDelete, greaterThan(guardIndex),
          reason: 'T18.4: documents may only be deleted after the opt-in');
      expect(documentsLegacyDelete, greaterThan(guardIndex),
          reason: 'T18.4: legacy documents dir too');
      expect(prefsDelete, greaterThan(guardIndex),
          reason: 'T18.4: API keys/prefs may only be deleted after the opt-in');
      expect(prefsLegacyDelete, greaterThan(guardIndex),
          reason: 'T18.4: legacy prefs dir must not escape the opt-in');
    });

    test('rename: Group B paths sit before the Group A opt-in guard', () {
      final guardIndex = iss.indexOf('if RemoveUserData then');
      final groupBBlock =
          iss.substring(0, guardIndex).toLowerCase().contains('ghitappt');
      expect(groupBBlock, isTrue);
    });

    test('T18.4: the user-data prompt defaults to KEEP', () {
      // The dialog is a Yes/No whose "No" (keep) is the safe path; and a
      // silent uninstall must never set RemoveUserData.
      expect(iss, contains('RemoveUserData := False'),
          reason: 'default state is keep');
      expect(iss, contains('if not UninstallSilent then'),
          reason: 'silent uninstall must not even ask — and therefore keeps');
    });

    test('T18.6: the installer closes a running app instead of failing', () {
      expect(iss, contains('CloseApplications=yes'));
    });

    test('T18.3: a low-disk warning exists before copying', () {
      expect(iss, contains('GetSpaceOnDisk64'),
          reason: 'free-space precheck must run at startup');
    });
  });
}
