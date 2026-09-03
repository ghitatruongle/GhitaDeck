// REAL Dart -> Rust bridge probe (T01.3 / T02.8 gates): runs inside the actual
// Windows app process so the real ghita_core.dll (stored next to the exe by
// cargokit) is found and loaded — unit tests simulate the DLL with fakes,
// this test proves the genuine load + call + version surface + real PPTX and
// .ghita bundle round-trips encoded end-to-end through ghita_zip.
//
// The engine PPTX is also persisted to build/t02_engine_probe.pptx so it can
// be opened by a real PowerPoint (COM — see the release checklist) as the
// final "no repair prompt" acceptance; the in-test OOXML package validation
// below is the automated gate that runs on every probe.
//
// Run: flutter test integration_test/rust_engine_probe_test.dart -d windows
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/l10n/app_localizations.dart';
import 'package:ghita_ppt_converter/models/slide.dart';
import 'package:ghita_ppt_converter/providers/ai_provider_manager.dart';
import 'package:ghita_ppt_converter/providers/app_provider.dart';
import 'package:ghita_ppt_converter/providers/locale_provider.dart';
import 'package:ghita_ppt_converter/providers/shortcuts_provider.dart';
import 'package:ghita_ppt_converter/providers/theme_provider.dart';
import 'package:ghita_ppt_converter/screens/settings_screen.dart';
import 'package:ghita_ppt_converter/services/image_codec.dart';
import 'package:ghita_ppt_converter/services/ppt_generator.dart';
import 'package:ghita_ppt_converter/services/project_bundle_service.dart';
import 'package:ghita_ppt_converter/services/rust_engine.dart';
import 'package:ghita_ppt_converter/services/zip_codec.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('real ghita_core.dll loads and version shows in Settings',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    // No injected rustInit: this exercises the genuine RustLib.init() path.
    final engine = RustEngineService();
    await engine.ensureInitialized();

    expect(engine.status, EngineStatus.rustReady,
        reason: 'real DLL load/call failed: ${engine.detail}');
    expect(engine.detail, contains('ghita_core 0.1.0'));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: engine),
          ChangeNotifierProvider(create: (_) => AppProvider()),
          ChangeNotifierProvider(create: (_) => AIProviderManager()),
          ChangeNotifierProvider(create: (_) => LocaleProvider()),
          ChangeNotifierProvider(create: (_) => ShortcutsProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: Consumer<LocaleProvider>(
          builder: (context, localeProvider, _) => MaterialApp(
            locale: localeProvider.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const SettingsScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Status line rendered from the real crate version.
    expect(find.textContaining('ghita_core 0.1.0'), findsOneWidget);
  });

  testWidgets('real ghita_zip: PPTX encoded end-to-end through the DLL',
      (tester) async {
    ZipEngineConfig.setPreferredRust(true);
    final tmp = await Directory.systemTemp.createTemp('ghita_zip_probe');
    addTearDown(() => tmp.delete(recursive: true));
    final out = '${tmp.path}/engine.pptx';

    final slides = [
      {
        'title': 'Zip probe',
        'htmlContent': '<h1>Xin chào</h1><p>Tiếng Việt ghi chú</p>',
        'notes': 'Ghi chú diễn giả',
        'transition': 'none',
      },
    ];
    await PPTGenerator.generatePPT(slides, out, useEngineZip: true);
    expect(ZipCodec.lastBackend, 'rust',
        reason: 'PPTX went through the Dart fallback instead of ghita_zip');

    final bytes = File(out).readAsBytesSync();
    final decoded = ZipDecoder().decodeBytes(bytes);
    expect(decoded.files.map((f) => f.name), contains('ppt/slides/slide1.xml'));
    // Strict OOXML package validation (the automated "no repair prompt" gate).
    _validatePptxPackage(decoded);

    // Persist next to the probe's media cache for the real-PowerPoint COM
    // open step in the release checklist (build/ is gitignored).
    try {
      final probeFile = File('build/t02_engine_probe.pptx');
      probeFile.parent.createSync(recursive: true);
      probeFile.writeAsBytesSync(bytes);
      debugPrint('T02 probe: engine PPTX saved to ${probeFile.absolute.path}');
    } catch (_) {
      // Read-only build dir — the in-test validation above is the gate.
    }
  });

  testWidgets('real ghita_zip codec round-trip through the DLL', (tester) async {
    ZipEngineConfig.setPreferredRust(true);
    final zip = await ZipCodec.encode([
      ZipCodecEntry(
          name: 'text.txt',
          bytes: Uint8List.fromList([65, 66, 67, 68]),
          stored: false),
      ZipCodecEntry(
          name: 'img.jpg',
          bytes: Uint8List.fromList([0xAB, 0xCD, 0xEF]),
          stored: true),
    ]);
    expect(ZipCodec.lastBackend, 'rust',
        reason: 'codec fell back to Dart instead of ghita_zip');
    final decoded = ZipDecoder().decodeBytes(zip);
    expect(decoded.files.map((f) => f.name),
        containsAll(['text.txt', 'img.jpg']));
    expect(
        (decoded.files.firstWhere((f) => f.name == 'img.jpg').content
            as List<int>),
        [0xAB, 0xCD, 0xEF]);
  });

  testWidgets('.ghita bundle round-trip through ghita_zip (real DLL)',
      (tester) async {
    ZipEngineConfig.setPreferredRust(true);
    final tmp = await Directory.systemTemp.createTemp('ghita_bundle_probe');
    addTearDown(() => tmp.delete(recursive: true));
    final bundlePath = '${tmp.path}/deck.ghita';
    final extractDir = '${tmp.path}/extracted';

    final slides = [
      Slide(title: 'Bundle A', htmlContent: '<h1>A</h1>', notes: 'notes A'),
      Slide(
          title: 'Bundle B',
          htmlContent: '<h1>B</h1><p>Tiếng Việt</p>',
          notes: 'notes B'),
    ];
    final media = <MapEntry<String, Uint8List>>[
      MapEntry('audio1.m4a', Uint8List.fromList(List.generate(256, (i) => i % 251))),
    ];

    final service = ProjectBundleService();
    final saved = await service.saveProjectBundle(
      targetPath: bundlePath,
      slides: slides,
      title: 'Round-trip deck',
      mediaFiles: media,
      useEngineZip: true,
    );
    expect(saved, isTrue);
    expect(ZipCodec.lastBackend, 'rust',
        reason: 'bundle was written by the Dart fallback instead of ghita_zip');

    final loaded = await service.loadProjectBundle(bundlePath,
        extractDir: extractDir);
    expect(loaded, isNotNull);
    final manifest = loaded!['manifest'] as Map<String, dynamic>;
    expect(manifest['title'], 'Round-trip deck');
    final loadedSlides = loaded['slides'] as List<Slide>;
    expect(loadedSlides, hasLength(2));
    expect(loadedSlides.map((s) => s.title), containsAll(['Bundle A', 'Bundle B']));
    expect(loadedSlides.every((s) => s.notes.isNotEmpty), isTrue);
    final mediaFiles = loaded['mediaFiles'] as Map<String, String>;
    expect(mediaFiles, contains('audio1.m4a'));
    final mediaPath = mediaFiles['audio1.m4a']!;
    expect(File(mediaPath).existsSync(), isTrue,
        reason: 'media not extracted from the engine-written bundle');
    expect(File(mediaPath).readAsBytesSync(), media.first.value,
        reason: 'media bytes corrupted through the engine round-trip');
  });

  testWidgets('real ghita_image: EXIF parity between the two backends',
      (tester) async {
    // Same real DLL as the first probe: the engine is in this isolate, so
    // ImageCodec.process uses the Rust backend.
    final engine = RustEngineService();
    await engine.ensureInitialized();
    ImageEngineConfig.setPreferredRust(true);
    expect(ImageEngineConfig.rustReady, isTrue,
        reason: 'DLL must be usable for the Rust image path');

    // B1: JPEG EXIF 6 (phone portrait, raw 8×4 storage) downscaled to a
    // 2 px width — both backends must keep the photo portrait (2×4, not 2×1).
    final jpg = _jpgWithExifRotation(8, 4, 6);
    final rustJpg = ImageCodec.process(jpg, 'jpg', maxWidth: 2);
    expect(ImageCodec.lastBackend, 'rust',
        reason: 'EXIF JPEG went through the Dart backend');
    expect(rustJpg.width, 2);
    expect(rustJpg.height, 4);
    final dartJpg = ImageCodec.processDart(jpg, 'jpg', maxWidth: 2);
    expect(dartJpg.width, rustJpg.width,
        reason: 'backends disagree on the downscaled width');
    expect(dartJpg.height, rustJpg.height,
        reason: 'backends disagree on the downscaled height');
    final rustDecodedJpg = img.decodeImage(rustJpg.bytes)!;
    expect(rustDecodedJpg.width, lessThan(rustDecodedJpg.height),
        reason: 'Rust output must stay portrait');

    // B3: PNG eXIf orientation 5 (rotate 90 + flip) — both backends must
    // produce the same pixels as the package:image reference bake.
    final anchor = img.Image(width: 2, height: 3);
    anchor.setPixelRgb(0, 0, 255, 0, 0);
    anchor.setPixelRgb(1, 0, 0, 255, 0);
    anchor.setPixelRgb(0, 1, 0, 0, 255);
    anchor.setPixelRgb(1, 2, 255, 255, 255);
    final pngWithExif = _pngBytesWithExifRotation(
        Uint8List.fromList(img.encodePng(anchor)), 5);
    final expected = img.bakeOrientation(
        img.Image.from(anchor..exif.imageIfd.orientation = 5));

    final dartPng = ImageCodec.processDart(pngWithExif, 'png');
    expect(dartPng.width, expected.width);
    expect(dartPng.height, expected.height);
    final rustPng = ImageCodec.process(pngWithExif, 'png');
    expect(ImageCodec.lastBackend, 'rust');
    expect(rustPng.width, expected.width,
        reason: 'Rust EXIF 5 width differs from the reference');
    expect(rustPng.height, expected.height,
        reason: 'Rust EXIF 5 height differs from the reference');
    final dartDecoded = img.decodeImage(dartPng.bytes)!;
    final rustDecoded = img.decodeImage(rustPng.bytes)!;
    for (final pair in [
      [dartDecoded, expected],
      [rustDecoded, expected],
    ]) {
      final actual = pair[0];
      final oracle = pair[1];
      expect(actual.getPixel(0, 0).r, oracle.getPixel(0, 0).r);
      expect(actual.getPixel(0, 0).g, oracle.getPixel(0, 0).g);
      expect(actual.getPixel(0, 0).b, oracle.getPixel(0, 0).b);
    }
  });
}

