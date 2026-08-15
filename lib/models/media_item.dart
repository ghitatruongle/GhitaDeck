/// Video model for exported presentations (Track 11, FEAT 5–6, 76).
library;
///
/// Pure Dart + serializable, so video definitions travel inside slide HTML
/// as `<video data-video='…json…'>` tags and cross the worker isolate.
/// The media payload itself lives in the `src`/`poster` attributes of the
/// tag (data: URIs, same storage as images) — the JSON carries playback
/// metadata only.
import 'dart:convert';
class VideoBookmark {
  const VideoBookmark({required this.time, required this.label});

  /// Seconds from the (trimmed) video start.
  final double time;
  final String label;

  Map<String, dynamic> toMap() => {'time': time, 'label': label};

  static VideoBookmark fromMap(Map<String, dynamic> map) => VideoBookmark(
        time: (map['time'] as num?)?.toDouble() ?? 0,
        label: map['label']?.toString() ?? '',
      );
}

/// Embedded (mp4) or online (YouTube) video with playback metadata.
class VideoData {
  const VideoData({
    this.src = '',
    this.poster = '',
    this.trimStart = 0,
    this.trimEnd = 0,
    this.autoplay = false,
    this.loop = false,
    this.youtubeId,
    this.durationMs = 0,
    this.bookmarks = const [],
  });

  /// Local/embedded source as a data: URI (`data:video/mp4;base64,…`) or a
  /// file path. Empty when [youtubeId] is set.
  final String src;

  /// Poster frame as a data: URI (`data:image/jpeg;base64,…`) or empty.
  final String poster;

  /// Trim window in seconds; [trimEnd] 0 means "to the end".
  final double trimStart;
  final double trimEnd;

  /// Start playback automatically when the slide is shown (HTML deck; PPTX
  /// autoplay timing is emitted too).
  final bool autoplay;
  final bool loop;

  /// Online video: the YouTube video id. When set, [src] is ignored on
  /// export — the PPTX gets an external video link, the HTML deck a
  /// thumbnail that opens the video.
  final String? youtubeId;

  /// Media length in milliseconds (probed at insert time when FFmpeg is
  /// available). Used for the PPTX autoplay timeline; 0 falls back to a
  /// default in the exporter.
  final int durationMs;

  /// Time marks for quick jumps (HTML deck player only).
  final List<VideoBookmark> bookmarks;

  bool get isOnline => youtubeId != null && youtubeId!.isNotEmpty;

  VideoData copyWith({
    String? src,
    String? poster,
    double? trimStart,
    double? trimEnd,
    bool? autoplay,
    bool? loop,
    String? youtubeId,
    int? durationMs,
    List<VideoBookmark>? bookmarks,
  }) =>
      VideoData(
        src: src ?? this.src,
        poster: poster ?? this.poster,
        trimStart: trimStart ?? this.trimStart,
        trimEnd: trimEnd ?? this.trimEnd,
        autoplay: autoplay ?? this.autoplay,
        loop: loop ?? this.loop,
        youtubeId: youtubeId ?? this.youtubeId,
        durationMs: durationMs ?? this.durationMs,
        bookmarks: bookmarks ?? this.bookmarks,
      );

  Map<String, dynamic> toMap() => {
        if (src.isNotEmpty) 'src': src,
        if (poster.isNotEmpty) 'poster': poster,
        if (trimStart > 0) 'trimStart': trimStart,
        if (trimEnd > 0) 'trimEnd': trimEnd,
        if (autoplay) 'autoplay': true,
        if (loop) 'loop': true,
        if (youtubeId != null) 'youtubeId': youtubeId,
        if (durationMs > 0) 'durationMs': durationMs,
        if (bookmarks.isNotEmpty)
          'bookmarks': bookmarks.map((b) => b.toMap()).toList(),
      };

  static VideoData fromJson(String json) {
    try {
      final map = jsonDecode(json);
      if (map is! Map<String, dynamic>) return const VideoData();
      return fromMap(map);
    } catch (_) {
      return const VideoData();
    }
  }

  static VideoData fromMap(Map<String, dynamic> map) {
    final rawBookmarks = map['bookmarks'];
    return VideoData(
      src: map['src']?.toString() ?? '',
      poster: map['poster']?.toString() ?? '',
      trimStart: (map['trimStart'] as num?)?.toDouble() ?? 0,
      trimEnd: (map['trimEnd'] as num?)?.toDouble() ?? 0,
      autoplay: map['autoplay'] == true,
      loop: map['loop'] == true,
      youtubeId: map['youtubeId']?.toString(),
      durationMs: (map['durationMs'] as num?)?.toInt() ?? 0,
      bookmarks: rawBookmarks is List
          ? rawBookmarks
              .whereType<Map>()
              .map((e) => VideoBookmark.fromMap(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
    );
  }

  String toJson() => jsonEncode(toMap());

  static VideoData sample() => const VideoData(
        src:
            'data:video/mp4;base64,AAAAIGZ0eXBpc29tAAACAGlzb21pc28yYXZjMW1wNDEAA',
        trimStart: 1,
        trimEnd: 6,
        loop: true,
        durationMs: 8000,
        bookmarks: [
          VideoBookmark(time: 1.5, label: 'Mở đầu'),
          VideoBookmark(time: 4.2, label: 'Kết luận'),
        ],
      );
}
