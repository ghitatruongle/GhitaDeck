class NetworkContentPolicy {
  NetworkContentPolicy._();

  static const String prefKey = 'presentation_network_content';

  static bool remoteAllowed = false;
  static bool userTouched = false;

  static String get _mediaSources => remoteAllowed ? 'data: https:' : 'data:';

  static String deckContentSecurityPolicy() =>
      "default-src 'none'; img-src $_mediaSources; media-src $_mediaSources; "
      "font-src data:; style-src 'unsafe-inline'; "
      "script-src 'unsafe-inline'";

  static String previewContentSecurityPolicy() =>
      "default-src 'none'; img-src $_mediaSources; media-src $_mediaSources; "
      "font-src data:; style-src 'unsafe-inline'";
}
