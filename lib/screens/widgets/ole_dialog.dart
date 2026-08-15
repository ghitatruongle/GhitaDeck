import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../services/ole_service.dart';

/// "Chèn đối tượng OLE" dialog (Track 18, P6): pick a file (Excel/Word/PDF),
/// set the icon label, then embed it into the slide as an OLE object.
class OleDialog extends StatefulWidget {
  const OleDialog({super.key});

  @override
  State<OleDialog> createState() => _OleDialogState();
}

class _OleDialogState extends State<OleDialog> {
  Uint8List? _bytes;
  String _fileName = '';
  String _label = '';
  final bool _loading = false;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx', 'xls', 'docx', 'doc', 'pdf', 'pptx'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes ??
        (file.path != null ? await File(file.path!).readAsBytes() : null);
    if (bytes == null) return;
    setState(() {
      _bytes = bytes;
      _fileName = file.name;
      if (_label.isEmpty) {
        // Default label = file name without extension.
        _label = file.name.replaceAll(RegExp(r'\.[^.]+$'), '');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Row(children: [
        const Icon(Icons.insert_drive_file_outlined),
        const SizedBox(width: 10),
        Text(l.ole),
      ]),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OutlinedButton.icon(
              onPressed: _loading ? null : _pickFile,
              icon: const Icon(Icons.folder_open),
              label: Text(_bytes != null
                  ? _fileName
                  : l.olePickFile),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: TextEditingController(text: _label),
              decoration: InputDecoration(
                labelText: l.oleLabel,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => _label = v,
            ),
            const SizedBox(height: 8),
            if (_bytes == null)
              Text(l.olePickHint, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: _bytes == null
              ? null
              : () => Navigator.pop(context, OleData(
                    fileName: _fileName,
                    fileBytes: _bytes!,
                    iconLabel: _label.isEmpty ? 'Document' : _label,
                  )),
          child: Text(l.oleInsert),
        ),
      ],
    );
  }
}