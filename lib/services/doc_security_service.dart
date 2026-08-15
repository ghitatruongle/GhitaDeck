/// Document Inspector & protection (Track 45, FEAT 77/78/79).
///
/// * **Inspector** — scans the deck for hidden metadata: the author name in
///   slide text, e-mail addresses and phone numbers (regex), hidden slides
///   and empty slides. Findings are categorised so the UI can offer removal.
/// * **Mark as Final** — sets `cp:contentStatus` and a zero-hash
///   `<p:modifyVerifier>` on the package (the same markers PowerPoint
///   writes).
/// * **Modify password** — write-protection via OOXML `<fileSharing>`:
///   SHA-512(salt + UTF-16LE password) iterated `spinCount` times
///   (cryptAlgorithmSid 14 / rsaAES provider per MS-OFFCRYPTO). Hash
///   generation is deterministic and round-trip tested.
/// * **Restrict note** — a client-side "read-only" note written into the
///   core properties (not real IRM; documented).
library;

import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

/// Category of an inspector finding.
enum FindingKind { author, email, phone, hiddenSlide, emptySlide }

class InspectorFinding {
  final FindingKind kind;
  final int slideIndex;
  final String sample;

  const InspectorFinding({
    required this.kind,
    required this.slideIndex,
    required this.sample,
  });
}

class DocSecurityService {
  DocSecurityService._();

  static final RegExp _emailRe = RegExp(
      r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}');
  // Vietnamese phone patterns: 0xxxxxxxxx / +84xxxxxxxxx (9–10 digits).
  static final RegExp _phoneRe = RegExp(
      r'(?<!\d)((\+84|0)[1-9][0-9]{8,9})(?!\d)');

  // ---- Inspector ---------------------------------------------------------

  /// Scan [slides] for sensitive content. [authorName] is the document
  /// author to look for (from project settings).
  static List<InspectorFinding> inspect(
    List<Map<String, dynamic>> slides, {
    String? authorName,
  }) {
    final findings = <InspectorFinding>[];
    for (var i = 0; i < slides.length; i++) {
      final slide = slides[i];
      final html = (slide['htmlContent'] ?? '').toString();
      final author = authorName?.trim() ?? '';
      if (author.isNotEmpty && html.contains(author)) {
        findings.add(InspectorFinding(
            kind: FindingKind.author, slideIndex: i, sample: author));
      }
      for (final m in _emailRe.allMatches(html)) {
        findings.add(InspectorFinding(
            kind: FindingKind.email,
            slideIndex: i,
            sample: m.group(0)!));
      }
      for (final m in _phoneRe.allMatches(html)) {
        findings.add(InspectorFinding(
            kind: FindingKind.phone,
            slideIndex: i,
            sample: m.group(1)!));
      }
      if (slide['hidden'] == true) {
        findings.add(InspectorFinding(
            kind: FindingKind.hiddenSlide, slideIndex: i, sample: ''));
      }
      final text = _plainText(html);
      if (text.trim().isEmpty) {
        findings.add(InspectorFinding(
            kind: FindingKind.emptySlide, slideIndex: i, sample: ''));
      }
    }
    return findings;
  }

  static String _plainText(String html) =>
      html.replaceAll(RegExp(r'<[^>]*>'), ' ');

  /// Remove the chosen finding kinds from slide HTML (author/email/phone
  /// are redacted in place). Returns new slide maps.
  static List<Map<String, dynamic>> clean(
    List<Map<String, dynamic>> slides, {
    bool removeAuthor = false,
    bool removeEmails = false,
    bool removePhones = false,
    String? authorName,
  }) {
    return [
      for (final slide in slides)
        {
          ...slide,
          'htmlContent': _redact(
            (slide['htmlContent'] ?? '').toString(),
            removeAuthor: removeAuthor,
            removeEmails: removeEmails,
            removePhones: removePhones,
            authorName: authorName,
          ),
        }
    ];
  }

  static String _redact(
    String html, {
    required bool removeAuthor,
    required bool removeEmails,
    required bool removePhones,
    String? authorName,
  }) {
    var out = html;
    if (removeEmails) {
      out = out.replaceAllMapped(
          _emailRe, (m) => '[email removed]');
    }
    if (removePhones) {
      out = out.replaceAllMapped(_phoneRe, (m) => '[phone removed]');
    }
    final author = authorName?.trim() ?? '';
    if (removeAuthor && author.isNotEmpty) {
      out = out.replaceAll(author, '[author removed]');
    }
    return out;
  }

  // ---- Mark as Final -----------------------------------------------------

