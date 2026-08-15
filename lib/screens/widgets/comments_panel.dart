import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../models/comment.dart';
import '../../services/collaboration_service.dart';
import '../../services/comment_service.dart';

/// Comments panel (Track 48, FEAT 81).
///
/// Shows the comments of the currently selected slide with add / reply /
/// resolve / delete. Typing `@` opens a mention chip list populated from the
/// active collaboration session (or the local profile when offline).
class CommentsPanel extends StatefulWidget {
  const CommentsPanel({
    super.key,
    required this.slide,
    required this.onChanged,
    this.authorName = 'User',
    this.authorColor = '#FF9800',
  });

  final Map<String, dynamic> slide;
  final VoidCallback onChanged;
  final String authorName;
  final String authorColor;

  @override
  State<CommentsPanel> createState() => _CommentsPanelState();
}

class _CommentsPanelState extends State<CommentsPanel> {
  final _controller = TextEditingController();
  StreamSubscription<CollaborationEvent>? _collabSub;
  List<String> _suggestions = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final collab = context.read<CollaborationService>();
    _collabSub?.cancel();
    _collabSub = collab.eventStream.listen((e) {
      if (e.type == CollaborationEventType.userJoined ||
          e.type == CollaborationEventType.userLeft) {
        if (mounted) _refreshSuggestions();
      }
    });
    _refreshSuggestions();
  }

  void _refreshSuggestions() {
    final collab = context.read<CollaborationService>();
    final names = collab.collaborators.map((c) => c.name).toList();
    if (names.isEmpty && widget.authorName.isNotEmpty) {
      names.add(widget.authorName);
    }
    if (mounted) setState(() => _suggestions = names);
  }

  @override
  void dispose() {
    _collabSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _addComment() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final parent = _replyTarget;
    CommentService.addComment(
      widget.slide,
      text: text,
      authorName: widget.authorName,
      authorColor: widget.authorColor,
      replyTo: parent?.id,
    );
    _controller.clear();
    _replyTarget = null;
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final comments = CommentService.commentsFor(widget.slide);
    return Container(
      width: 300,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.comments,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (comments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(context.l10n.commentsEmpty,
                  style: Theme.of(context).textTheme.bodySmall),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: comments.length,
                itemBuilder: (context, index) =>
                    _commentTile(comments[index]),
              ),
            ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            minLines: 1,
            maxLines: 3,
            decoration: InputDecoration(
              isDense: true,
              hintText: context.l10n.commentsAdd,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.send),
                onPressed: _addComment,
              ),
            ),
            onSubmitted: (_) => _addComment(),
            onChanged: (value) {
              if (value.endsWith('@') && _suggestions.isNotEmpty) {
                _showMentionMenu();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _commentTile(Comment c) {
    final replies = CommentService.commentsFor(widget.slide)
        .where((x) => x.replyTo == c.id)
        .toList();
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      color: c.resolved ? Colors.grey.shade200 : null,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 10,
                  backgroundColor: _parseColor(c.authorColor),
                  child: Text(c.authorName.isNotEmpty
                      ? c.authorName[0].toUpperCase()
                      : '?',
                      style: const TextStyle(fontSize: 10)),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(c.authorName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: c.resolved
                      ? context.l10n.commentsUnresolve
                      : context.l10n.commentsResolve,
                  icon: Icon(
                    c.resolved ? Icons.undo : Icons.check_circle_outline,
                    size: 18,
                  ),
                  onPressed: () {
                    CommentService.setResolved(
                        widget.slide, c.id, !c.resolved);
                    widget.onChanged();
                  },
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: context.l10n.commentsDelete,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: () {
                    CommentService.removeComment(widget.slide, c.id);
                    widget.onChanged();
                  },
                ),
              ],
            ),
            Text.rich(
              _highlightMentions(c.text),
              style: const TextStyle(fontSize: 13),
            ),

            Text(
              '${c.createdAt.toLocal().hour.toString().padLeft(2, '0')}:'
              '${c.createdAt.toLocal().minute.toString().padLeft(2, '0')}',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
            for (final reply in replies) ...[
              const Divider(height: 8),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text.rich(_highlightMentions(
                    '↳ ${reply.authorName}: ${reply.text}'),
                    style: const TextStyle(fontSize: 12)),
              ),
            ],
            TextButton.icon(
              style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero),
              onPressed: () {
                _controller.text = '@${c.authorName} ';
                _controller.selection = TextSelection.collapsed(
                    offset: _controller.text.length);
                _showReplyTarget(c);
              },
              icon: const Icon(Icons.reply, size: 14),
              label: Text(context.l10n.commentsReply,
                  style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  /// When a reply is started, the submit button appends to the thread.
  Comment? _replyTarget;

  void _showReplyTarget(Comment c) {
    setState(() => _replyTarget = c);
  }

  TextSpan _highlightMentions(String text) {
    final spans = <TextSpan>[];
    final re = RegExp(r'@([A-Za-z0-9_\p{L}]{2,24})', unicode: true);
    var start = 0;
    for (final m in re.allMatches(text)) {
      if (m.start > start) {
        spans.add(TextSpan(text: text.substring(start, m.start)));
      }
      spans.add(TextSpan(
        text: m.group(0),
        style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold),
      ));
      start = m.end;
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }
    return TextSpan(children: spans);
  }

  void _showMentionMenu() {
    if (_suggestions.isEmpty) return;
    final overlay = Overlay.of(context);
    final box = context.findRenderObject() as RenderBox;
    overlay.insert(OverlayEntry(
      builder: (context) => Positioned(
        left: box.localToGlobal(Offset.zero).dx + 40,
        top: box.localToGlobal(Offset.zero).dy - 40,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final name in _suggestions.take(6))
                ListTile(
                  dense: true,
                  title: Text('@$name'),
                  onTap: () {
                    _controller.text =
                        _controller.text.replaceFirst(RegExp(r'@$'), '@$name ');
                    _controller.selection = TextSelection.collapsed(
                        offset: _controller.text.length);
                    Navigator.of(context).pop();
                  },
                ),
            ],
          ),
        ),
      ),
    ));
  }

  Color _parseColor(String hex) {
    final clean = hex.replaceAll('#', '');
    final v = int.tryParse(
            clean.length >= 6 ? clean.substring(0, 6) : 'FF9800',
            radix: 16) ??
        0xFF9800;
    return Color(0xFF000000 | v);
  }
}
