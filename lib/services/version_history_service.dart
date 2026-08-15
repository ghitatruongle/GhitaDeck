import 'dart:io';

import 'cloud_sync_service.dart';

/// Version history policy (Track 50, FEAT 83).
///
/// Keeps at most [maxVersions] remote snapshots per project. When an upload
/// would exceed the cap the oldest versions are deleted after the new one is
/// written. Conflicts (two machines uploading within the same second) are
/// handled by the caller keeping the newer timestamped bundle and stashing
/// the loser as `.conflict`.
class VersionHistoryService {
  VersionHistoryService._();

  static const int maxVersions = 20;

  /// Trim remote versions down to [maxVersions], oldest first. Returns the
  /// versions deleted. [keep] protects a specific version (e.g. the one just
  /// uploaded) from being trimmed in the same pass.
  static Future<List<int>> trimVersions(
    CloudCredentials creds,
    String projectName, {
    required List<RemoteVersion> versions,
    int? keep,
  }) async {
    final sorted = List<RemoteVersion>.from(versions)
      ..sort((a, b) => b.version.compareTo(a.version));
    final deleted = <int>[];
    // Version N+1 (if any) is the newest; keep it and up to maxVersions-1.
    for (var i = maxVersions; i < sorted.length; i++) {
      final v = sorted[i];
      if (v.version == keep) continue;
      if (await CloudSyncService.deleteVersion(creds, projectName, v.version)) {
        deleted.add(v.version);
      }
    }
    return deleted;
  }

  /// Merge rule for a download: when the local file is newer than the remote
  /// snapshot the caller should keep local and archive the remote as
  /// `.conflict`. Returns true when local is newer.
  static bool localIsNewer(File localFile, DateTime remoteModifiedAt) {
    try {
      return localFile.existsSync() &&
          localFile.lastModifiedSync().isAfter(remoteModifiedAt);
    } catch (_) {
      return false;
    }
  }
}