/// Strict OOXML package validation — the automated "no repair prompt" gate.
/// PowerPoint repairs a package when parts are malformed XML, when
/// [Content_Types].xml does not cover a part, or when a relationship target
/// points at a missing part; all three are checked here.
void _validatePptxPackage(Archive archive) {
  final files = {for (final f in archive.files) f.name: f};

  // 1. Every XML part must parse as well-formed XML.
  for (final f in archive.files) {
    if (f.name.endsWith('.xml') || f.name.endsWith('.rels')) {
      final text = utf8.decode(f.content as List<int>);
      try {
        XmlDocument.parse(text);
      } catch (e) {
        fail('Malformed XML in ${f.name}: $e');
      }
    }
  }

  // 2. [Content_Types].xml Default/Override coverage for every part.
  final ctPart = files['[Content_Types].xml'];
  expect(ctPart, isNotNull, reason: 'missing [Content_Types].xml');
  final ctDoc = XmlDocument.parse(utf8.decode(ctPart!.content as List<int>));
  final defaults = {
    for (final d in ctDoc.findAllElements('Default'))
      d.getAttribute('Extension')!.toLowerCase(): d.getAttribute('ContentType')!,
  };
  final overrides = {
    for (final o in ctDoc.findAllElements('Override'))
      o.getAttribute('PartName')!: o.getAttribute('ContentType')!,
  };
  final parts = files.keys
      .where((n) => n != '[Content_Types].xml' && !n.endsWith('.rels'));
  for (final part in parts) {
    final ext = part.split('.').last.toLowerCase();
    final covered = defaults.containsKey(ext) || overrides.containsKey('/$part');
    expect(covered, isTrue,
        reason: 'Content-Type không khai báo cho $part → repair prompt');
  }

  // 3. Every relationship target must resolve to an existing part.
  for (final f in archive.files.where((f) => f.name.endsWith('.rels'))) {
    final relDoc = XmlDocument.parse(utf8.decode(f.content as List<int>));
    final baseDir = f.name.contains('/')
        ? f.name.substring(0, f.name.lastIndexOf('/') + 1)
        : '';
    for (final rel in relDoc.findAllElements('Relationship')) {
      final target = rel.getAttribute('Target');
      if (target == null ||
          target.startsWith('http') ||
          target.startsWith('https')) {
        continue;
      }
      final resolved = _resolvePart(baseDir, Uri.decodeFull(target));
      expect(files.containsKey(resolved), isTrue,
          reason: 'rels target "$target" (${f.name}) → $resolved không tồn tại');
    }
  }
}

