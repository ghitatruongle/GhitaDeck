import 'dart:convert';

/// Presentation mode (Track 36, FEAT 58).
enum ShowMode {
  /// Full-screen with a human presenter (default).
  presenter,

  /// Windowed, viewer-driven browsing.
  browsed,

  /// Full-screen kiosk loop; exits only via the app UI.
  kiosk,
}

/// Set-Up Show configuration (Track 36, FEAT 58/59/60). Pure settings —
/// persisted in the app session and applied when Present starts.
class SetupShowSettings {
  final ShowMode mode;
  final bool loopContinuously;
  final bool showWithoutNarration;
  final bool showWithoutAnimation;
  final int advanceSeconds;

  /// Preferred pen colour for this presentation session (Track 36, P5).
  final String penColorHex;

  /// Preferred laser colour for this session.
  final String laserColorHex;

  const SetupShowSettings({
    this.mode = ShowMode.presenter,
    this.loopContinuously = false,
    this.showWithoutNarration = false,
    this.showWithoutAnimation = false,
    this.advanceSeconds = 0,
    this.penColorHex = '#ED1C24',
    this.laserColorHex = '#ED1C24',
  });

  SetupShowSettings copyWith({
    ShowMode? mode,
    bool? loopContinuously,
    bool? showWithoutNarration,
    bool? showWithoutAnimation,
    int? advanceSeconds,
    String? penColorHex,
    String? laserColorHex,
  }) =>
      SetupShowSettings(
        mode: mode ?? this.mode,
        loopContinuously: loopContinuously ?? this.loopContinuously,
        showWithoutNarration:
            showWithoutNarration ?? this.showWithoutNarration,
        showWithoutAnimation: showWithoutAnimation ?? this.showWithoutAnimation,
        advanceSeconds: advanceSeconds ?? this.advanceSeconds,
        penColorHex: penColorHex ?? this.penColorHex,
        laserColorHex: laserColorHex ?? this.laserColorHex,
      );

  Map<String, dynamic> toMap() => {
        'mode': mode.name,
        'loopContinuously': loopContinuously,
        'showWithoutNarration': showWithoutNarration,
        'showWithoutAnimation': showWithoutAnimation,
        if (advanceSeconds > 0) 'advanceSeconds': advanceSeconds,
        'penColorHex': penColorHex,
        'laserColorHex': laserColorHex,
      };

  static SetupShowSettings fromMap(Map<String, dynamic> map) =>
      SetupShowSettings(
        mode: ShowMode.values.asNameMap()[map['mode']] ?? ShowMode.presenter,
        loopContinuously: map['loopContinuously'] == true,
        showWithoutNarration: map['showWithoutNarration'] == true,
        showWithoutAnimation: map['showWithoutAnimation'] == true,
        advanceSeconds: (map['advanceSeconds'] as num?)?.toInt() ?? 0,
        penColorHex: (map['penColorHex'] ?? '#ED1C24').toString(),
        laserColorHex: (map['laserColorHex'] ?? '#ED1C24').toString(),
      );

  String toJson() => jsonEncode(toMap());

  static SetupShowSettings fromJson(String json) {
    try {
      final map = jsonDecode(json);
      if (map is Map<String, dynamic>) return fromMap(map);
    } catch (_) {}
    return const SetupShowSettings();
  }

  /// Whether slides should auto-advance on a timer during the show.
  bool get autoAdvance => advanceSeconds > 0;
}
