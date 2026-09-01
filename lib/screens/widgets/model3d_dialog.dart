import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../models/model3d_item.dart';
import '../../services/model3d_service.dart';
import '../../utils/snackbar_helper.dart';

/// "Chèn 3D Model" dialog (Track 14, P2/P6): pick a GLB (poster preview +
/// "3D" badge — no 3D renderer needed), toggle auto-rotate, then insert or
/// replace a model — all export formats read the same `<div data-model3d>`.
class Model3dDialog extends StatefulWidget {
  const Model3dDialog({super.key, this.currentHtml = '', this.editIndex});

  final String currentHtml;
  final int? editIndex;

  @override
  State<Model3dDialog> createState() => _Model3dDialogState();
}

class _Model3dDialogState extends State<Model3dDialog> {
  late List<Model3DData> _existing;
  late Model3DData _draft;
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _existing = Model3DService.modelsIn(widget.currentHtml);
    final initial = (widget.editIndex != null &&
            widget.editIndex! < _existing.length)
        ? _existing[widget.editIndex!]
        : const Model3DData();
    _draft = initial;
    _nameController.text = initial.name;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickModel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['glb'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final Uint8List? bytes = file.bytes ??
        (file.path != null ? await File(file.path!).readAsBytes() : null);
    if (bytes == null) return;
    // GLB magic: 'glTF' (0x46546C67).
    if (bytes.length < 12 ||
        bytes[0] != 0x67 ||
        bytes[1] != 0x6C ||
        bytes[2] != 0x54 ||
        bytes[3] != 0x46) {
      if (mounted) {
        showAppSnackBar(
  context,
  context.l10n.model3dInvalidFile,
  duration: const Duration(seconds: 3)
);
      }
      return;
    }
    setState(() {
      _draft = _draft.copyWith(
        src: 'data:model/gltf-binary;base64,${base64Encode(bytes)}',
        name: file.name.replaceAll(RegExp(r'\.glb$', caseSensitive: false), ''),
      );
      _nameController.text = _draft.name;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.view_in_ar_outlined),
          const SizedBox(width: 10),
          Text(widget.editIndex == null ? l.insertModel3d : l.editModel3d),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_existing.isNotEmpty) ...[
                Text(l.model3dExisting,
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 6),
                DropdownButtonFormField<int>(
                  initialValue: widget.editIndex,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (var i = 0; i < _existing.length; i++)
                      DropdownMenuItem(
                        value: i,
                        child: Text(
                          _existing[i].name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      Navigator.pop(context, 'edit:$v');
                    }
                  },
                ),
                const SizedBox(height: 12),
              ],
              // Preview: self-generated poster + "3D" badge (no renderer).
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  children: [
                    if (_draft.src.isNotEmpty)
                      Image.memory(
                        Model3DService.renderPosterPng(_draft),
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 200,
                          color: const Color(0xFF1B2A4A),
                          child: const Center(
                            child: Icon(Icons.view_in_ar,
                                color: Colors.white54, size: 48),
                          ),
                        ),
                      )
                    else
                      Container(
                        height: 200,
                        color: const Color(0xFF1B2A4A),
                        child: const Center(
                          child: Icon(Icons.view_in_ar,
                              color: Colors.white54, size: 48),
                        ),
                      ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '3D',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickModel,
                      icon: const Icon(Icons.folder_open),
                      label: Text(
                        _draft.src.isNotEmpty
                            ? '${_draft.name}.glb'
                            : l.model3dPickFile,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: l.model3dName,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) =>
                    setState(() => _draft = _draft.copyWith(name: v.trim())),
              ),
              const SizedBox(height: 6),
              CheckboxListTile(
                value: _draft.rotate,
                title: Text(l.model3dRotate),
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (v) =>
                    setState(() => _draft = _draft.copyWith(rotate: v)),
              ),
              Text(l.model3dRotateHint,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: _draft.src.isEmpty
              ? null
              : () => Navigator.pop(context, _draft),
          child: Text(widget.editIndex == null ? l.insertModel3d : l.save),
        ),
      ],
    );
  }
}