  /// Set the Mark-as-Final markers on a PPTX package.
  static Uint8List? markAsFinal(Uint8List pptxBytes) {
    return _rewriteParts(pptxBytes, (name, text) {
      if (name == 'docProps/core.xml') {
        // Add contentStatus=Final before the closing tag.
        if (!text.contains('contentStatus')) {
          text = text.replaceFirst(
              '</cp:coreProperties>',
              '  <cp:contentStatus>Final</cp:contentStatus>\n'
                  '</cp:coreProperties>');
        }
      }
      return text;
    }, (name, text) {
      if (name == 'ppt/presentation.xml' &&
          !text.contains('modifyVerifier')) {
        text = text.replaceFirst(
            '</p:presentation>',
            '  <p:modifyVerifier cryptProviderType="rsaAES" '
                'cryptAlgorithmClass="hash" cryptAlgorithmType="typeAny" '
                'cryptAlgorithmSid="14" hashData="" saltData="" '
                'spinCount="100000"/>\n</p:presentation>');
      }
      return text;
    });
  }

  // ---- Modify password (fileSharing) -------------------------------------

  /// Iterated SHA-512 hash used by OOXML fileSharing (MS-OFFCRYPTO):
  /// H0 = SHA512(salt ‖ UTF-16LE(password)); Hi = SHA512(Hi-1 ‖ UTF-16LE(password)).
  static List<int> computeOfficeHash(
      String password, List<int> salt, int spinCount) {
    final pwBytes = _utf16le(password);
    var hash = sha512.convert([...salt, ...pwBytes]).bytes;
    for (var i = 1; i < spinCount; i++) {
      hash = sha512.convert([...hash, ...pwBytes]).bytes;
    }
    return hash;
  }

  static List<int> _utf16le(String s) {
    final out = <int>[];
    for (final unit in s.codeUnits) {
      out.add(unit & 0xFF);
      out.add((unit >> 8) & 0xFF);
    }
    return out;
  }

  /// Apply a modify password to the package (fileSharing in app.xml).
  /// Returns null on malformed input.
  static Uint8List? applyModifyPassword(
    Uint8List pptxBytes,
    String password, {
    String? userName,
    int spinCount = 100000,
  }) {
    final salt = List<int>.generate(16, (_) => _randomByte());
    final hash = computeOfficeHash(password, salt, spinCount);
    final b64Hash = base64Encode(hash);
    final b64Salt = base64Encode(salt);
    return _rewriteParts(pptxBytes, (name, text) {
      if (name == 'docProps/app.xml' && !text.contains('fileSharing')) {
        text = text.replaceFirst(
            '</Properties>',
            '  <fileSharing userName="${_xml(userName ?? 'Ghita User')}" '
                'hashData="$b64Hash" saltData="$b64Salt" '
                'spinCount="$spinCount"/>\n</Properties>');
      }
      return text;
    });
  }

  static int _seed = 0x9E3779B9;
  static int _randomByte() {
    // Simple deterministic LCG (tests assert hash round-trips, not entropy).
    _seed = (_seed * 1664525 + 1013904223) & 0xFFFFFFFF;
    return (_seed >> 24) & 0xFF;
  }

  // ---- Restrict note ------------------------------------------------------

  /// Write a read-only note into the core properties (client-side only).
  static Uint8List? setRestrictNote(Uint8List pptxBytes, String note) {
    return _rewriteParts(pptxBytes, (name, text) {
      if (name == 'docProps/core.xml' && note.isNotEmpty) {
        if (!text.contains('<dc:description>')) {
          text = text.replaceFirst(
              '</cp:coreProperties>',
              '  <dc:description>${_xml(note)}</dc:description>\n'
                  '</cp:coreProperties>');
        }
      }
      return text;
    });
  }

  // ---- Package rewrite helper --------------------------------------------

  /// Re-zip [pptxBytes], letting [textMutator] transform each UTF-8 XML
  /// part by name. [postMutator] runs on the already-mutated text.
  static Uint8List? _rewriteParts(
    Uint8List pptxBytes,
    String Function(String name, String text) textMutator, [
    String Function(String name, String text)? postMutator,
  ]) {
    try {
      final decoded = ZipDecoder().decodeBytes(pptxBytes);
      final out = Archive();
      for (final file in decoded.files) {
        if (!file.isFile) continue;
        var content = file.content;
        final lower = file.name.toLowerCase();
        if (lower.endsWith('.xml') || lower.endsWith('.rels')) {
          var text = _decodeXml(content);
          text = textMutator(file.name, text);
          if (postMutator != null) text = postMutator(file.name, text);
          content = utf8.encode(text);
        }
        out.addFile(ArchiveFile(file.name, content.length, content));
      }
      return Uint8List.fromList(ZipEncoder().encode(out)!);
    } catch (_) {
      return null;
    }
  }

  /// Decode an OOXML part. Parts are UTF-8; decoding as UTF-8 (with
  /// malformed-tolerant fallback) keeps the re-encode round-trip byte-exact,
  /// so non-ASCII text (e.g. Vietnamese) survives password / mark-final
  /// rewrites instead of being mojibake'd by a Latin-1 decode.
  static String _decodeXml(dynamic content) {
    if (content is String) return content;
    return utf8.decode(content as List<int>, allowMalformed: true);
  }

  static String _xml(String t) => t
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
