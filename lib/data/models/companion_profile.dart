import 'dart:convert';

/// Companion profile row. Mirrors `companion_profile` (docs/08).
/// Local-only: all fields are user-controlled display/behavior preferences;
/// nothing here is sent anywhere (docs/13).
class CompanionProfile {
  final String id;
  final String name;
  final String? avatarRef;
  final Map<String, int> axes;
  final int humor;
  final int emoji;
  final String respLength;
  final List<String> interests;
  final List<String> avoidTopics;
  final String? userName;
  final Map<String, String> commPrefs;
  final int version;
  final int createdAt;
  final int updatedAt;

  static const String defaultId = 'default';

  /// Axis keys with neutral defaults. Values 0..100.
  static const Map<String, int> defaultAxes = {
    'formal': 30,
    'talkative': 55,
    'playful': 50,
    'gentle': 70,
    'energetic': 45,
  };

  const CompanionProfile({
    this.id = defaultId,
    this.name = 'Companion',
    this.avatarRef,
    this.axes = defaultAxes,
    this.humor = 50,
    this.emoji = 50,
    this.respLength = 'medium',
    this.interests = const [],
    this.avoidTopics = const [],
    this.userName,
    this.commPrefs = const {},
    this.version = 1,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CompanionProfile.fromMap(Map<String, Object?> m) =>
      CompanionProfile(
        id: m['id']! as String,
        name: m['name']! as String,
        avatarRef: m['avatarRef'] as String?,
        axes: _intMap(m['axesJson']! as String, defaultAxes),
        humor: (m['humor'] as int?) ?? 50,
        emoji: (m['emoji'] as int?) ?? 50,
        respLength: (m['respLength'] as String?) ?? 'medium',
        interests: _strList(m['interests'] as String?),
        avoidTopics: _strList(m['avoidTopics'] as String?),
        userName: m['userName'] as String?,
        commPrefs: _strMap(m['commPrefs'] as String?),
        version: (m['version']! as int),
        createdAt: m['createdAt']! as int,
        updatedAt: m['updatedAt']! as int,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'avatarRef': avatarRef,
        'axesJson': jsonEncode(axes),
        'humor': humor,
        'emoji': emoji,
        'respLength': respLength,
        'interests': jsonEncode(interests),
        'avoidTopics': jsonEncode(avoidTopics),
        'userName': userName,
        'commPrefs': jsonEncode(commPrefs),
        'version': version,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  CompanionProfile copyWith({
    String? name,
    String? Function()? avatarRef,
    Map<String, int>? axes,
    int? humor,
    int? emoji,
    String? respLength,
    List<String>? interests,
    List<String>? avoidTopics,
    String? Function()? userName,
    Map<String, String>? commPrefs,
    int? version,
    int? updatedAt,
  }) =>
      CompanionProfile(
        id: id,
        name: name ?? this.name,
        avatarRef: avatarRef != null ? avatarRef() : this.avatarRef,
        axes: axes ?? this.axes,
        humor: humor ?? this.humor,
        emoji: emoji ?? this.emoji,
        respLength: respLength ?? this.respLength,
        interests: interests ?? this.interests,
        avoidTopics: avoidTopics ?? this.avoidTopics,
        userName: userName != null ? userName() : this.userName,
        commPrefs: commPrefs ?? this.commPrefs,
        version: version ?? this.version,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  static Map<String, int> _intMap(String raw, Map<String, int> fallback) {
    try {
      final d = jsonDecode(raw) as Map<String, dynamic>;
      return {...fallback, ...d.map((k, v) => MapEntry(k, (v as num).toInt()))};
    } catch (_) {
      return Map.of(fallback);
    }
  }

  static List<String> _strList(String? raw) {
    if (raw == null) return const [];
    try {
      return (jsonDecode(raw) as List).map((e) => '$e').toList();
    } catch (_) {
      return const [];
    }
  }

  static Map<String, String> _strMap(String? raw) {
    if (raw == null) return const {};
    try {
      return (jsonDecode(raw) as Map)
          .map((k, v) => MapEntry('$k', '$v'));
    } catch (_) {
      return const {};
    }
  }
}
