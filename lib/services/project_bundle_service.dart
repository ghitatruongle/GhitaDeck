import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/slide.dart';

/// Service for packing and unpacking `.ghita` project bundle files.
/// A `.ghita` file is an encoded ZIP archive containing:
/// - `manifest.json` (metadata, title, author, version, ratio)
/// - `slides.json` (slides content, notes, effects, tags)
/// - `history.json` (version snapshot history)
/// - `media/` (embedded offline assets — Track 13: narration audio)
class ProjectBundleService {
  /// One binary asset to embed under `media/` (Track 13, P8).
  static const String mediaDir = 'media';

  /// Packs a presentation into a `.ghita` bundle file at [targetPath].
  ///
  /// [mediaFiles] (name → bytes) are embedded under `media/`; slides that
  /// reference one of those names via `audioPath` travel as
  /// `media/<name>` + `audioEmbedded: true` so the bundle is self-contained
  /// and opens on another machine.
  Future<bool> saveProjectBundle({
    required String targetPath,
    required List<Slide> slides,
    String title = 'Untitled Presentation',
    String author = 'Ghita User',
    String aspectRatio = '16:9',
    Map<String, dynamic>? extraManifest,
    List<Map<String, dynamic>>? historySnapshots,
    List<MapEntry<String, Uint8List>>? mediaFiles,
  }) async {
    try {
      final archive = Archive();

      // 1. Manifest
      final manifestMap = {
        'appName': 'Ghita PowerPoint Converter',
        'version': '2.0.0-beta',
        'title': title,
        'author': author,
        'aspectRatio': aspectRatio,
        'createdAt': DateTime.now().toIso8601String(),
        'slideCount': slides.length,
        if (mediaFiles != null && mediaFiles.isNotEmpty)
          'mediaCount': mediaFiles.length,
        if (extraManifest != null) ...extraManifest,
      };
      final manifestBytes = utf8.encode(jsonEncode(manifestMap));
      archive.addFile(ArchiveFile('manifest.json', manifestBytes.length, manifestBytes));

      // 2. Slides (audioPath rewritten to the bundle-relative media name)
      final slidesList = slides.map((s) {
        var map = s.toMap();
        final audioPath = map['audioPath'];
        if (audioPath is String && audioPath.isNotEmpty) {
          final name = p.basename(audioPath);
          if (mediaFiles?.any((e) => e.key == name) ?? false) {
            map['audioPath'] = '$mediaDir/$name';
            map['audioEmbedded'] = true;
          }
        }
        return map;
      }).toList();
      final slidesBytes = utf8.encode(jsonEncode(slidesList));
      archive.addFile(ArchiveFile('slides.json', slidesBytes.length, slidesBytes));

      // 3. History
      final historyList = historySnapshots ?? [];
      final historyBytes = utf8.encode(jsonEncode(historyList));
      archive.addFile(ArchiveFile('history.json', historyBytes.length, historyBytes));

      // 4. Embedded media (Track 13, P8)
      for (final entry in mediaFiles ?? const <MapEntry<String, Uint8List>>[]) {
        archive.addFile(
            ArchiveFile('$mediaDir/${entry.key}', entry.value.length, entry.value));
      }

      // 5. Encode ZIP & Write File
      final encoder = ZipEncoder();
      final zipBytes = encoder.encode(archive);
      if (zipBytes != null) {
        final outputFile = File(targetPath);
        // Ensure the target directory exists — writeAsBytes otherwise throws
        // when saving into a folder that doesn't exist yet, and the caller
        // only learns about it via the generic "false" return.
        await outputFile.parent.create(recursive: true);
        await outputFile.writeAsBytes(zipBytes, flush: true);
        debugPrint('ProjectBundleService: Saved .ghita bundle to $targetPath');
        return true;
      }
    } catch (e) {
      debugPrint('ProjectBundleService Error saving bundle: $e');
    }
    return false;
  }

  /// Unpacks and loads a `.ghita` bundle file from [sourcePath]. Media
  /// entries are extracted to [extractDir] (default: the app documents
  /// `GhitaPPT/audio/` dir); tests inject a temp dir.
  Future<Map<String, dynamic>?> loadProjectBundle(
    String sourcePath, {
    String? extractDir,
  }) async {
    try {
      final file = File(sourcePath);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      Map<String, dynamic>? manifest;
      List<Slide> slides = [];
      List<Map<String, dynamic>> history = [];
      // Track 13, P8: media entries are extracted to the narration dir so
      // slides referencing `media/<name>` resolve to a real local file.
      final mediaFiles = <String, String>{};

      for (final archiveFile in archive) {
        if (archiveFile.isFile) {
          if (archiveFile.name == 'manifest.json') {
            final content = utf8.decode(archiveFile.content as List<int>);
            manifest = jsonDecode(content) as Map<String, dynamic>;
          } else if (archiveFile.name == 'slides.json') {
            final content = utf8.decode(archiveFile.content as List<int>);
            final rawList = jsonDecode(content) as List;
            slides = rawList
                .map((e) => Slide.fromMap(e as Map<String, dynamic>))
                .toList();
          } else if (archiveFile.name == 'history.json') {
            final content = utf8.decode(archiveFile.content as List<int>);
            final rawList = jsonDecode(content) as List;
            history = rawList
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
          } else if (archiveFile.name.startsWith('$mediaDir/')) {
            final name = p.basename(archiveFile.name);
            String dirPath = extractDir ?? '';
            if (dirPath.isEmpty) {
              final dir = await getApplicationDocumentsDirectory();
              dirPath = p.join(dir.path, 'GhitaPPT', 'audio');
            }
            final audioDir = Directory(dirPath);
            if (!await audioDir.exists()) {
              await audioDir.create(recursive: true);
            }
            final outPath = p.join(audioDir.path, name);
            await File(outPath).writeAsBytes(
                archiveFile.content as List<int>, flush: true);
            mediaFiles[name] = outPath;
          }
        }
      }

      // Rewrite slides whose audioPath is a bundle-relative media reference
      // to the extracted local file (keeps audioEmbedded so a later save
      // re-embeds them).
      if (mediaFiles.isNotEmpty) {
        slides = slides.map((slide) {
          final audioPath = slide.audioPath;
          if (audioPath.startsWith('$mediaDir/')) {
            final name = p.basename(audioPath);
            final local = mediaFiles[name];
            if (local != null) {
              return slide.copyWith(audioPath: local, audioEmbedded: true);
            }
          }
          return slide;
        }).toList();
      }

      return {
        'manifest': manifest ?? {},
        'slides': slides,
        'history': history,
        'filePath': sourcePath,
        'mediaFiles': mediaFiles,
      };
    } catch (e) {
      debugPrint('ProjectBundleService Error loading bundle: $e');
    }
    return null;
  }
}
