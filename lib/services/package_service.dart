/// Deck packaging (Track 45, FEAT 74).
///
/// Exports a distributable folder: `deck.pptx` + a `media/` folder with the
/// deck's embedded images/audio/video extracted as real files (the
/// PowerPoint "link media" distribution pattern) + a README.txt describing
/// the contents. Optionally everything is zipped into a single archive.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';

import 'ppt_generator.dart';

/// One extracted media file.
class PackagedMedia {
  final String sourceName;
  final String filePath;
  final int bytes;

  const PackagedMedia({
    required this.sourceName,
    required this.filePath,
    required this.bytes,
  });
}

class PackageResult {
  final String outputDir;
  final List<PackagedMedia> media;
  final String? zipPath;

  const PackageResult({
    required this.outputDir,
    required this.media,
    this.zipPath,
  });
}

class PackageService {
  PackageService._();

  static final RegExp _mediaRe = RegExp(
      r'data:(image|audio|video)/([a-z0-9.+-]+);base64,([A-Za-z0-9+/=]+)');
  static final RegExp _extCleanRe = RegExp(r'[^a-z0-9]');

  /// Scan [html] for `data:image|audio|video;base64,…` URIs and return
  /// (mime, bytes) pairs in document order.
  static List<(String, Uint8List)> mediaInHtml(String html) {
    final result = <(String, Uint8List)>[];
    final re = _mediaRe;
    for (final m in re.allMatches(html)) {
      final mime = '${m[1]}/${m[2]}';
      try {
        final bytes = base64Decode(m.group(3)!);
        result.add((mime, Uint8List.fromList(bytes)));
      } catch (_) {}
    }
    return result;
  }

  /// Media count + total bytes across a deck.
  static (int count, int totalBytes) deckMediaStats(
      List<Map<String, dynamic>> slides) {
    var count = 0;
    var total = 0;
    for (final slide in slides) {
      final media = mediaInHtml((slide['htmlContent'] ?? '').toString());
      count += media.length;
      total += media.fold(0, (s, m) => s + m.$2.length);
    }
    return (count, total);
  }

  static String _extFor(String mime) {
    if (mime == 'image/jpeg') return 'jpg';
    if (mime == 'image/png') return 'png';
    if (mime == 'image/gif') return 'gif';
    if (mime == 'audio/mp4' || mime == 'audio/m4a') return 'm4a';
    if (mime == 'audio/wav') return 'wav';
    if (mime == 'video/mp4') return 'mp4';
    final clean = mime.split('/').last.replaceAll(_extCleanRe, '');
    return clean.isEmpty ? 'bin' : clean;
  }

  /// Package [slides]: generate `deck.pptx`, extract media into `media/`,
  /// write `README.txt`, and optionally zip everything.
  static Future<PackageResult> packageDeck(
    List<Map<String, dynamic>> slides,
    String outputDir, {
    String deckName = 'deck',
    bool createZip = false,
  }) async {
    final dir = Directory(outputDir);
    await dir.create(recursive: true);
    final mediaDir = Directory('${dir.path}${Platform.pathSeparator}media');
    await mediaDir.create(recursive: true);

    // 1. Generate the PPTX next to the folder.
    final pptxPath = '${dir.path}${Platform.pathSeparator}$deckName.pptx';
    await PPTGenerator.generatePPT(slides, pptxPath);

    // 2. Extract media.
    final media = <PackagedMedia>[];
    var counter = 0;
    for (final slide in slides) {
      final html = (slide['htmlContent'] ?? '').toString();
      for (final (mime, bytes) in mediaInHtml(html)) {
        counter++;
        final ext = _extFor(mime);
        final name = 'media_$counter.$ext';
        final path = '${mediaDir.path}${Platform.pathSeparator}$name';
        await File(path).writeAsBytes(bytes, flush: true);
        media.add(PackagedMedia(
            sourceName: name, filePath: path, bytes: bytes.length));
      }
    }

    // 3. README.txt
    final readme = _readme(slides, media, deckName);
    await File('${dir.path}${Platform.pathSeparator}README.txt')
        .writeAsString(readme, flush: true);

    String? zipPath;
    if (createZip) {
      zipPath = '${dir.path}${Platform.pathSeparator}$deckName.zip';
      await _zipDir(dir, zipPath);
    }
    return PackageResult(outputDir: dir.path, media: media, zipPath: zipPath);
  }

  static String _readme(
      List<Map<String, dynamic>> slides, List<PackagedMedia> media, String deckName) {
    final b = StringBuffer()
      ..writeln('GhitaPPT — packaged deck "$deckName"')
      ..writeln('========================================')
      ..writeln('Slides : ${slides.length}')
      ..writeln('Media  : ${media.length} files (${_fmtBytes(media.fold<int>(0, (s, m) => s + m.bytes))})')
      ..writeln()
      ..writeln('Contents:')
      ..writeln('  $deckName.pptx — the presentation')
      ..writeln('  media/        — images/audio/video referenced by the deck')
      ..writeln('  This file     — package manifest');
    if (media.isNotEmpty) {
      b.writeln();
      b.writeln('Media files:');
      for (final m in media) {
        b.writeln('  ${m.sourceName}  (${_fmtBytes(m.bytes)})');
      }
    }
    return b.toString();
  }

  static String _fmtBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  static Future<void> _zipDir(Directory dir, String outPath) async {
    final archive = Archive();
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        final bytes = await entity.readAsBytes();
        final rel = entity.path.substring(dir.path.length + 1)
            .replaceAll('\\', '/');
        archive.addFile(ArchiveFile(rel, bytes.length, bytes));
      }
    }
    final encoded = ZipEncoder().encode(archive);
    if (encoded == null) throw StateError('ZIP encoding failed');
    final file = File(outPath);
    await file.writeAsBytes(encoded, flush: true);
  }
}
