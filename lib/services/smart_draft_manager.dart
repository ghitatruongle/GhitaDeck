import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/slide.dart';

/// Smart Draft Manager — v1.2.0 + Track 65 (OPT 26/27).
///
/// Auto-saves an unsaved presentation into a recoverable draft sandbox so a
/// crash never loses work.
///
/// OPT 26 — drafts are only written when the deck is dirty (callers decide)
/// and are debounced by the presentation state.
///
/// OPT 27 — when the serialized slides alone exceed [_largeDeckThreshold]
/// (1 MB), the slides payload is spilled into a separate `*.slides.json`
/// file next to the pointer file; the pointer keeps only metadata + a count.
/// Reading a legacy draft (slides inline) still works.
class SmartDraftManager {
  static const String _draftFileName = 'ghita_ppt_unsaved_draft.json';
  static const String _slidesFileName = 'ghita_ppt_unsaved_draft.slides.json';

  /// 1 MB of JSON slides — beyond this the pointer file stays small.
  static const int _largeDeckThreshold = 1 << 20;

  Future<File> _getDraftFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final draftsDir = Directory(p.join(dir.path, 'GhitaPPT', 'drafts'));
    if (!await draftsDir.exists()) {
      await draftsDir.create(recursive: true);
    }
    return File(p.join(draftsDir.path, _draftFileName));
  }

  Future<File> _getSlidesFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final draftsDir = Directory(p.join(dir.path, 'GhitaPPT', 'drafts'));
    if (!await draftsDir.exists()) {
      await draftsDir.create(recursive: true);
    }
    return File(p.join(draftsDir.path, _slidesFileName));
  }

  /// Saves the current presentation slides & metadata to the temporary draft sandbox.
  Future<void> saveDraft(List<Slide> slides,
      {Map<String, dynamic>? metadata}) async {
    try {
      final file = await _getDraftFile();
      final slidesJson = jsonEncode(slides.map((s) => s.toMap()).toList());
      final draftData = <String, dynamic>{
        'version': '2.0.0',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'metadata': metadata ?? {},
      };

      if (utf8.encode(slidesJson).length > _largeDeckThreshold) {
        // OPT 27: big deck → spill slides to their own file, keep a pointer.
        final slidesFile = await _getSlidesFile();
        await slidesFile.writeAsString(slidesJson, flush: true);
        draftData['slidesFile'] = _slidesFileName;
        draftData['slideCount'] = slides.length;
      } else {
        draftData['slides'] = jsonDecode(slidesJson);
        // Remove any stale spill file from an earlier large save.
        final slidesFile = await _getSlidesFile();
        if (await slidesFile.exists()) {
          await slidesFile.delete();
        }
      }
      await file.writeAsString(jsonEncode(draftData), flush: true);
      debugPrint('SmartDraftManager: Draft auto-saved (${slides.length} slides)');
    } catch (e) {
      debugPrint('SmartDraftManager Error saving draft: $e');
    }
  }

  /// Checks whether an unsaved recoverable draft exists.
  Future<bool> hasRecoverableDraft() async {
    try {
      final file = await _getDraftFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final map = jsonDecode(content) as Map<String, dynamic>;
          // New large-deck format: pointer + external slides file.
          if (map.containsKey('slidesFile')) {
            final slidesFile = await _getSlidesFile();
            if (await slidesFile.exists()) {
              final raw = await slidesFile.readAsString();
              if (raw.trim().isNotEmpty) {
                return (jsonDecode(raw) as List).isNotEmpty;
              }
            }
            return false;
          }
          final slidesList = map['slides'] as List?;
          return slidesList != null && slidesList.isNotEmpty;
        }
      }
    } catch (e) {
      debugPrint('SmartDraftManager Error checking draft: $e');
    }
    return false;
  }

  /// Loads and returns the recoverable draft dataset, or null if none.
  /// Inline (legacy) and spilled (large-deck) formats are both supported.
  Future<Map<String, dynamic>?> loadRecoverableDraft() async {
    try {
      final file = await _getDraftFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final map = jsonDecode(content) as Map<String, dynamic>;
          if (map.containsKey('slidesFile')) {
            final slidesFile = await _getSlidesFile();
            if (await slidesFile.exists()) {
              final raw = await slidesFile.readAsString();
              map['slides'] = jsonDecode(raw) as List;
            } else {
              map['slides'] = <dynamic>[];
            }
          }
          return map;
        }
      }
    } catch (e) {
      debugPrint('SmartDraftManager Error loading draft: $e');
    }
    return null;
  }

  /// Purges (deletes) the draft file from the sandbox after an official save to `.ghita`.
  Future<void> purgeDraft() async {
    try {
      final file = await _getDraftFile();
      if (await file.exists()) {
        await file.delete();
      }
      final slidesFile = await _getSlidesFile();
      if (await slidesFile.exists()) {
        await slidesFile.delete();
      }
      debugPrint('SmartDraftManager: Unsaved draft purged cleanly from sandbox.');
    } catch (e) {
      debugPrint('SmartDraftManager Error purging draft: $e');
    }
  }
}
