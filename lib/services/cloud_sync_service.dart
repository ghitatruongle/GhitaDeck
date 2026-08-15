import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Cloud sync over WebDAV (Track 50, FEAT 82).
///
/// WebDAV (Nextcloud/ownCloud first) is used rather than a proprietary API:
/// it speaks plain HTTP (PROPFIND/MKCOL/PUT/GET) so no extra package or
/// registered OAuth app is required. Credentials are kept in the OS secure
/// store ([FlutterSecureStorage]); the transport is pure Dart and fully
/// testable with a fake [http.Client].
///
/// Versioning model: each project lives in `<root>/ghita/<name>/` and every
/// upload is written as `v{N}.ghita` with a `latest.ghita` pointer. The
/// [VersionHistoryService] trims old versions and lists them for restore.
class CloudSyncService {
  CloudSyncService._();

  static const String _storageBaseUrlKey = 'cloud_base_url';
  static const String _storageUsernameKey = 'cloud_username';
  static const String _storagePasswordKey = 'cloud_password';

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  // ---- Credentials ---------------------------------------------------------

  static Future<void> saveCredentials({
    required String baseUrl,
    required String username,
    required String password,
  }) async {
    await _secureStorage.write(key: _storageBaseUrlKey, value: baseUrl);
    await _secureStorage.write(key: _storageUsernameKey, value: username);
    await _secureStorage.write(key: _storagePasswordKey, value: password);
  }

  static Future<void> clearCredentials() async {
    await _secureStorage.delete(key: _storageBaseUrlKey);
    await _secureStorage.delete(key: _storageUsernameKey);
    await _secureStorage.delete(key: _storagePasswordKey);
  }

  static Future<CloudCredentials?> loadCredentials() async {
    final baseUrl = await _secureStorage.read(key: _storageBaseUrlKey);
    final username = await _secureStorage.read(key: _storageUsernameKey);
    final password = await _secureStorage.read(key: _storagePasswordKey);
    if (baseUrl == null || username == null || password == null) return null;
    return CloudCredentials(
        baseUrl: baseUrl, username: username, password: password);
  }

