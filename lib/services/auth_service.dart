import 'dart:math';

import '../models/user_profile.dart';

/// Session role semantics (Track 49, FEAT 84).
///
/// * **host** — created the session; full rights including moderation.
/// * **editor** — can edit slides and comments.
/// * **viewer** — read-only; the server rejects their sync payloads and the
///   UI shows a "view mode" notice instead of letting them edit.
///
/// The collaboration server enforces the role on every write; this service
/// only mirrors the rules so the UI can react instantly (disable toolbars,
/// show the view-mode banner) without waiting for a 403 round-trip.
class AuthService {
  AuthService._();

  static const String hostRole = 'host';
  static const String editorRole = 'editor';
  static const String viewerRole = 'viewer';

  static const Set<String> roles = {hostRole, editorRole, viewerRole};

  static bool isViewer(String? role) => role == viewerRole;

  static bool canEdit(String? role) =>
      role == hostRole || role == editorRole;

  /// Whether the current profile may own a session (always true — hosting
  /// works offline and locally; cloud auth is optional).
  static bool canHost(UserProfile profile) => true;

  /// Default display color derived from a profile (used for cursors/avatars).
  static String profileColor(UserProfile profile) {
    final hex = profile.color.replaceAll('#', '');
    return RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(hex)
        ? '#${hex.toUpperCase()}'
        : '#FF9800';
  }

  /// A short-lived join token for the given role (used by the broadcast link
  /// generator — the collaboration service accepts these directly).
  static String mintToken(String role, {int byteLength = 8}) {
    final random = Random.secure();
    final bytes = List<int>.generate(
        byteLength, (_) => random.nextInt(256));
    return '${role.substring(0, 1)}_${bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join()}';
  }

  /// Parses the role out of a minted token (or null for unrecognised tokens).
  static String? roleOfToken(String token) {
    if (token.startsWith('e_')) return editorRole;
    if (token.startsWith('v_')) return viewerRole;
    return null;
  }

  /// Human description of the role, used in the permission README/UI.
  static String describe(String role) => switch (role) {
        hostRole => 'Full control: edit slides, moderate the session',
        editorRole => 'Edit slides and comments',
        viewerRole => 'Read-only: view the deck, no edits',
        _ => 'Unknown role',
      };
}
