import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class LegacyPathMigration {
  LegacyPathMigration._();

  static const String _legacyPrefsDirName = 'GhitaPPT Converter';
  static const String _legacyDataDirName = 'GhitaPPT';
  static const String _dataDirName = 'GhitaDeck';
  static const String _legacyDraftPointer = 'ghita_ppt_unsaved_draft.json';
  static const String _legacyDraftSlides = 'ghita_ppt_unsaved_draft.slides.json';
  static const String _draftPointer = 'ghita_deck_unsaved_draft.json';
  static const String _draftSlides = 'ghita_deck_unsaved_draft.slides.json';

  static Future<void> run() async {
    if (!Platform.isWindows) return;
    try {
      await _migrateSupportDir();
      await _migrateDocumentsDir();
    } catch (_) {}
  }

  static Future<void> _migrateSupportDir() async {
    final appdata = Platform.environment['APPDATA'];
    if (appdata == null || appdata.isEmpty) return;
    final legacy = Directory(p.join(appdata, 'Ghita', _legacyPrefsDirName));
    if (!legacy.existsSync()) return;
    final support = await getApplicationSupportDirectory();
    final target = Directory(support.path);
    if (!target.existsSync()) {
      _renameDir(legacy, target);
      return;
    }
    if (_mergeDir(legacy, target)) {
      _deleteQuietly(legacy);
    }
  }

  static Future<void> _migrateDocumentsDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final legacy = Directory(p.join(docs.path, _legacyDataDirName));
    if (!legacy.existsSync()) return;
    final target = Directory(p.join(docs.path, _dataDirName));
    if (!target.existsSync()) {
      _renameDir(legacy, target);
    } else if (_mergeDir(legacy, target)) {
      _deleteQuietly(legacy);
    }
    _renameLegacyDraftFiles(target);
  }

  static void _renameDir(Directory from, Directory to) {
    try {
      from.renameSync(to.path);
    } on FileSystemException {
      if (_mergeDir(from, to)) {
        _deleteQuietly(from);
      }
    }
  }

  static bool _mergeDir(Directory from, Directory to) {
    var allCopied = true;
    try {
      to.createSync(recursive: true);
      for (final entity
          in from.listSync(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        final rel = p.relative(entity.path, from: from.path);
        final dest = p.join(to.path, rel);
        if (File(dest).existsSync()) continue;
        Directory(p.dirname(dest)).createSync(recursive: true);
        try {
          entity.copySync(dest);
        } catch (_) {
          allCopied = false;
        }
      }
    } catch (_) {
      return false;
    }
    return allCopied;
  }

  static void _renameLegacyDraftFiles(Directory dataDir) {
    final drafts = Directory(p.join(dataDir.path, 'drafts'));
    if (!drafts.existsSync()) return;
    _renameFile(drafts, _legacyDraftPointer, _draftPointer);
    _renameFile(drafts, _legacyDraftSlides, _draftSlides);
  }

  static void _renameFile(Directory dir, String from, String to) {
    final src = File(p.join(dir.path, from));
    if (!src.existsSync()) return;
    final dst = File(p.join(dir.path, to));
    if (dst.existsSync()) return;
    try {
      src.renameSync(dst.path);
    } catch (_) {}
  }

  static void _deleteQuietly(Directory dir) {
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {}
  }
}
