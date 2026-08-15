import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../services/cameo_service.dart';

/// "Chèn Cameo (camera)" dialog (Track 20, P7): set the label and position —
/// returns a [CameoData] or null when cancelled.
class CameoDialog extends StatefulWidget {
  const CameoDialog({super.key});

  @override
  State<CameoDialog> createState() => _CameoDialogState();
}

class _CameoDialogState extends State<CameoDialog> {
  String _label = 'Camera';
  double _x = 40, _y = 30, _w = 20, _h = 25;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Row(children: [
        const Icon(Icons.videocam_outlined),
        const SizedBox(width: 10),
        Text(l.cameo),
      ]),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: TextEditingController(text: _label),
              decoration: InputDecoration(
                labelText: l.cameoLabel,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => _label = v,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: _x.toStringAsFixed(0)),
                    decoration: const InputDecoration(
                      labelText: 'X (%)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => _x = double.tryParse(v) ?? _x,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: _y.toStringAsFixed(0)),
                    decoration: const InputDecoration(
                      labelText: 'Y (%)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => _y = double.tryParse(v) ?? _y,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: _w.toStringAsFixed(0)),
                    decoration: const InputDecoration(
                      labelText: 'W (%)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => _w = double.tryParse(v) ?? _w,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: _h.toStringAsFixed(0)),
                    decoration: const InputDecoration(
                      labelText: 'H (%)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => _h = double.tryParse(v) ?? _h,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, CameoData(
            label: _label,
            x: _x, y: _y, w: _w, h: _h,
          )),
          child: Text(l.cameoInsert),
        ),
      ],
    );
  }
}