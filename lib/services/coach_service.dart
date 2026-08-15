import 'dart:convert';

/// One feedback item for a slide (Track 38, P5/P6).
class CoachFeedback {
  final String title;
  final String detail;

  const CoachFeedback({required this.title, required this.detail});
}

/// Coaching result for the whole rehearsal (Track 38, P6).
class CoachResult {
  final int score; // 0–100
  final int wordsPerMinute;
  final int fillerCount;
  final int pauseSeconds;
  final List<CoachFeedback> feedback;

  const CoachResult({
    required this.score,
    required this.wordsPerMinute,
    required this.fillerCount,
    required this.pauseSeconds,
    required this.feedback,
  });

  Map<String, dynamic> toMap() => {
        'score': score,
        'wordsPerMinute': wordsPerMinute,
        'fillerCount': fillerCount,
        'pauseSeconds': pauseSeconds,
        'feedback': feedback
            .map((f) => {'title': f.title, 'detail': f.detail})
            .toList(),
      };

  static CoachResult fromMap(Map<String, dynamic> map) => CoachResult(
        score: (map['score'] as num?)?.toInt() ?? 0,
        wordsPerMinute: (map['wordsPerMinute'] as num?)?.toInt() ?? 0,
        fillerCount: (map['fillerCount'] as num?)?.toInt() ?? 0,
        pauseSeconds: (map['pauseSeconds'] as num?)?.toInt() ?? 0,
        feedback: (map['feedback'] as List? ?? const [])
            .map((e) => CoachFeedback(
                  title: (e['title'] ?? '').toString(),
                  detail: (e['detail'] ?? '').toString(),
                ))
            .toList(),
      );
}

/// Presenter Coach (Track 38, FEAT 63).
///
/// Local analysis is pure Dart: word count → pace, filler words in EN/VI
/// (um/uh/ừm/à/...), and long-silence heuristics. The AI deep pass
/// ([aiAnalyze]) is injected as a callback so tests can stub it; the app wires
/// the configured AI provider.
class CoachService {
  CoachService._();

  /// Filler words by locale: English and Vietnamese.
  static const List<String> _fillerEn = [
    'um', 'uh', 'er', 'hmm', 'like', 'you know', 'basically', 'actually',
  ];
  static const List<String> _fillerVi = ['ừm', 'à', 'ờ', 'ơ', 'thì', 'mà'];

  /// Tokenize transcript into words (handles Vietnamese by splitting on
  /// spaces — no dictionary required for a heuristic pass).
  static List<String> tokens(String transcript) {
    return transcript
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
  }

  static int countFillerWords(String transcript) {
    final words = tokens(transcript);
    var count = 0;
    for (final w in words) {
      if (_fillerEn.contains(w) || _fillerVi.contains(w)) count++;
    }
    // Multi-word fillers ("you know") — count exact phrase occurrences too.
    count += RegExp(r'\byou know\b', caseSensitive: false)
        .allMatches(transcript)
        .length;
    return count;
  }

  /// Estimate long pauses from raw silence markers (seconds) — the recorder
  /// feeds gaps > 1.5s.
  static int pauseSeconds(List<double> gapsSeconds) =>
      gapsSeconds.where((g) => g >= 1.5).fold(0, (sum, g) => sum + g.round());

  /// Local analysis over a transcript + [durationSeconds].
  static CoachResult analyze({
    required String transcript,
    required int durationSeconds,
    List<double> gapsSeconds = const [],
    int totalSlides = 1,
  }) {
    final words = tokens(transcript).length;
    final wpm = durationSeconds > 0
        ? (words / durationSeconds * 60).round()
        : 0;
    final fillers = countFillerWords(transcript);
    final pauses = pauseSeconds(gapsSeconds);
    final feedback = <CoachFeedback>[];

    if (wpm > 0) {
      if (wpm < 90) {
        feedback.add(const CoachFeedback(
            title: 'Pace is slow', detail: 'Aim for 120–150 words per minute.'));
      } else if (wpm > 170) {
        feedback.add(const CoachFeedback(
            title: 'Pace is fast', detail: 'Slow down — aim for 120–150 wpm.'));
      } else {
        feedback.add(const CoachFeedback(
            title: 'Good pace', detail: 'Your speaking pace is on target.'));
      }
    }
    if (fillers > 0) {
      feedback.add(CoachFeedback(
          title: 'Filler words',
          detail: 'Found $fillers filler word(s) — try pausing instead.'));
    }
    if (pauses >= 5) {
      feedback.add(const CoachFeedback(
          title: 'Long pauses', detail: 'Several pauses over 1.5s detected.'));
    }

    var score = 100;
    score -= (wpm < 90 || wpm > 170) ? 10 : 0;
    score -= fillers * 5;
    score -= pauses ~/ 2;
    score = score.clamp(0, 100);

    return CoachResult(
      score: score,
      wordsPerMinute: wpm,
      fillerCount: fillers,
      pauseSeconds: pauses,
      feedback: feedback,
    );
  }

  /// Optional AI deep pass: [aiAnalyze] receives the transcript and slide
  /// count and returns JSON [CoachResult]. Wired in the app to the configured
  /// AI provider; the callback may throw — the caller falls back to local.
  static Future<CoachResult> aiAnalyze({
    required String transcript,
    required int durationSeconds,
    required Future<String> Function(String prompt) aiPrompt,
  }) async {
    final prompt =
        'You are a presentation coach. Analyze this transcript '
        '(duration ${durationSeconds}s). Return ONLY a JSON object with keys '
        'score (0-100), wordsPerMinute, fillerCount, pauseSeconds, feedback '
        '(array of {title, detail}). Transcript:\n$transcript';
    final raw = await aiPrompt(prompt);
    try {
      final map = jsonDecode(raw);
      if (map is Map<String, dynamic>) {
        final fb = (map['feedback'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map((e) => CoachFeedback(
                  title: (e['title'] ?? '').toString(),
                  detail: (e['detail'] ?? '').toString(),
                ))
            .toList();
        return CoachResult(
          score: ((map['score'] as num?)?.toInt() ?? 0).clamp(0, 100),
          wordsPerMinute: (map['wordsPerMinute'] as num?)?.toInt() ?? 0,
          fillerCount: (map['fillerCount'] as num?)?.toInt() ?? 0,
          pauseSeconds: (map['pauseSeconds'] as num?)?.toInt() ?? 0,
          feedback: fb,
        );
      }
    } catch (_) {}
    throw Exception('AI coach returned invalid JSON');
  }
}
