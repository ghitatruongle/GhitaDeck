/// Video embed helpers for exported presentations (Track 11, FEAT 5–6, 76).
///
/// Video blocks live in slide HTML as native `<video>` tags carrying
/// `data-video='{json}'` (playback metadata). The payload is stored in the
/// tag's `src`/`poster` attributes as data: URIs — the same storage as
/// images — so it travels through htmlContent unchanged.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/media_item.dart';

/// Media kind for the merged slide timeline (Track 11 video, Track 13 audio).
enum MediaTimingKind { video, audio }

/// Playback spec for one media shape inside a merged slide timeline.
class MediaTimingSpec {
  const MediaTimingSpec({
    required this.spid,
    required this.autoplay,
    required this.loop,
    required this.durationMs,
    this.kind = MediaTimingKind.video,
    this.acrossSlides = false,
  });

  final int spid;
  final bool autoplay;
  final bool loop;
  final int durationMs;
  final MediaTimingKind kind;

  /// Audio only: keep playing across slide changes (omit the onStopAudio
  /// end condition PowerPoint writes by default).
  final bool acrossSlides;
}

class VideoEmbedService {
  VideoEmbedService._();

  static final RegExp _dataVideoRegExp = RegExp(
    r"""data-video=(['"])(.*?)\1""",
    caseSensitive: false,
    dotAll: true,
  );

  /// Find every `<video data-video='…'>` block in [html], in document order.
  static List<VideoData> videosIn(String html) {
    final videos = <VideoData>[];
    for (final match in _dataVideoRegExp.allMatches(html)) {
      // group(1) is the quote character; group(2) carries the JSON.
      final video = VideoData.fromJson(match.group(2)!);
      if (video.src.isNotEmpty || video.isOnline) {
        videos.add(video);
      }
    }
    return videos;
  }

  /// Serialize a [video] for use inside a single-quoted HTML attribute
  /// (the JSON itself uses double quotes; single quotes are escaped).
  static String escapeAttribute(VideoData video) =>
      video.toJson().replaceAll("'", '&#39;');

  /// Build the `<video>` tag inserted into the slide HTML. `src`/`poster`
  /// are mirrored as attributes so the editor preview (WebView2) renders the
  /// video/poster natively; the JSON remains the single source of truth.
  static String videoMarkup(VideoData video) {
    final b = StringBuffer()..write('<video');
    if (video.src.isNotEmpty) {
      b.write(' src="${_escapeAttr(video.src)}"');
    }
    if (video.poster.isNotEmpty) {
      b.write(' poster="${_escapeAttr(video.poster)}"');
    }
    b
      ..write(' controls')
      ..write(' data-video=\'${escapeAttribute(video)}\'')
      ..write('></video>');
    return b.toString();
  }

  /// Replace the [index]-th video block in [html] with new markup
  /// (0-based, document order — mirrors ChartService.replaceChartAt).
  static String replaceVideoAt(String html, int index, VideoData video) {
    final tagPattern = RegExp(
      r"""<video\b[^>]*data-video=(['"])(.*?)\1[^>]*>.*?</video>""",
      caseSensitive: false,
      dotAll: true,
    );
    final matches = tagPattern.allMatches(html).toList();
    if (index < 0 || index >= matches.length) return html;
    final match = matches[index];
    return html.replaceRange(
      match.start,
      match.end,
      videoMarkup(video),
    );
  }

  /// Number of video blocks in [html].
  static int videoCount(String html) => _dataVideoRegExp.allMatches(html).length;

  // ---- YouTube ----------------------------------------------------------

  static final RegExp _youtubeRegExp = RegExp(
    r'(?:youtu\.be/|youtube\.com/(?:watch\?(?:.*&)?v=|embed/|shorts/|v/))'
    r'([A-Za-z0-9_-]{6,20})',
    caseSensitive: false,
  );

  /// Extract a YouTube video id from a URL, or null when [url] is not a
  /// recognizable YouTube link.
  static String? parseYouTubeId(String url) {
    final match = _youtubeRegExp.firstMatch(url.trim());
    return match?.group(1);
  }