/// Resolves a possibly-relative package part path (`../` permitted) against
/// the directory of the *described* part (OOXML rule): for
/// "ppt/notesSlides/_rels/notesSlide1.xml.rels" the base is
/// "ppt/notesSlides/" — the `_rels/` folder and the rels filename itself are
/// dropped before resolving the target.
String _resolvePart(String baseDir, String target) {
  var base = baseDir;
  if (base.contains('/_rels/')) {
    base = base.substring(0, base.indexOf('/_rels/') + 1);
  } else if (base.startsWith('_rels/')) {
    base = '';
  }
  final stack = <String>[];
  if (base.isNotEmpty) stack.addAll(base.split('/').where((s) => s.isNotEmpty));
  for (final seg in target.split('/')) {
    if (seg.isEmpty || seg == '.') continue;
    if (seg == '..') {
      if (stack.isNotEmpty) stack.removeLast();
    } else {
      stack.add(seg);
    }
  }
  return stack.join('/');
}

// ---- EXIF fixtures (B1/B3 parity) — same shapes as test/image_codec_test.dart.

/// JPEG with a hand-crafted EXIF APP1 segment (orientation 0x0112) right
/// after the SOI. The raw raster is [w]×[h]; EXIF orientation 6/8 on a
/// landscape-stored raw (8×4) yields a portrait display (4×8).
Uint8List _jpgWithExifRotation(int w, int h, int orientation) {
  final image = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      image.setPixelRgb(x, y, (x * 5) % 256, (y * 7) % 256, (x + y) % 256);
    }
  }
  final jpg = Uint8List.fromList(img.encodeJpg(image, quality: 92));
  return Uint8List.fromList([...jpg.sublist(0, 2), ..._app1Segment(orientation),
      ...jpg.sublist(2)]);
}

