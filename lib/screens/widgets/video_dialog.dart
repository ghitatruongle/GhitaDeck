import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../models/media_item.dart';
import '../../services/video_embed_service.dart';

/// "Chèn video" dialog (Track 11, P4–P7): pick a local mp4 (with optional
/// FFmpeg trim + first-frame poster) or paste a YouTube link (thumbnail
/// fetched online), set playback options and bookmarks, then insert or
/// replace a video — all three export formats read the same `<video
/// data-video='…'>` block.
class VideoDialog extends StatefulWidget {
  const VideoDialog({super.key, this.currentHtml = '', this.editIndex});

  final String currentHtml;
  final int? editIndex;

  @override
  State<VideoDialog> createState() => _VideoDialogState();
}

class _VideoDialogState extends State<VideoDialog> {
  late List<VideoData> _existing;
  late VideoData _draft;

  final _youtubeController = TextEditingController();
  final _trimStartController = TextEditingController();
  final _trimEndController = TextEditingController();

  Uint8List? _srcBytes;
  String? _srcFileName;
  String? _tempFilePath;
  bool _ffmpeg = false;
  bool _busy = false;
  String _status = '';
  final List<TextEditingController> _bookmarkLabels = [];
  final List<TextEditingController> _bookmarkTimes = [];

  @override
  void initState() {
    super.initState();
    _existing = VideoEmbedService.videosIn(widget.currentHtml);
    final initial = (widget.editIndex != null &&
            widget.editIndex! < _existing.length)
        ? _existing[widget.editIndex!]
        : const VideoData();
    _draft = initial;
    if (_draft.isOnline) {
      _youtubeController.text = VideoEmbedService.youtubeWatchUrl(
          _draft.youtubeId!);
    }
    if (_draft.trimStart > 0) {
      _trimStartController.text = _formatSeconds(_draft.trimStart);
    }
    if (_draft.trimEnd > 0) {
      _trimEndController.text = _formatSeconds(_draft.trimEnd);
    }
    for (final b in _draft.bookmarks) {
      _bookmarkLabels.add(TextEditingController(text: b.label));
      _bookmarkTimes.add(TextEditingController(text: _formatSeconds(b.time)));
    }
    _checkFfmpeg();
  }

  @override
  void dispose() {
    _youtubeController.dispose();
    _trimStartController.dispose();
    _trimEndController.dispose();
    for (final c in _bookmarkLabels) {
      c.dispose();
    }
    for (final c in _bookmarkTimes) {
      c.dispose();
    }
    if (_tempFilePath != null) {
      try {
        File(_tempFilePath!).deleteSync();
      } catch (_) {}
    }
    super.dispose();
  }

  Future<void> _checkFfmpeg() async {
    final ok = await VideoEmbedService.ffmpegAvailable();
    if (mounted) {
      setState(() => _ffmpeg = ok);
    }
  }