  /// YouTube thumbnail bytes (jpg) for [videoId], or null on any failure.
  /// Guardrails mirror HtmlImageLoader: 10 s timeout, 2 MB cap.
  static Future<Uint8List?> fetchYouTubeThumbnail(String videoId) async {
    final uri = Uri.parse('https://img.youtube.com/vi/$videoId/hqdefault.jpg');
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final bytes = response.bodyBytes;
      if (bytes.length > 2 * 1024 * 1024) return null;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  static String youtubeWatchUrl(String videoId) =>
      'https://www.youtube.com/watch?v=$videoId';

  static String thumbnailDataUri(Uint8List bytes) =>
      'data:image/jpeg;base64,${base64Encode(bytes)}';

  // ---- FFmpeg helpers (trim / poster, Track 11, P4–P5) ------------------
  // FFmpeg is optional: the dialog uses it to cut the file and extract a
  // poster frame when it is installed; without it the video embeds whole and
  // only the HTML player honours the trim timestamps (PPTX plays the full
  // file — documented limit).

  /// Whether `ffmpeg` (and `ffprobe`) are available on PATH.
  static Future<bool> ffmpegAvailable() async {
    try {
      final r = await Process.run('ffmpeg', ['-version']);
      return r.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Media length in milliseconds via `ffprobe`, or null when unavailable.
  static Future<int?> probeDurationMs(String filePath) async {
    try {
      final r = await Process.run('ffprobe', [
        '-v', 'error',
        '-show_entries', 'format=duration',
        '-of', 'default=noprint_wrappers=1:nokey=1',
        filePath,
      ]);
      if (r.exitCode != 0) return null;
      final sec = double.tryParse((r.stdout as String).trim());
      return sec == null ? null : (sec * 1000).round();
    } catch (_) {
      return null;
    }
  }

  /// Extract one JPEG frame (the poster) at [at] seconds, or null on failure.
  static Future<Uint8List?> extractFrameJpeg(
    String filePath, {
    double at = 0,
  }) async {
    Directory? dir;
    try {
      dir = await Directory.systemTemp.createTemp('ghita_frame_');
      final out = '${dir.path}/frame.jpg';
      final r = await Process.run('ffmpeg', [
        '-y', '-ss', '$at', '-i', filePath,
        '-frames:v', '1', '-q:v', '3', out,
      ]);
      if (r.exitCode != 0) return null;
      return await File(out).readAsBytes();
    } catch (_) {
      return null;
    } finally {
      try {
        await dir?.delete(recursive: true);
      } catch (_) {}
    }
  }

  /// Trim [filePath] to the [start, end] window (stream copy first — no
  /// re-encode; falls back to an ultrafast re-encode when the copy fails).
  /// Returns the trimmed mp4 bytes, or null on failure.
  static Future<Uint8List?> trimToBytes(
    String filePath,
    double start,
    double end,
  ) async {
    if (end <= start) return null;
    Directory? dir;
    try {
      dir = await Directory.systemTemp.createTemp('ghita_trim_');
      final out = '${dir.path}/trim.mp4';
      var r = await Process.run('ffmpeg', [
        '-y', '-ss', '$start', '-i', filePath,
        '-t', '${end - start}', '-c', 'copy', out,
      ]);
      if (r.exitCode != 0) {
        r = await Process.run('ffmpeg', [
          '-y', '-ss', '$start', '-i', filePath,
          '-t', '${end - start}',
          '-c:v', 'libx264', '-preset', 'ultrafast', '-c:a', 'aac', out,
        ]);
      }
      if (r.exitCode != 0) return null;
      return await File(out).readAsBytes();
    } catch (_) {
      return null;
    } finally {
      try {
        await dir?.delete(recursive: true);
      } catch (_) {}
    }
  }

  // ---- PPTX XML builders (used by PPTGenerator) --------------------------

  /// One `<p:pic>` that doubles as poster and video carrier — the structure
  /// PowerPoint itself writes (verified against a COM `AddMediaObject2`
  /// golden): `blipFill` holds the poster image, `p:nvPr/a:videoFile`
  /// points at the mp4 via a `video` relationship, and the cNvPr carries the
  /// `ppaction://media` click action with an *empty* r:id (no hyperlink rel).
  /// The `p14:media` extension references the legacy `media` relationship —
  /// PowerPoint writes both rels to the same file.
  static String videoPicXml({
    required int shapeId,
    required String name,
    required String videoRid,
    required String posterRid,
    required int offX,
    required int offY,
    required int extCx,
    required int extCy,
    String? mediaRid,
  }) {
    final b = StringBuffer()
      ..write('<p:pic>\n')
      ..write('  <p:nvPicPr>')
      ..write('<p:cNvPr id="$shapeId" name="$name">')
      ..write('<a:hlinkClick r:id="" action="ppaction://media"/>')
      ..write('</p:cNvPr>')
      ..write('<p:cNvPicPr><a:picLocks noChangeAspect="1"/></p:cNvPicPr>')
      ..write('<p:nvPr>')
      ..write(
          '<a:videoFile xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" r:link="$videoRid"/>');
    if (mediaRid != null && mediaRid.isNotEmpty) {
      b
        ..write('<p:extLst><p:ext uri="{DAA4B4D4-6D71-4841-9C94-3DE7FCFB9230}">')
        ..write('<p14:media xmlns:p14="http://schemas.microsoft.com/office/powerpoint/2010/main" '
            'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" r:embed="$mediaRid"/>')
        ..write('</p:ext></p:extLst>');
    }
    b
      ..write('</p:nvPr>')
      ..write('</p:nvPicPr>\n')
      ..write('  <p:blipFill>')
      ..write('<a:blip r:embed="$posterRid"/>')
      ..write('<a:stretch><a:fillRect/></a:stretch>')
      ..write('</p:blipFill>\n')
      ..write('  <p:spPr>')
      ..write('<a:xfrm><a:off x="$offX" y="$offY"/>'
          '<a:ext cx="$extCx" cy="$extCy"/></a:xfrm>')
      ..write('<a:prstGeom prst="rect"><a:avLst/></a:prstGeom>')
      ..write('</p:spPr>\n')
      ..write('</p:pic>');
    return b.toString();
  }

  /// Playback spec for one media shape inside a merged slide timeline.
  ///
  /// One `<p:par>` (a single media's timeline) matching PowerPoint's own
  /// structure — see [mediaTimingXml] for the shapes it covers.
  static (String, int) _mediaTimingPar(
    MediaTimingSpec media,
    int nextId,
  ) {
    final b = StringBuffer()..write('<p:par>');
    final spid = media.spid;
    if (media.autoplay) {
      final id = nextId;
      b
        ..write('<p:cTn id="$id" dur="indefinite" restart="never" nodeType="tmRoot">')
        ..write('<p:childTnLst><p:seq concurrent="1" nextAc="seek">')
        ..write('<p:cTn id="${id + 1}" dur="indefinite" nodeType="mainSeq">')
        ..write('<p:childTnLst><p:par>')
        ..write('<p:cTn id="${id + 2}" fill="hold">')
        ..write('<p:stCondLst><p:cond delay="indefinite"/></p:stCondLst>')
        ..write('<p:childTnLst><p:par>')
        ..write('<p:cTn id="${id + 3}" fill="hold">')
        ..write('<p:stCondLst><p:cond delay="0"/></p:stCondLst>')
        ..write('<p:childTnLst><p:par>')
        ..write(
            '<p:cTn id="${id + 4}" presetID="1" presetClass="mediacall" presetSubtype="0" fill="hold" nodeType="clickEffect">')
        ..write('<p:stCondLst><p:cond delay="0"/></p:stCondLst>')
        ..write('<p:childTnLst>')
        ..write('<p:cmd type="call" cmd="playFrom(0.0)">')
        ..write('<p:cBhvr><p:cTn id="${id + 5}" dur="${media.durationMs}" fill="hold"/>')
        ..write('<p:tgtEl><p:spTgt spid="$spid"/></p:tgtEl></p:cBhvr>')
        ..write('</p:cmd></p:childTnLst></p:cTn>')
        ..write('</p:par></p:childTnLst></p:cTn>')
        ..write('</p:par></p:childTnLst></p:cTn>')
        ..write('</p:par></p:childTnLst></p:cTn>')
        ..write('<p:prevCondLst><p:cond evt="onPrev" delay="0">'
            '<p:tgtEl><p:sldTgt/></p:tgtEl></p:cond></p:prevCondLst>')
        ..write('<p:nextCondLst><p:cond evt="onNext" delay="0">'
            '<p:tgtEl><p:sldTgt/></p:tgtEl></p:cond></p:nextCondLst>')
        ..write('</p:seq>');
      nextId += 6;
    } else {
      final id = nextId;
      b
        ..write('<p:cTn id="$id" dur="indefinite" restart="never" nodeType="tmRoot">')
        ..write('<p:childTnLst><p:seq concurrent="1" nextAc="seek">')
        ..write(
            '<p:cTn id="${id + 1}" restart="whenNotActive" fill="hold" evtFilter="cancelBubble" nodeType="interactiveSeq">')
        ..write('<p:stCondLst><p:cond evt="onClick" delay="0">'
            '<p:tgtEl><p:spTgt spid="$spid"/></p:tgtEl></p:cond></p:stCondLst>')
        ..write('<p:endSync evt="end" delay="0"><p:rtn val="all"/></p:endSync>')
        ..write('<p:childTnLst><p:par>')
        ..write('<p:cTn id="${id + 2}" fill="hold">')
        ..write('<p:stCondLst><p:cond delay="0"/></p:stCondLst>')
        ..write('<p:childTnLst><p:par>')
        ..write('<p:cTn id="${id + 3}" fill="hold">')
        ..write('<p:stCondLst><p:cond delay="0"/></p:stCondLst>')
        ..write('<p:childTnLst><p:par>')
        ..write(
            '<p:cTn id="${id + 4}" presetID="${media.kind == MediaTimingKind.audio ? '1' : '2'}" presetClass="mediacall" presetSubtype="0" fill="hold" nodeType="clickEffect">')
        ..write('<p:stCondLst><p:cond delay="0"/></p:stCondLst>')
        ..write('<p:childTnLst>')
        ..write(media.kind == MediaTimingKind.audio
            ? '<p:cmd type="call" cmd="playFrom(0.0)">'
            : '<p:cmd type="call" cmd="togglePause">')
        ..write(media.kind == MediaTimingKind.audio
            ? '<p:cBhvr><p:cTn id="${id + 5}" dur="${media.durationMs}" fill="hold"/>'
            : '<p:cBhvr><p:cTn id="${id + 5}" dur="1" fill="hold"/>')
        ..write('<p:tgtEl><p:spTgt spid="$spid"/></p:tgtEl></p:cBhvr>')
        ..write('</p:cmd></p:childTnLst></p:cTn>')
        ..write('</p:par></p:childTnLst></p:cTn>')
        ..write('</p:par></p:childTnLst></p:cTn>')
        ..write('</p:par></p:childTnLst></p:cTn>')
        ..write('<p:nextCondLst><p:cond evt="onClick" delay="0">'
            '<p:tgtEl><p:spTgt spid="$spid"/></p:tgtEl></p:cond></p:nextCondLst>')
        ..write('</p:seq>');
      nextId += 6;
    }
    // Media node — loop adds repeatCount="indefinite"; audio stops on slide
    // change via the onStopAudio end condition unless it plays across slides.
    b
      ..write(media.kind == MediaTimingKind.audio
          ? '<p:audio><p:cMediaNode vol="80000">'
          : '<p:video><p:cMediaNode vol="80000">')
      ..write('<p:cTn id="$nextId"')
      ..write(media.loop ? ' repeatCount="indefinite"' : '')
      ..write(' fill="hold" display="0">')
      ..write('<p:stCondLst><p:cond delay="indefinite"/></p:stCondLst>')
      ..write(media.kind == MediaTimingKind.audio && !media.acrossSlides
          ? '<p:endCondLst><p:cond evt="onStopAudio" delay="0">'
              '<p:tgtEl><p:sldTgt/></p:tgtEl></p:cond></p:endCondLst>'
          : '')
      ..write('</p:cTn>')
      ..write('<p:tgtEl><p:spTgt spid="$spid"/></p:tgtEl>')
      ..write(media.kind == MediaTimingKind.audio
          ? '</p:cMediaNode></p:audio>'
          : '</p:cMediaNode></p:video>');
    nextId++;
    if (media.autoplay) {
      // PowerPoint appends the click-to-pause interactive sequence even when
      // the video plays automatically.
      final id = nextId;
      b
        ..write('<p:seq concurrent="1" nextAc="seek">')
        ..write(
            '<p:cTn id="$id" restart="whenNotActive" fill="hold" evtFilter="cancelBubble" nodeType="interactiveSeq">')
        ..write('<p:stCondLst><p:cond evt="onClick" delay="0">'
            '<p:tgtEl><p:spTgt spid="$spid"/></p:tgtEl></p:cond></p:stCondLst>')
        ..write('<p:endSync evt="end" delay="0"><p:rtn val="all"/></p:endSync>')
        ..write('<p:childTnLst><p:par>')
        ..write('<p:cTn id="${id + 1}" fill="hold">')
        ..write('<p:stCondLst><p:cond delay="0"/></p:stCondLst>')
        ..write('<p:childTnLst><p:par>')
        ..write('<p:cTn id="${id + 2}" fill="hold">')
        ..write('<p:stCondLst><p:cond delay="0"/></p:stCondLst>')
        ..write('<p:childTnLst><p:par>')
        ..write(
            '<p:cTn id="${id + 3}" presetID="2" presetClass="mediacall" presetSubtype="0" fill="hold" nodeType="clickEffect">')
        ..write('<p:stCondLst><p:cond delay="0"/></p:stCondLst>')
        ..write('<p:childTnLst>')
        ..write('<p:cmd type="call" cmd="togglePause">')
        ..write('<p:cBhvr><p:cTn id="${id + 4}" dur="1" fill="hold"/>')
        ..write('<p:tgtEl><p:spTgt spid="$spid"/></p:tgtEl></p:cBhvr>')
        ..write('</p:cmd></p:childTnLst></p:cTn>')
        ..write('</p:par></p:childTnLst></p:cTn>')
        ..write('</p:par></p:childTnLst></p:cTn>')
        ..write('</p:par></p:childTnLst></p:cTn>')
        ..write('<p:nextCondLst><p:cond evt="onClick" delay="0">'
            '<p:tgtEl><p:spTgt spid="$spid"/></p:tgtEl></p:cond></p:nextCondLst>')
        ..write('</p:seq>');
      nextId += 5;
    }
    b.write('</p:childTnLst></p:cTn></p:par>');
    return (b.toString(), nextId);
  }

  /// Merged `<p:timing>` for every media shape on one slide. Each [MediaTimingSpec]
  /// becomes one `<p:par>`; timeline ids run sequentially across the whole
  /// timing (PowerPoint numbers them 1..N).
  static String mediaTimingXml(List<MediaTimingSpec> media) {
    if (media.isEmpty) return '';
    return '<p:timing><p:tnLst>${mediaTimingInnerXml(media)}</p:tnLst></p:timing>';
  }

  /// The `<p:tnLst>` inner content for the media specs — used when the slide
  /// also carries 3D-model animation timelines (Track 14) that must share
  /// the single `p:timing` element.
  static String mediaTimingInnerXml(List<MediaTimingSpec> media) {
    if (media.isEmpty) return '';
    final b = StringBuffer();
    var nextId = 1;
    for (final m in media) {
      final (part, nid) = _mediaTimingPar(m, nextId);
      b.write(part);
      nextId = nid;
    }
    return b.toString();
  }

  /// One `<p:pic>` for narration audio (Track 13) — same structure as the
  /// video pic but with `p:nvPr/a:audioFile` and PowerPoint's speaker icon
  /// in the blip fill (icon bytes extracted from a COM golden deck).
  static String audioPicXml({
    required int shapeId,
    required String name,
    required String audioRid,
    required String posterRid,
    String? mediaRid,
    int offX = 1269999,
    int offY = 1269999,
    int iconSize = 1270000,
  }) {
    final b = StringBuffer()
      ..write('<p:pic>\n')
      ..write('  <p:nvPicPr>')
      ..write('<p:cNvPr id="$shapeId" name="$name">')
      ..write('<a:hlinkClick r:id="" action="ppaction://media"/>')
      ..write('</p:cNvPr>')
      ..write('<p:cNvPicPr><a:picLocks noChangeAspect="1"/></p:cNvPicPr>')
      ..write('<p:nvPr>')
      ..write(
          '<a:audioFile xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" r:link="$audioRid"/>');
    if (mediaRid != null && mediaRid.isNotEmpty) {
      b
        ..write('<p:extLst><p:ext uri="{DAA4B4D4-6D71-4841-9C94-3DE7FCFB9230}">')
        ..write('<p14:media xmlns:p14="http://schemas.microsoft.com/office/powerpoint/2010/main" '
            'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" r:embed="$mediaRid"/>')
        ..write('</p:ext></p:extLst>');
    }
    b
      ..write('</p:nvPr>')
      ..write('</p:nvPicPr>\n')
      ..write('  <p:blipFill>')
      ..write('<a:blip r:embed="$posterRid"/>')
      ..write('<a:stretch><a:fillRect/></a:stretch>')
      ..write('</p:blipFill>\n')
      ..write('  <p:spPr>')
      ..write('<a:xfrm><a:off x="$offX" y="$offY"/>'
          '<a:ext cx="$iconSize" cy="$iconSize"/></a:xfrm>')
      ..write('<a:prstGeom prst="rect"><a:avLst/></a:prstGeom>')
      ..write('</p:spPr>\n')
      ..write('</p:pic>');
    return b.toString();
  }

  /// Fallback poster used when a video has no poster image: a 1×1 black
  /// PNG, stretched by PowerPoint to the shape. Keeps `<p:pic>` schema-valid
  /// (blipFill is required) without any runtime dependency.
  static const String fallbackPosterDataUri =
      'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAACXBIWXMAAAABAAAAAQBPJcTWAAAADElEQVR4nGNkYGAAAAAIAAI76MGHAAAAAElFTkSuQmCC';

  static String _escapeAttr(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('"', '&quot;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}