/// PNG eXIf chunk (orientation 0x0112) inserted right after IHDR.
Uint8List _pngBytesWithExifRotation(Uint8List png, int orientation) {
  final tiff = _tiffExif(orientation);
  final chunk = BytesBuilder()
    ..add(_be32(tiff.length))
    ..add('eXIf'.codeUnits)
    ..add(tiff)
    ..add([0, 0, 0, 0]); // CRC ignored by our length-based parser
  final ihdrLen = ByteData.sublistView(png).getUint32(8);
  final ihdrEnd = 8 + 12 + ihdrLen;
  return Uint8List.fromList([
    ...png.sublist(0, ihdrEnd),
    ...chunk.takeBytes(),
    ...png.sublist(ihdrEnd),
  ]);
}

Uint8List _app1Segment(int orientation) {
  final app1 = BytesBuilder()
    ..add('Exif\x00\x00'.codeUnits)
    ..add(_tiffExif(orientation));
  return Uint8List.fromList([
    0xFF,
    0xE1,
    ..._be16(app1.length + 2),
    ...app1.takeBytes(),
  ]);
}

Uint8List _tiffExif(int orientation) => Uint8List.fromList([
      0x49, 0x49, 0x2A, 0x00, // little-endian TIFF
      8, 0, 0, 0, // IFD0 offset
      1, 0, // one entry
      0x12, 0x01, // tag 0x0112
      3, 0, // SHORT
      1, 0, 0, 0, // count
      ...[orientation, 0, 0, 0], // inline value
      0, 0, 0, 0, // next IFD
    ]);

Uint8List _be16(int v) =>
    Uint8List(2)..buffer.asByteData().setUint16(0, v, Endian.big);

Uint8List _be32(int v) => Uint8List(4)..buffer.asByteData().setUint32(0, v);
