import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/custom_show.dart';
import '../models/export_options.dart';
import '../models/slide.dart';
import '../services/export_isolate.dart';
import '../services/export_primitives.dart';
import '../services/html_export_service.dart';
import '../services/setup_show_service.dart';

mixin DeckExportActions on ChangeNotifier {
  List<Slide> get slides;
  SlideEffect get slideEffect;
  bool get autoAdvance;
  int get autoAdvanceSeconds;
  CustomShow? get activeCustomShow;
  SetupShowSettings get setupShow;
  HtmlExportService get htmlExportService;
  String? get exportStatus;
  set exportStatus(String? value);
  String? get lastExportedPath;
  set lastExportedPath(String? value);
  void resetExportStatus();
  List<Map<String, dynamic>> slideMaps();

  Future<String> exportWithOptions(
    String fileName,
    ExportOptions options, {
    ExportProgressCallback? onProgress,
    ExportCancelToken? cancelToken,
  }) async {
    exportStatus = 'exporting';
    notifyListeners();
    try {
      final selectedSlides = options.selectSlides(slideMaps());
      final exportSlides = options.format == PresentationExportFormat.pdf &&
              !options.includeHiddenSlides
          ? selectedSlides
              .where((s) => s['hidden'] != true)
              .toList(growable: false)
          : selectedSlides;
      onProgress?.call(ExportProgressBudget.preparing(exportSlides.length));
      final targetDir = await getApplicationDocumentsDirectory();
      final safeName =
          fileName.replaceAll(RegExp(r'[^\w\.-]'), '_').replaceFirst(
                RegExp('\\.${RegExp.escape(options.format.extension)}' r'$'),
                '',
              );
      final outputPath =
          '${targetDir.path}/$safeName.${options.format.extension}';

      final String path;
      switch (options.format) {
        case PresentationExportFormat.pptx:
          path = await runPptExportInIsolate(
            selectedSlides,
            outputPath,
            effect: slideEffect,
            aspectRatio: options.aspectRatio,
            includeNotes: options.includeNotes,
            includeBackgrounds: options.includeBackgrounds,
            imageMaxWidth: options.quality.imageMaxWidth,
            autoAdvance:
                autoAdvance ? Duration(seconds: autoAdvanceSeconds) : null,
            fitContent: options.fitContent,
            theme: options.theme,
            onProgress: onProgress,
            cancelToken: cancelToken,
          );
          break;
        case PresentationExportFormat.html:
          path = await runHtmlExportInIsolate(
            selectedSlides,
            outputPath,
            aspectRatio: options.aspectRatio,
            includeNotes: options.includeNotes,
            includeBackgrounds: options.includeBackgrounds,
            imageMaxWidth: options.quality.imageMaxWidth,
            playerLocale: options.htmlPlayerLocale,
            onProgress: onProgress,
            cancelToken: cancelToken,
          );
          break;
        case PresentationExportFormat.pdf:
          path = await runPdfExportInIsolate(
            exportSlides,
            outputPath,
            aspectRatio: options.aspectRatio,
            includeNotes: options.includeNotes,
            includeBackgrounds: options.includeBackgrounds,
            imageMaxWidth: options.quality.imageMaxWidth,
            paperSize: options.pdfPaperSize,
            marginPreset: options.pdfMarginPreset,
            scaleToFit: options.pdfScaleToFit,
            includeHiddenSlides: options.includeHiddenSlides,
            notesPages: options.pdfNotesPages,
            bookmarks: options.pdfBookmarks,
            onProgress: onProgress,
            cancelToken: cancelToken,
          );
          break;
        case PresentationExportFormat.docx:
          path = await runDocxExportInIsolate(
            selectedSlides,
            outputPath,
            includeNotes: options.includeNotes,
            includeSlideList: options.docxIncludeSlideList,
            onProgress: onProgress,
            cancelToken: cancelToken,
          );
          break;
      }
      lastExportedPath = path;
      exportStatus = 'success';
      notifyListeners();
      resetExportStatus();
      return path;
    } catch (e) {
      exportStatus = 'error';
      notifyListeners();
      resetExportStatus();
      rethrow;
    }
  }

  Future<String> exportToPPT(String fileName, {bool widescreen = true}) async {
    exportStatus = 'exporting';
    notifyListeners();
    try {
      final Directory targetDir = await getApplicationDocumentsDirectory();
      final String sanitizeName = fileName.replaceAll(RegExp(r'[^\w\.-]'), '_');
      final String fullPath = '${targetDir.path}/$sanitizeName.pptx';

      final String path = await runPptExportInIsolate(
        slideMaps(),
        fullPath,
        effect: slideEffect,
        widescreen: widescreen,
        autoAdvance: autoAdvance ? Duration(seconds: autoAdvanceSeconds) : null,
      );
      lastExportedPath = path;
      exportStatus = 'success';
      notifyListeners();
      resetExportStatus();
      return path;
    } catch (e) {
      exportStatus = 'error';
      notifyListeners();
      resetExportStatus();
      rethrow;
    }
  }

  Future<String> exportToPPTPath(String filePath,
      {bool widescreen = true}) async {
    exportStatus = 'exporting';
    notifyListeners();
    try {
      final String path = await runPptExportInIsolate(
        slideMaps(),
        filePath,
        effect: slideEffect,
        widescreen: widescreen,
        autoAdvance: autoAdvance ? Duration(seconds: autoAdvanceSeconds) : null,
      );
      lastExportedPath = path;
      exportStatus = 'success';
      notifyListeners();
      resetExportStatus();
      return path;
    } catch (e) {
      exportStatus = 'error';
      notifyListeners();
      resetExportStatus();
      rethrow;
    }
  }

  Future<String> exportToHtml(String fileName) async {
    exportStatus = 'exporting';
    notifyListeners();
    try {
      final Directory targetDir = await getApplicationDocumentsDirectory();
      final String safeName = fileName.replaceAll(RegExp(r'[^\w\.-]'), '_');
      final String fullPath = '${targetDir.path}/$safeName.html';
      final String exportedPath =
          await runHtmlExportInIsolate(slideMaps(), fullPath);
      lastExportedPath = exportedPath;
      exportStatus = 'success';
      notifyListeners();
      resetExportStatus();
      return exportedPath;
    } catch (e) {
      exportStatus = 'error';
      notifyListeners();
      resetExportStatus();
      rethrow;
    }
  }

  Future<String> exportToHtmlPath(String filePath) async {
    exportStatus = 'exporting';
    notifyListeners();
    try {
      final String exportedPath =
          await runHtmlExportInIsolate(slideMaps(), filePath);
      lastExportedPath = exportedPath;
      exportStatus = 'success';
      notifyListeners();
      resetExportStatus();
      return exportedPath;
    } catch (e) {
      exportStatus = 'error';
      notifyListeners();
      resetExportStatus();
      rethrow;
    }
  }

  Future<String> exportToPdf(String fileName, {bool widescreen = true}) async {
    exportStatus = 'exporting';
    notifyListeners();
    try {
      final Directory targetDir = await getApplicationDocumentsDirectory();
      final String sanitizeName = fileName.replaceAll(RegExp(r'[^\w\.-]'), '_');
      final String fullPath = '${targetDir.path}/$sanitizeName.pdf';
      final String exportedPath = await runPdfExportInIsolate(
        slideMaps(),
        fullPath,
        widescreen: widescreen,
      );
      lastExportedPath = exportedPath;
      exportStatus = 'success';
      notifyListeners();
      resetExportStatus();
      return exportedPath;
    } catch (e) {
      exportStatus = 'error';
      notifyListeners();
      resetExportStatus();
      rethrow;
    }
  }

  Future<String> exportToPdfPath(String filePath,
      {bool widescreen = true}) async {
    exportStatus = 'exporting';
    notifyListeners();
    try {
      final String exportedPath = await runPdfExportInIsolate(
        slideMaps(),
        filePath,
        widescreen: widescreen,
      );
      lastExportedPath = exportedPath;
      exportStatus = 'success';
      notifyListeners();
      resetExportStatus();
      return exportedPath;
    } catch (e) {
      exportStatus = 'error';
      notifyListeners();
      resetExportStatus();
      rethrow;
    }
  }

  String buildHtmlDeck({int startIndex = 0, List<int>? slideOrder}) {
    var maps = slideMaps();
    final order = slideOrder ??
        (activeCustomShow?.validIndices(maps.length) ??
            (setupShow.autoAdvance ? null : null));
    if (order != null && order.isNotEmpty) {
      maps = [
        for (final i in order)
          if (i >= 0 && i < maps.length) maps[i]
      ];
    }
    final Duration? autoAdvanceDuration;
    if (setupShow.autoAdvance) {
      autoAdvanceDuration = Duration(seconds: setupShow.advanceSeconds);
    } else if (autoAdvance) {
      autoAdvanceDuration = Duration(seconds: autoAdvanceSeconds);
    } else {
      autoAdvanceDuration = null;
    }
    return htmlExportService.buildPresentationHtml(
      maps,
      startIndex: startIndex,
      autoAdvance: autoAdvanceDuration,
      imageMaxWidth: 1200,
    );
  }
}
