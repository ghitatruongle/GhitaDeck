import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../../l10n/l10n.dart';
import '../../l10n/app_localizations.dart';
import '../../models/slide.dart';
import '../../models/slide_layout.dart';

/// Album layout for arranging multiple images on one slide.
enum PhotoAlbumLayout {
  single,
  two,
  oneLargeTwoSmall,
  grid2x2,
  grid3,
  grid4,
}

/// "Photo Album" dialog (Track 16, FEAT 14): pick multiple images, choose a
/// layout, toggle captions/frames/transitions, then generate N slides appended
/// to the deck.
class PhotoAlbumDialog extends StatefulWidget {
  const PhotoAlbumDialog({super.key});

  @override
  State<PhotoAlbumDialog> createState() => _PhotoAlbumDialogState();
}

class _PhotoAlbumDialogState extends State<PhotoAlbumDialog> {
  final _images = <_AlbumImage>[];
  PhotoAlbumLayout _layout = PhotoAlbumLayout.single;
  bool _addCaption = true;
  bool _addFrame = false;
  bool _addTransition = true;
  SlideEffect _transitionEffect = SlideEffect.fade;

  @override
  void dispose() {
    for (final img in _images) {
      img.controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;
    for (final file in result.files) {
      final bytes = file.bytes ??
          (file.path != null ? File(file.path!).readAsBytesSync() : null);
      if (bytes == null) continue;
      final name = file.name;
      setState(() {
        _images.add(_AlbumImage(
          bytes: bytes,
          name: name,
          controller: TextEditingController(text: name.replaceAll(RegExp(r'\.[^.]+$'), '')),
        ));
      });
    }
  }

  void _removeImage(int index) {
    _images[index].controller.dispose();
    setState(() => _images.removeAt(index));
  }

  /// Build the slides from the selected images and pop them back.
  void _generate() {
    if (_images.isEmpty) return;
    final slides = <Slide>[];
    final caption = _addCaption;
    final frame = _addFrame;
    final transition = _addTransition;
    final effect = _transitionEffect;
    final layout = _layout;

    // Group images per slide according to layout.
    final batches = _batchImages(_images, layout);
    for (final batch in batches) {
      final html = _buildSlideHtml(batch, layout, caption, frame);
      slides.add(Slide(
        title: batch.map((i) => i.controller.text).join(', '),
        htmlContent: html,
        layoutType: SlideLayoutType.pictureAndCaption.name,
        effect: transition ? effect : null,
      ));
    }
    Navigator.pop(context, slides);
  }

  List<List<_AlbumImage>> _batchImages(List<_AlbumImage> images, PhotoAlbumLayout layout) {
    final perSlide = _imagesPerSlide(layout);
    final batches = <List<_AlbumImage>>[];
    for (var i = 0; i < images.length; i += perSlide) {
      batches.add(images.sublist(i, (i + perSlide).clamp(0, images.length)));
    }
    return batches;
  }

  int _imagesPerSlide(PhotoAlbumLayout layout) {
    switch (layout) {
      case PhotoAlbumLayout.single:
        return 1;
      case PhotoAlbumLayout.two:
        return 2;
      case PhotoAlbumLayout.oneLargeTwoSmall:
        return 3;
      case PhotoAlbumLayout.grid2x2:
        return 4;
      case PhotoAlbumLayout.grid3:
        return 3;
      case PhotoAlbumLayout.grid4:
        return 4;
    }
  }

  String _buildSlideHtml(List<_AlbumImage> batch, PhotoAlbumLayout layout, bool caption, bool frame) {
    final buf = StringBuffer();
    final frameStyle = frame ? ' border: 2px solid #ccc; border-radius: 6px; box-shadow: 0 2px 6px rgba(0,0,0,0.15);' : '';

    if (layout == PhotoAlbumLayout.single) {
      buf.write('<div style="text-align:center; padding:20px;">');
      buf.write('<img src="${_dataUri(batch[0].bytes)}" alt="${batch[0].controller.text}" style="max-width:90%; max-height:70vh; object-fit:contain;$frameStyle">');
      if (caption && batch[0].controller.text.isNotEmpty) {
        buf.write('<p style="margin-top:10px; font-size:1.3rem; color:#333;">${_xml(batch[0].controller.text)}</p>');
      }
      buf.write('</div>');
    } else if (layout == PhotoAlbumLayout.two) {
      buf.write('<div style="display:flex; gap:16px; padding:20px; align-items:center; justify-content:center;">');
      for (final img in batch) {
        buf.write('<div style="text-align:center; flex:1;">');
        buf.write('<img src="${_dataUri(img.bytes)}" alt="${img.controller.text}" style="max-width:100%; max-height:55vh; object-fit:contain;$frameStyle">');
        if (caption && img.controller.text.isNotEmpty) {
          buf.write('<p style="margin-top:8px; font-size:1.1rem; color:#333;">${_xml(img.controller.text)}</p>');
        }
        buf.write('</div>');
      }
      buf.write('</div>');
    } else if (layout == PhotoAlbumLayout.oneLargeTwoSmall) {
      buf.write('<div style="display:flex; gap:12px; padding:20px; align-items:center;">');
      if (batch.isNotEmpty) {
        buf.write('<div style="flex:2; text-align:center;">');
        buf.write('<img src="${_dataUri(batch[0].bytes)}" alt="${batch[0].controller.text}" style="max-width:100%; max-height:60vh; object-fit:contain;$frameStyle">');
        if (caption && batch[0].controller.text.isNotEmpty) {
          buf.write('<p style="margin-top:6px; font-size:1.1rem; color:#333;">${_xml(batch[0].controller.text)}</p>');
        }
        buf.write('</div>');
      }
      if (batch.length > 1) {
        buf.write('<div style="flex:1; display:flex; flex-direction:column; gap:10px;">');
        for (var i = 1; i < batch.length; i++) {
          buf.write('<div style="text-align:center;">');
          buf.write('<img src="${_dataUri(batch[i].bytes)}" alt="${batch[i].controller.text}" style="max-width:100%; max-height:28vh; object-fit:contain;$frameStyle">');
          if (caption && batch[i].controller.text.isNotEmpty) {
            buf.write('<p style="margin-top:4px; font-size:0.95rem; color:#333;">${_xml(batch[i].controller.text)}</p>');
          }
          buf.write('</div>');
        }
        buf.write('</div>');
      }
      buf.write('</div>');
    } else {
      // Grid layouts
      final cols = layout == PhotoAlbumLayout.grid3 ? 3 : (layout == PhotoAlbumLayout.grid4 ? 2 : 2);
      buf.write('<div style="display:grid; grid-template-columns:repeat($cols, 1fr); gap:12px; padding:20px;">');
      for (final img in batch) {
        buf.write('<div style="text-align:center;">');
        buf.write('<img src="${_dataUri(img.bytes)}" alt="${img.controller.text}" style="width:100%; aspect-ratio:16/10; object-fit:cover;$frameStyle">');
        if (caption && img.controller.text.isNotEmpty) {
          buf.write('<p style="margin-top:4px; font-size:0.9rem; color:#333;">${_xml(img.controller.text)}</p>');
        }
        buf.write('</div>');
      }
      buf.write('</div>');
    }
    return buf.toString();
  }

  String _dataUri(Uint8List bytes) {
    // Use JPEG for smaller size (Track 03 reuse: compress when possible).
    final image = img.decodeImage(bytes);
    if (image != null) {
      final compressed = img.encodeJpg(image, quality: 85);
      if (compressed.length < bytes.length) {
        return 'data:image/jpeg;base64,${base64Encode(compressed)}';
      }
    }
    return 'data:image/png;base64,${base64Encode(bytes)}';
  }

  String _xml(String text) => text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Row(children: [
        const Icon(Icons.photo_library_outlined),
        const SizedBox(width: 10),
        Text(l.photoAlbum),
      ]),
      content: SizedBox(
        width: 580,
        height: 480,
        child: _images.isEmpty ? _buildEmpty(l) : _buildContent(l),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        if (_images.isNotEmpty)
          FilledButton(
            onPressed: _generate,
            child: Text(l.photoAlbumCreate),
          ),
      ],
    );
  }

  Widget _buildEmpty(AppLocalizations l) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_photo_alternate_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(l.photoAlbumEmpty, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _pickImages,
            icon: const Icon(Icons.add),
            label: Text(l.photoAlbumPick),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(AppLocalizations l) {
    return Column(
      children: [
        // Toolbar
        Row(
          children: [
            FilledButton.icon(
              onPressed: _pickImages,
              icon: const Icon(Icons.add, size: 18),
              label: Text(l.photoAlbumPick, style: const TextStyle(fontSize: 12)),
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
            ),
            const SizedBox(width: 8),
            Text('${_images.length} ${l.photoAlbumCount}', style: const TextStyle(fontSize: 12)),
            const Spacer(),
            // Layout selector
            DropdownButton<PhotoAlbumLayout>(
              value: _layout,
              underline: const SizedBox(),
              style: const TextStyle(fontSize: 12, color: Colors.black87),
              items: const [
                DropdownMenuItem(value: PhotoAlbumLayout.single, child: Text('1 ảnh')),
                DropdownMenuItem(value: PhotoAlbumLayout.two, child: Text('2 ảnh')),
                DropdownMenuItem(value: PhotoAlbumLayout.oneLargeTwoSmall, child: Text('1 lớn + 2 nhỏ')),
                DropdownMenuItem(value: PhotoAlbumLayout.grid2x2, child: Text('Lưới 2×2')),
                DropdownMenuItem(value: PhotoAlbumLayout.grid3, child: Text('Lưới 3')),
                DropdownMenuItem(value: PhotoAlbumLayout.grid4, child: Text('Lưới 4')),
              ],
              onChanged: (v) => setState(() => _layout = v ?? PhotoAlbumLayout.single),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Options row
        Row(
          children: [
            Checkbox(
              value: _addCaption,
              onChanged: (v) => setState(() => _addCaption = v ?? true),
            ),
            Text(l.photoAlbumCaption, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 12),
            Checkbox(
              value: _addFrame,
              onChanged: (v) => setState(() => _addFrame = v ?? false),
            ),
            Text(l.photoAlbumFrame, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 12),
            Checkbox(
              value: _addTransition,
              onChanged: (v) => setState(() => _addTransition = v ?? true),
            ),
            Text(l.photoAlbumTransition, style: const TextStyle(fontSize: 12)),
            if (_addTransition) ...[
              const SizedBox(width: 6),
              DropdownButton<SlideEffect>(
                value: _transitionEffect,
                underline: const SizedBox(),
                style: const TextStyle(fontSize: 12, color: Colors.black87),
                items: const [
                  DropdownMenuItem(value: SlideEffect.fade, child: Text('Fade')),
                  DropdownMenuItem(value: SlideEffect.pushLeft, child: Text('Push')),
                  DropdownMenuItem(value: SlideEffect.zoom, child: Text('Zoom')),
                ],
                onChanged: (v) => setState(() => _transitionEffect = v ?? SlideEffect.fade),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        // Image list
        Expanded(
          child: ListView.builder(
            itemCount: _images.length,
            itemBuilder: (_, i) => ListTile(
              dense: true,
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.memory(_images[i].bytes, width: 48, height: 36, fit: BoxFit.cover),
              ),
              title: SizedBox(
                height: 28,
                child: TextField(
                  controller: _images[i].controller,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 4),
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => _removeImage(i),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AlbumImage {
  final Uint8List bytes;
  final String name;
  final TextEditingController controller;

  _AlbumImage({
    required this.bytes,
    required this.name,
    required this.controller,
  });
}