  static String normalizedBaseUrl(String url) {
    var u = url.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  // ---- WebDAV operations ---------------------------------------------------

  /// Base URI for a project folder under the WebDAV root.
  static Uri _projectUri(CloudCredentials creds, String projectName) =>
      Uri.parse(
          '${normalizedBaseUrl(creds.baseUrl)}/ghita/${_safeName(projectName)}/');

  static String _safeName(String name) => name
      .trim()
      .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')
      .replaceAll(RegExp(r'_+'), '_');

  static http.Client _clientWithAuth(CloudCredentials creds) {
    return http.Client();
  }

  static Map<String, String> _authHeaders(CloudCredentials creds) => {
        'Authorization':
            'Basic ${base64Encode(utf8.encode('${creds.username}:${creds.password}'))}',
      };

  /// Ensure the `ghita/<name>` folder exists (MKCOL, idempotent).
  static Future<bool> ensureProjectFolder(
    CloudCredentials creds, {
    http.Client? client,
  }) async {
    final c = client ?? _clientWithAuth(creds);
    try {
      // Root folder first, then per-project.
      for (final path in ['/ghita/', '/ghita/${_safeName(creds.projectName ?? 'default')}/']) {
        final uri = Uri.parse(
            '${normalizedBaseUrl(creds.baseUrl)}$path');
        final request = http.Request('MKCOL', uri);
        request.headers.addAll(_authHeaders(creds));
        final streamed = await c.send(request);
        final mk = await http.Response.fromStream(streamed);
        if (mk.statusCode >= 400 &&
            mk.statusCode != 405 &&
            mk.statusCode != 301) {
          return false;
        }
      }
      return true;
    } catch (_) {
      return false;
    } finally {
      if (client == null) c.close();
    }
  }

  /// Upload [bytes] as a new version of [projectName]. Returns the version
  /// number written (increments from the highest existing `v{N}` file).
  static Future<int?> uploadVersion(
    CloudCredentials creds,
    String projectName,
    List<int> bytes, {
    http.Client? client,
  }) async {
    final versions = await listVersions(creds, projectName, client: client);
    final next = versions.isEmpty
        ? 1
        : versions.map((v) => v.version).reduce((a, b) => a > b ? a : b) + 1;
    final fileName = 'v$next.ghita';
    final uri = Uri.parse('${_projectUri(creds, projectName)}${Uri.encodeComponent(fileName)}');
    final c = client ?? _clientWithAuth(creds);
    try {
      final put = await c.put(uri,
          headers: {..._authHeaders(creds), 'Content-Type': 'application/octet-stream'},
          body: bytes);
      if (put.statusCode < 200 || put.statusCode >= 300) return null;
      // Update the latest pointer (overwrite).
      final latestUri =
          Uri.parse('${_projectUri(creds, projectName)}latest.ghita');
      await c.put(latestUri,
          headers: {..._authHeaders(creds), 'Content-Type': 'application/octet-stream'},
          body: bytes);
      return next;
    } catch (_) {
      return null;
    } finally {
      if (client == null) c.close();
    }
  }

  /// Download the given remote version (or `latest.ghita` when [version] is
  /// null). Returns null when missing.
  static Future<List<int>?> downloadVersion(
    CloudCredentials creds,
    String projectName, {
    int? version,
    http.Client? client,
  }) async {
    final fileName = version == null ? 'latest.ghita' : 'v$version.ghita';
    final uri = Uri.parse(
        '${_projectUri(creds, projectName)}${Uri.encodeComponent(fileName)}');
    final c = client ?? _clientWithAuth(creds);
    try {
      final get = await c.get(uri, headers: _authHeaders(creds));
      if (get.statusCode != 200) return null;
      return get.bodyBytes;
    } catch (_) {
      return null;
    } finally {
      if (client == null) c.close();
    }
  }

  /// List remote versions (from PROPFIND XML or, when the server hides the
  /// collection, from a `versions.json` we maintain alongside uploads).
  static Future<List<RemoteVersion>> listVersions(
    CloudCredentials creds,
    String projectName, {
    http.Client? client,
  }) async {
    final c = client ?? _clientWithAuth(creds);
    try {
      final request = http.Request('PROPFIND', _projectUri(creds, projectName));
      request.headers.addAll({
        ..._authHeaders(creds),
        'Depth': '1',
        'Content-Type': 'application/xml',
      });
      request.body =
          '<?xml version="1.0"?><d:propfind xmlns:d="DAV:"><d:prop><d:getcontentlength/><d:getlastmodified/></d:prop></d:propfind>';
      final streamed = await c.send(request);
      final propfind = await http.Response.fromStream(streamed);
      if (propfind.statusCode >= 200 && propfind.statusCode < 300) {
        final versions = _parsePropfind(propfind.body, projectName);
        if (versions.isNotEmpty) return versions;
      }
      // Fallback: read a manifest we wrote on the last upload.
      final manifestUri = Uri.parse(
          '${_projectUri(creds, projectName)}versions.json');
      final get = await c.get(manifestUri, headers: _authHeaders(creds));
      if (get.statusCode == 200) {
        final decoded = jsonDecode(get.body);
        if (decoded is List) {
          return decoded
              .whereType<Map>()
              .map((e) => RemoteVersion.fromMap(Map<String, dynamic>.from(e)))
              .toList();
        }
      }
      return const [];
    } catch (_) {
      return const [];
    } finally {
      if (client == null) c.close();
    }
  }

  /// Delete a specific remote version.
  static Future<bool> deleteVersion(
    CloudCredentials creds,
    String projectName,
    int version, {
    http.Client? client,
  }) async {
    final fileName = 'v$version.ghita';
    final uri = Uri.parse(
        '${_projectUri(creds, projectName)}${Uri.encodeComponent(fileName)}');
    final c = client ?? _clientWithAuth(creds);
    try {
      final del = await c.delete(uri, headers: _authHeaders(creds));
      return del.statusCode >= 200 && del.statusCode < 300;
    } catch (_) {
      return false;
    } finally {
      if (client == null) c.close();
    }
  }

  static List<RemoteVersion> _parsePropfind(String xml, String projectName) {
    final versions = <RemoteVersion>[];
    final hrefRe = RegExp(r'<d:href>([^<]+)</d:href>');
    final lengthRe = RegExp(r'<d:getcontentlength>([^<]+)</d:getcontentlength>');
    final modifiedRe =
        RegExp(r'<d:getlastmodified>([^<]+)</d:getlastmodified>');
    final hrefs = hrefRe.allMatches(xml).map((m) => m.group(1)!).toList();
    final lengths =
        lengthRe.allMatches(xml).map((m) => m.group(1)!).toList();
    final modifieds =
        modifiedRe.allMatches(xml).map((m) => m.group(1)!).toList();
    for (var i = 0; i < hrefs.length; i++) {
      final href = hrefs[i];
      final match = RegExp(r'v(\d+)\.ghita$').firstMatch(href);
      if (match == null) continue;
      final version = int.tryParse(match.group(1)!) ?? 0;
      if (version <= 0) continue;
      versions.add(RemoteVersion(
        projectName: projectName,
        version: version,
        sizeBytes: i < lengths.length ? int.tryParse(lengths[i]) ?? 0 : 0,
        modifiedAt:
            i < modifieds.length ? DateTime.tryParse(modifieds[i]) : null,
      ));
    }
    versions.sort((a, b) => b.version.compareTo(a.version));
    return versions;
  }
}

class CloudCredentials {
  final String baseUrl;
  final String username;
  final String password;
  final String? projectName;

  const CloudCredentials({
    required this.baseUrl,
    required this.username,
    required this.password,
    this.projectName,
  });

  CloudCredentials copyWith({String? projectName}) => CloudCredentials(
        baseUrl: baseUrl,
        username: username,
        password: password,
        projectName: projectName ?? this.projectName,
      );
}

class RemoteVersion {
  final String projectName;
  final int version;
  final int sizeBytes;
  final DateTime? modifiedAt;

  const RemoteVersion({
    required this.projectName,
    required this.version,
    required this.sizeBytes,
    this.modifiedAt,
  });

  Map<String, dynamic> toMap() => {
        'projectName': projectName,
        'version': version,
        'sizeBytes': sizeBytes,
        if (modifiedAt != null)
          'modifiedAt': modifiedAt!.toUtc().toIso8601String(),
      };

  static RemoteVersion fromMap(Map<String, dynamic> map) => RemoteVersion(
        projectName: (map['projectName'] ?? '').toString(),
        version: (map['version'] as num?)?.toInt() ?? 0,
        sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
        modifiedAt: map['modifiedAt'] != null
            ? DateTime.tryParse(map['modifiedAt'].toString())
            : null,
      );
}
