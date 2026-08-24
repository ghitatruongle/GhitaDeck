/// Central release metadata for the GhitaPPT application.
///
/// Keep [appVersion] aligned with pubspec.yaml. The separate schema and
/// protocol versions intentionally do not change for every app release.
class BuildInfo {
  BuildInfo._();

  static const String productName = 'GhitaPPT Converter';
  static const String appVersion = '2.0.1-beta.1';
  static const String coreVersion = '2.0.1';
  static const String channel = 'beta';
  static const int buildNumber = 1;
  static const String numericVersion = '2.0.1.1';

  /// Version of the LAN collaboration wire protocol.
  static const int collaborationProtocolVersion = 2;

  /// Version of the serialized .ghita document schema.
  static const int bundleSchemaVersion = 2;

  static String get displayVersion => '$appVersion+$buildNumber';
  static String get userAgent => '$productName/$displayVersion';
}
