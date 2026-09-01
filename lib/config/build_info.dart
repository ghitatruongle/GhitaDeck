/// Central release metadata for the GhitaPPT application.
///
/// Keep [appVersion] aligned with pubspec.yaml. The separate schema and
/// protocol versions intentionally do not change for every app release.
class BuildInfo {
  BuildInfo._();

  static const String productName = 'GhitaPPT Converter';
  static const String appVersion = '2.0.5-demo';
  static const String coreVersion = '2.0.5-demo';
  static const String channel = 'stable';
  static const int buildNumber = 4;
  static const String numericVersion = '2.0.5.4';

  /// Version of the LAN collaboration wire protocol.
  static const int collaborationProtocolVersion = 2;

  /// Version of the serialized .ghita document schema.
  static const int bundleSchemaVersion = 2;

  static String get displayVersion => '$appVersion+$buildNumber';
  static String get userAgent => '$productName/$displayVersion';
}
