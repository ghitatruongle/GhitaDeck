/// Extended save formats (Track 44, FEAT 72/73).
///
///  * **.potx** / **.ppsx** — the PPTX package is identical except the main
///    part's content type (template / slideshow) and the file extension.
///    [rewritePackageType] post-processes the PPTX bytes so PowerPoint
///    recognises the package correctly on open.
///  * **.ppt (97–2003)** — requires a conversion engine; [LibreOffice] is
///    detected on the machine and driven headless. When neither LibreOffice
///    nor PowerPoint automation is available the service reports a clear
///    warning instead of emitting a fake legacy file.
library;

import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';

/// The three Office Open XML presentation "flavours" the app can save.
enum OoxmlDeckKind { presentation, template, slideshow }

class PackageFormatService {
  PackageFormatService._();

  /// File extension for a kind.
  static String extensionFor(OoxmlDeckKind kind) => switch (kind) {
        OoxmlDeckKind.presentation => 'pptx',
        OoxmlDeckKind.template => 'potx',
        OoxmlDeckKind.slideshow => 'ppsx',
      };

  /// Main-part content type for a kind.
  static String contentTypeFor(OoxmlDeckKind kind) => switch (kind) {
        OoxmlDeckKind.presentation =>
          'application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml',
        OoxmlDeckKind.template =>
          'application/vnd.openxmlformats-officedocument.presentationml.template.main+xml',
        OoxmlDeckKind.slideshow =>
          'application/vnd.openxmlformats-officedocument.presentationml.slideshow.main+xml',
      };

  /// Rewrite the PPTX package bytes for [kind]: the only part that differs
  /// is the `[Content_Types].xml` Override for `/ppt/presentation.xml`.
  /// Returns null on malformed input.
  static Uint8List? rewritePackageType(
      Uint8List pptxBytes, OoxmlDeckKind kind) {
    try {
      final decoded = ZipDecoder().decodeBytes(pptxBytes);
      final out = Archive();
      var rewrote = false;
      for (final file in decoded.files) {
        if (file.isFile) {
          var content = file.content;
          if (file.name == '[Content_Types].xml') {
            final text = _latin1(content);
            final updated = _replaceContentType(text, kind);
            if (updated != text) {
              content = updated.codeUnits;
              rewrote = true;
            }
          }
          out.addFile(ArchiveFile(file.name, content.length, content));
        }
      }
      if (!rewrote) return null;
      return Uint8List.fromList(ZipEncoder().encode(out)!);
    } catch (_) {
      return null;
    }
  }

  static String _latin1(dynamic content) {
    if (content is String) return content;
    return String.fromCharCodes(content as List<int>);
  }

  /// Replace the presentation Override content type (case-insensitive
  /// PartName match). Returns the input when nothing changed.
  static String _replaceContentType(String xml, OoxmlDeckKind kind) {
    final target = contentTypeFor(kind);
    final re = RegExp(
      r'(<Override\s+PartName="/ppt/presentation\.xml"\s+ContentType=")[^"]*(")',
      caseSensitive: false,
    );
    return xml.replaceAllMapped(re, (m) => '${m[1]}$target${m[2]}');
  }

  // ---- Legacy .ppt via LibreOffice ---------------------------------------

  /// Candidate LibreOffice/OpenOffice executables (Windows + common UNIX).
  static const List<String> _sofficeCandidates = [
    r'C:\Program Files\LibreOffice\program\soffice.exe',
    r'C:\Program Files (x86)\LibreOffice\program\soffice.exe',
    'soffice',
    'libreoffice',
  ];

  /// Locate a LibreOffice binary (override for tests via [probe]).
  static String? Function()? binaryProbe;

  static Future<String?> _findSoffice() async {
    final probe = binaryProbe;
    if (probe != null) return probe();
    for (final candidate in _sofficeCandidates) {
      try {
        final r = await Process.run(candidate, ['--version'])
            .timeout(const Duration(seconds: 5));
        if (r.exitCode == 0) return candidate;
      } catch (_) {}
    }
    return null;
  }

  /// Convert a .pptx to legacy .ppt via LibreOffice headless. Returns the
  /// output path, or throws [StateError] when LibreOffice is unavailable.
  static Future<String> convertToPpt(
    String pptxPath,
    String outputDir, {
    String? soffice,
  }) async {
    final binary = soffice ?? await _findSoffice();
    if (binary == null) {
      throw StateError(
          'LibreOffice not found — .ppt export needs LibreOffice '
          '(or save .pptx and use PowerPoint to Save As .ppt).');
    }
    final dir = Directory(outputDir);
    await dir.create(recursive: true);
    final result = await Process.run(binary, [
      '--headless',
      '--convert-to',
      'ppt',
      '--outdir',
      dir.path,
      pptxPath,
    ]);
    if (result.exitCode != 0) {
      throw StateError('LibreOffice conversion failed: ${result.stderr}');
    }
    final base = pptxPath.split(Platform.pathSeparator).last;
    final name = base.endsWith('.pptx')
        ? base.substring(0, base.length - 5)
        : base;
    final out = '${dir.path}${Platform.pathSeparator}$name.ppt';
    if (!File(out).existsSync()) {
      throw StateError('LibreOffice did not produce $out');
    }
    return out;
  }
}
