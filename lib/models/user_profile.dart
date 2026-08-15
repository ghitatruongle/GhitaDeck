import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local user profile (Track 49, FEAT 84).
///
/// The app works fully offline — the profile is a local identity (name +
/// avatar color/emoji) used as the comment author, collaboration display name
/// and export metadata author. No network account is required for LAN
/// collaboration; cloud login (P2) is optional and behind [isCloudEnabled].
class UserProfile {
  final String name;
  final String avatarEmoji;
  final String color;
  final String? cloudAccountName;

  const UserProfile({
    this.name = 'User',
    this.avatarEmoji = '👤',
    this.color = '#FF9800',
    this.cloudAccountName,
  });

  UserProfile copyWith({
    String? name,
    String? avatarEmoji,
    String? color,
    String? cloudAccountName,
    bool clearCloudAccount = false,
  }) {
    return UserProfile(
      name: name ?? this.name,
      avatarEmoji: avatarEmoji ?? this.avatarEmoji,
      color: color ?? this.color,
      cloudAccountName: clearCloudAccount
          ? null
          : cloudAccountName ?? this.cloudAccountName,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'avatarEmoji': avatarEmoji,
        'color': color,
        if (cloudAccountName != null) 'cloudAccountName': cloudAccountName,
      };

  static UserProfile fromMap(Map<String, dynamic> map) => UserProfile(
        name: (map['name'] ?? 'User').toString(),
        avatarEmoji: (map['avatarEmoji'] ?? '👤').toString(),
        color: (map['color'] ?? '#FF9800').toString(),
        cloudAccountName: map['cloudAccountName']?.toString(),
      );

  String toJson() => jsonEncode(toMap());

  static UserProfile fromJson(String json) {
    try {
      return fromMap(jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      return const UserProfile();
    }
  }

  /// Loads the stored profile (defaults when none exists yet).
  static Future<UserProfile> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('user_profile');
    return raw == null ? const UserProfile() : fromJson(raw);
  }

  /// Persists this profile locally.
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_profile', toJson());
  }
}
