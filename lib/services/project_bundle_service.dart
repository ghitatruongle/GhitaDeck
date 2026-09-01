import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/slide.dart';
import '../config/build_info.dart';
import 'html_sanitizer_service.dart';
import 'zip_codec.dart';

/// Service for packing and unpacking `.ghita` project bundle files.
/// A `.ghita` file is an encoded ZIP archive containing:
/// - `manifest.json` (metadata, title, author, version, ratio)
/// - `slides.json` (slides content, notes, effects, tags)
/// - `history.json` (version snapshot history)
/// - `media/` (embedded offline assets — Track 13: narration audio)
class ProjectBundleService {
  /// One binary asset to embed under `media/` (Track 13, P8).
  static const String mediaDir = 'media';
  static const int maxBundleBytes = 256 * 1024 * 1024;
  static const int maxUncompressedBytes = 512 * 1024 * 1024;
  static const int maxJsonEntryBytes = 64 * 1024 * 1024;
  static const int maxMediaEntryBytes = 128 * 1024 * 1024;
  static const int maxArchiveEntries = 2048;
  static const int maxSlides = 1000;
  static const Set<String> _allowedMediaExtensions = {
    '.aac',
    '.flac',
    '.m4a',
    '.mp3',
    '.ogg',
    '.wav',
  };

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
    int schemaVersion = BuildInfo.bundleSchemaVersion,
    Map<String, dynamic>? extraManifest,
    List<Map<String, dynamic>>? historySnapshots,
    List<MapEntry<String, Uint8List>>? mediaFiles,
    Map<String, String>? mediaPathNames,
    // T02: true → ZipCodec picks Rust ghita_zip (with Dart fallback).
    bool useEngineZip = false,
  }) async {
    try {
      if (slides.length > maxSlides) return false;
      final archive = Archive();

      // 1. Manifest
      final manifestMap = {
        if (extraManifest != null) ...extraManifest,
        'appName': BuildInfo.productName,
        'version': BuildInfo.appVersion,
        'appVersion': BuildInfo.appVersion,
        'schemaVersion': schemaVersion,
        'title': title,
        'author': author,
        'aspectRatio': aspectRatio,
        'createdAt': DateTime.now().toIso8601String(),
        'slideCount': slides.length,
        if (mediaFiles != null && mediaFiles.isNotEmpty)
          'mediaCount': mediaFiles.length,
      };
      final manifestBytes = utf8.encode(jsonEncode(manifestMap));
      archive.addFile(
          ArchiveFile('manifest.json', manifestBytes.length, manifestBytes));

      // 2. Slides (audioPath rewritten to the bundle-relative media name)
      final slidesList = slides.map((s) {
        var map = s.toMap();
        final audioPath = map['audioPath'];
        if (audioPath is String && audioPath.isNotEmpty) {
          final name = mediaPathNames?[audioPath] ?? p.basename(audioPath);
          if (mediaFiles?.any((e) => e.key == name) ?? false) {
            map['audioPath'] = '$mediaDir/$name';
            map['audioEmbedded'] = true;
          }
        }
        return map;
      }).toList();
      final slidesBytes = utf8.encode(jsonEncode(slidesList));
      archive
          .addFile(ArchiveFile('slides.json', slidesBytes.length, slidesBytes));

      // 3. History
      final historyList = historySnapshots ?? [];
      final historyBytes = utf8.encode(jsonEncode(historyList));
      archive.addFile(
          ArchiveFile('history.json', historyBytes.length, historyBytes));

      // 4. Embedded media (Track 13, P8)
      final mediaNames = <String>{};
      for (final entry in mediaFiles ?? const <MapEntry<String, Uint8List>>[]) {
        final name = entry.key;
        if (name.isEmpty ||
            p.basename(name) != name ||
            !_allowedMediaExtensions
                .contains(p.extension(name).toLowerCase()) ||
            entry.value.length > maxMediaEntryBytes ||
            !mediaNames.add(name)) {
          throw const FormatException('Unsafe embedded media entry.');
        }
        archive.addFile(
            ArchiveFile('$mediaDir/$name', entry.value.length, entry.value));
      }

      // 5. Encode ZIP & Write File
      final zipBytes = useEngineZip
          ? await ZipCodec.encode(ZipCodec.fromArchive(archive))
          : ZipEncoder().encode(archive);
      if (zipBytes != null) {
        if (zipBytes.length > maxBundleBytes) return false;
        final outputFile = File(targetPath);
        // Ensure the target directory exists — writeAsBytes otherwise throws
        // when saving into a folder that doesn't exist yet, and the caller
        // only learns about it via the generic "false" return.
        await outputFile.parent.create(recursive: true);
        await _replaceAtomically(outputFile, zipBytes);
        debugPrint('ProjectBundleService: Saved .ghita bundle to $targetPath');
        return true;
      }
    } catch (e) {
      debugPrint('ProjectBundleService Error saving bundle: $e');
    }
    return false;
  }

  Future<void> _replaceAtomically(File outputFile, List<int> bytes) async {
    final nonce = '${pid}_${DateTime.now().microsecondsSinceEpoch}';
    final tempFile = File('${outputFile.path}.$nonce.tmp');
    File? backupFile;
    try {
      await tempFile.writeAsBytes(bytes, flush: true);
      if (await outputFile.exists()) {
        backupFile = File('${outputFile.path}.$nonce.bak');
        await outputFile.rename(backupFile.path);
      }
      try {
        await tempFile.rename(outputFile.path);
      } catch (_) {
        if (backupFile != null &&
            await backupFile.exists() &&
            !await outputFile.exists()) {
          await backupFile.rename(outputFile.path);
        }
        rethrow;
      }
      if (backupFile != null && await backupFile.exists()) {
        await backupFile.delete();
      }
    } finally {
      if (await tempFile.exists()) await tempFile.delete();
    }
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
      final compressedSize = await file.length();
      if (compressedSize <= 0 || compressedSize > maxBundleBytes) {
        throw const FormatException('Project bundle size is outside limits.');
      }

      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      if (archive.files.length > maxArchiveEntries) {
        throw const FormatException(
            'Project bundle contains too many entries.');
      }
      var expandedSize = 0;
      for (final entry in archive.files) {
        expandedSize += entry.size;
        if (entry.size < 0 || expandedSize > maxUncompressedBytes) {
          throw const FormatException('Project bundle expands beyond limits.');
        }
        if ((entry.name == 'manifest.json' ||
                entry.name == 'slides.json' ||
                entry.name == 'history.json') &&
            entry.size > maxJsonEntryBytes) {
          throw const FormatException('Project metadata is too large.');
        }
        if (entry.name.startsWith('$mediaDir/') &&
            entry.size > maxMediaEntryBytes) {
          throw const FormatException('Embedded media is too large.');
        }
      }

      Map<String, dynamic>? manifest;
      List<Slide> slides = [];
      List<Map<String, dynamic>> history = [];
      var manifestSeen = false;
      var slidesSeen = false;
      var historySeen = false;
      // Track 13, P8: media entries are extracted to the narration dir so
      // slides referencing `media/<name>` resolve to a real local file.
      final mediaFiles = <String, String>{};
      final mediaSeen = <String>{};

      for (final archiveFile in archive) {
        if (archiveFile.isFile) {
          if (archiveFile.name == 'manifest.json') {
            if (manifestSeen) {
              throw const FormatException('Duplicate manifest.json entry.');
            }
            manifestSeen = true;
            final content = utf8.decode(archiveFile.content as List<int>);
            manifest = jsonDecode(content) as Map<String, dynamic>;
          } else if (archiveFile.name == 'slides.json') {
            if (slidesSeen) {
              throw const FormatException('Duplicate slides.json entry.');
            }
            slidesSeen = true;
            final content = utf8.decode(archiveFile.content as List<int>);
            final rawList = jsonDecode(content) as List;
            if (rawList.length > maxSlides) {
              throw const FormatException('Project contains too many slides.');
            }
            slides = rawList
                .map((e) => Slide.fromMap(Map<String, dynamic>.from(e as Map)))
                .map((slide) => slide.copyWith(
htmlContent: HtmlSanitizerService.sanitize(slide.htmlContent).html,
                    ))
                .toList();
          } else if (archiveFile.name == 'history.json') {
            if (historySeen) {
              throw const FormatException('Duplicate history.json entry.');
            }
            historySeen = true;
            final content = utf8.decode(archiveFile.content as List<int>);
            final rawList = jsonDecode(content) as List;
            history = rawList
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
          } else if (archiveFile.name.startsWith('$mediaDir/')) {
            final relativeName =
                archiveFile.name.substring('$mediaDir/'.length);
            if (relativeName.isEmpty ||
                p.basename(relativeName) != relativeName ||
                !mediaSeen.add(relativeName) ||
                !_allowedMediaExtensions
                    .contains(p.extension(relativeName).toLowerCase())) {
              throw const FormatException('Unsafe embedded media entry.');
            }
            final content = List<int>.from(archiveFile.content as List<int>);
            final digest = crypto.sha256.convert(content).toString();
            final extension = p.extension(relativeName);
            final stem = p.basenameWithoutExtension(relativeName);
            final name = '$stem-${digest.substring(0, 12)}$extension';
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
            await File(outPath).writeAsBytes(content, flush: true);
            mediaFiles[relativeName] = outPath;
          }
        }
      }

      if (!slidesSeen) {
        throw const FormatException('Project bundle has no slides.json.');
      }

      // Bundles without schemaVersion are legacy schema 1 documents. They are
      // still accepted, while future schemas are rejected rather than being
      // silently misread.
      final rawSchemaVersion = manifest?['schemaVersion'];
      final schemaVersion = rawSchemaVersion is num
          ? rawSchemaVersion.toInt()
          : int.tryParse(rawSchemaVersion?.toString() ?? '') ?? 1;
      if (schemaVersion > BuildInfo.bundleSchemaVersion) {
        throw FormatException(
          'Project bundle schema $schemaVersion is newer than supported '
          '${BuildInfo.bundleSchemaVersion}.',
        );
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