  static String _formatSeconds(double s) {
    final whole = s.round();
    return '${whole ~/ 60}:${(whole % 60).toString().padLeft(2, '0')}';
  }

  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp4', 'm4v'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes ??
        (file.path != null ? await File(file.path!).readAsBytes() : null);
    if (bytes == null) return;
    final tempPath = '${Directory.systemTemp.path}/ghita_pick_${DateTime.now().millisecondsSinceEpoch}.mp4';
    await File(tempPath).writeAsBytes(bytes);
    if (_tempFilePath != null) {
      try {
        File(_tempFilePath!).deleteSync();
      } catch (_) {}
    }
    setState(() {
      _srcBytes = bytes;
      _srcFileName = file.name;
      _tempFilePath = tempPath;
      _status = '';
    });
    if (_ffmpeg) {
      setState(() => _busy = true);
      final durationMs = await VideoEmbedService.probeDurationMs(tempPath);
      final frame = await VideoEmbedService.extractFrameJpeg(tempPath);
      if (mounted) {
        setState(() {
          _busy = false;
          _draft = _draft.copyWith(
            src: 'data:video/mp4;base64,${base64Encode(bytes)}',
            durationMs: durationMs ?? 0,
            poster: frame != null
                ? 'data:image/jpeg;base64,${base64Encode(frame)}'
                : _draft.poster,
          );
          _status = durationMs != null
              ? '${(durationMs / 1000).toStringAsFixed(1)}s'
              : '';
        });
      }
    } else {
      setState(() {
        _draft = _draft.copyWith(
          src: 'data:video/mp4;base64,${base64Encode(bytes)}',
          youtubeId: null,
        );
      });
    }
  }

  Future<void> _pickPoster() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes ??
        (file.path != null ? await File(file.path!).readAsBytes() : null);
    if (bytes == null) return;
    setState(() {
      _draft = _draft.copyWith(
        poster: 'data:image/${file.extension == 'png' ? 'png' : 'jpeg'};base64,${base64Encode(bytes)}',
      );
    });
  }

  void _addBookmark() {
    setState(() {
      _bookmarkLabels.add(TextEditingController());
      _bookmarkTimes.add(TextEditingController());
    });
  }

  void _removeBookmark(int index) {
    setState(() {
      _bookmarkLabels[index].dispose();
      _bookmarkTimes[index].dispose();
      _bookmarkLabels.removeAt(index);
      _bookmarkTimes.removeAt(index);
    });
  }

  double _parseSeconds(String text) {
    final parts = text.trim().split(':');
    if (parts.length == 2) {
      final m = int.tryParse(parts[0]) ?? 0;
      final s = double.tryParse(parts[1]) ?? 0;
      return m * 60 + s;
    }
    return double.tryParse(text.trim()) ?? 0;
  }

  Future<void> _apply() async {
    if (_busy) return;
    final youtubeUrl = _youtubeController.text.trim();
    final trimStart = _parseSeconds(_trimStartController.text);
    final trimEnd = _parseSeconds(_trimEndController.text);

    setState(() => _busy = true);
    try {
      var draft = _draft;
      if (youtubeUrl.isNotEmpty) {
        final id = VideoEmbedService.parseYouTubeId(youtubeUrl);
        if (id == null) {
          if (mounted) {
            setState(() => _busy = false);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(context.l10n.videoInvalidUrl),
            ));
          }
          return;
        }
        draft = draft.copyWith(
          youtubeId: id,
          src: '',
          trimStart: 0,
          trimEnd: 0,
        );
        if (draft.poster.isEmpty) {
          final thumb = await VideoEmbedService.fetchYouTubeThumbnail(id);
          if (thumb != null && mounted) {
            draft = draft.copyWith(
                poster: VideoEmbedService.thumbnailDataUri(thumb));
          }
        }
      } else if (_srcBytes != null) {
        // Apply the trim window with FFmpeg when possible: the embedded file
        // itself becomes the trimmed cut (timestamps stay for the HTML
        // player only when FFmpeg is unavailable).
        var bytes = _srcBytes!;
        if (_ffmpeg &&
            _tempFilePath != null &&
            trimEnd > trimStart &&
            trimStart >= 0) {
          final trimmed =
              await VideoEmbedService.trimToBytes(_tempFilePath!, trimStart, trimEnd);
          if (trimmed != null) {
            bytes = trimmed;
            if (mounted) {
              draft = draft.copyWith(
                src: 'data:video/mp4;base64,${base64Encode(bytes)}',
                trimStart: 0,
                trimEnd: 0,
              );
            }
          }
        }
        if (draft.src.isEmpty) {
          draft = draft.copyWith(
            src: 'data:video/mp4;base64,${base64Encode(bytes)}',
            trimStart: trimStart,
            trimEnd: trimEnd,
          );
        }
      }
      final bookmarks = <VideoBookmark>[
        for (var i = 0; i < _bookmarkLabels.length; i++)
          VideoBookmark(
            time: _parseSeconds(_bookmarkTimes[i].text),
            label: _bookmarkLabels[i].text.trim(),
          ),
      ]..removeWhere((b) => b.label.isEmpty && b.time <= 0);

      final result = draft.copyWith(bookmarks: bookmarks);
      if (mounted) {
        Navigator.pop(context, result);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isOnline = _draft.isOnline;
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.movie_outlined),
          const SizedBox(width: 10),
          Text(widget.editIndex == null ? l.insertVideo : l.editVideo),
        ],
      ),
      content: SizedBox(
        width: 640,
        height: 620,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_existing.isNotEmpty) ...[
                Text(l.videoExisting,
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
                          _existing[i].isOnline
                              ? 'YouTube ${_existing[i].youtubeId}'
                              : 'Video ${i + 1}',
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
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                      value: 'file',
                      label: Text(l.videoFromFile),
                      icon: const Icon(Icons.video_file_outlined)),
                  ButtonSegment(
                      value: 'youtube',
                      label: Text(l.videoFromYoutube),
                      icon: const Icon(Icons.link)),
                ],
                selected: {isOnline ? 'youtube' : 'file'},
                onSelectionChanged: (v) {
                  setState(() {
                    if (v.first == 'file' && isOnline) {
                      _draft = _draft.copyWith(youtubeId: null);
                      _youtubeController.clear();
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
              if (isOnline)
                TextField(
                  controller: _youtubeController,
                  decoration: InputDecoration(
                    labelText: l.videoYoutubeUrl,
                    hintText: 'https://www.youtube.com/watch?v=…',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                )
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _pickVideo,
                        icon: const Icon(Icons.folder_open),
                        label: Text(
                          _srcFileName ?? l.videoPickFile,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    if (_busy) ...[
                      const SizedBox(width: 8),
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ],
                  ],
                ),
                if (_status.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(_status,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _trimStartController,
                        decoration: InputDecoration(
                          labelText: l.videoTrimStart,
                          hintText: '0:05',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _trimEndController,
                        decoration: InputDecoration(
                          labelText: l.videoTrimEnd,
                          hintText: '0:30',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                if (!_ffmpeg) ...[
                  const SizedBox(height: 4),
                  Text(l.videoNoFfmpeg,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          )),
                ],
              ],
              const SizedBox(height: 10),
              CheckboxListTile(
                value: _draft.autoplay,
                title: Text(l.videoAutoplay),
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (v) =>
                    setState(() => _draft = _draft.copyWith(autoplay: v)),
              ),
              CheckboxListTile(
                value: _draft.loop,
                title: Text(l.videoLoop),
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (v) =>
                    setState(() => _draft = _draft.copyWith(loop: v)),
              ),
              const SizedBox(height: 8),
              Text(l.videoPoster,
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (_draft.poster.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.memory(
                        _posterBytes(_draft.poster) ??
                            Uint8List.fromList(const []),
                        width: 96,
                        height: 54,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox(
                          width: 96,
                          height: 54,
                          child: ColoredBox(color: Colors.black),
                        ),
                      ),
                    ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: _pickPoster,
                    icon: const Icon(Icons.image_outlined),
                    label: Text(_draft.poster.isNotEmpty
                        ? l.videoChangePoster
                        : l.videoChoosePoster),
                  ),
                  if (_draft.poster.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    IconButton(
                      onPressed: () => setState(
                          () => _draft = _draft.copyWith(poster: '')),
                      icon: const Icon(Icons.close),
                      tooltip: l.videoRemovePoster,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Text(l.videoBookmarks,
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              for (var i = 0; i < _bookmarkLabels.length; i++)
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _bookmarkLabels[i],
                        decoration: InputDecoration(
                          labelText: l.videoBookmarkLabel,
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _bookmarkTimes[i],
                        decoration: InputDecoration(
                          labelText: l.videoBookmarkTime,
                          hintText: '0:15',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _removeBookmark(i),
                      icon: const Icon(Icons.delete_outline),
                      tooltip: l.videoRemoveBookmark,
                    ),
                  ],
                ),
              TextButton.icon(
                onPressed: _addBookmark,
                icon: const Icon(Icons.add),
                label: Text(l.videoAddBookmark),
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
        FilledButton(
          onPressed: _busy ? null : _apply,
          child: Text(widget.editIndex == null ? l.insertVideo : l.save),
        ),
      ],
    );
  }

  Uint8List? _posterBytes(String dataUri) {
    const prefix = ';base64,';
    final idx = dataUri.indexOf(prefix);
    if (idx < 0) return null;
    try {
      return base64Decode(dataUri.substring(idx + prefix.length));
    } catch (_) {
      return null;
    }
  }
}
