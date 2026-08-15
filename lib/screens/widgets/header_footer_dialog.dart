import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../services/header_footer_service.dart';

/// "Chèn Header & Footer" dialog (Track 19, P2): configure header, footer,
/// slide number, date/time, and whether to exclude the first slide.
/// Returns a [DeckMeta] when confirmed, or null when cancelled.
/// The caller can apply the result to all slides or to the selected slide.
class HeaderFooterDialog extends StatefulWidget {
  final DeckMeta current;
  const HeaderFooterDialog({super.key, this.current = const DeckMeta()});

  @override
  State<HeaderFooterDialog> createState() => _HeaderFooterDialogState();
}

class _HeaderFooterDialogState extends State<HeaderFooterDialog> {
  late DeckMeta _draft;
  late TextEditingController _headerCtrl;
  late TextEditingController _footerCtrl;

  @override
  void initState() {
    super.initState();
    _draft = widget.current;
    _headerCtrl = TextEditingController(text: _draft.header);
    _footerCtrl = TextEditingController(text: _draft.footer);
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    _footerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Row(children: [
        const Icon(Icons.text_snippet_outlined),
        const SizedBox(width: 10),
        Text(l.headerFooter),
      ]),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              TextField(
                controller: _headerCtrl,
                decoration: InputDecoration(
                  labelText: l.hfHeader,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => _draft = _draft.copyWith(header: v),
              ),
              const SizedBox(height: 10),
              // Footer
              TextField(
                controller: _footerCtrl,
                decoration: InputDecoration(
                  labelText: l.hfFooter,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => _draft = _draft.copyWith(footer: v),
              ),
              const SizedBox(height: 12),
              // Slide number
              CheckboxListTile(
                value: _draft.slideNumber,
                title: Text(l.hfSlideNumber, style: const TextStyle(fontSize: 13)),
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (v) => setState(() => _draft = _draft.copyWith(slideNumber: v ?? true)),
              ),
              // Date/time
              CheckboxListTile(
                value: _draft.dateTime,
                title: Text(l.hfDateTime, style: const TextStyle(fontSize: 13)),
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (v) => setState(() => _draft = _draft.copyWith(dateTime: v ?? false)),
              ),
              if (_draft.dateTime) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: _draft.dateTimeAuto,
                            onChanged: (v) => setState(() => _draft = _draft.copyWith(dateTimeAuto: v ?? true)),
                          ),
                          Text(l.hfDateTimeAuto, style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                      TextField(
                        controller: TextEditingController(text: _draft.dateTimeFormat),
                        decoration: InputDecoration(
                          labelText: l.hfDateTimeFormat,
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (v) => _draft = _draft.copyWith(dateTimeFormat: v),
                      ),
                    ],
                  ),
                ),
              ],
              // Exclude first
              CheckboxListTile(
                value: _draft.excludeFirst,
                title: Text(l.hfExcludeFirst, style: const TextStyle(fontSize: 13)),
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (v) => setState(() => _draft = _draft.copyWith(excludeFirst: v ?? true)),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, (_draft, false)),
          child: Text(l.hfApplyToSlide),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, (_draft, true)),
          child: Text(l.hfApplyToAll),
        ),
      ],
    );
  }
}