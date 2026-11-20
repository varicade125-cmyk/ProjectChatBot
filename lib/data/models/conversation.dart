/// Conversation row. Mirrors `conversations` (docs/08).
class Conversation {
  final String id;
  final String title;
  final bool isArchived;
  final bool isPinned;
  final int createdAt;
  final int updatedAt;
  final String? lastMessagePreview;
  final int messageCount;
  final String? summary;

  const Conversation({
    required this.id,
    required this.title,
    this.isArchived = false,
    this.isPinned = false,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessagePreview,
    this.messageCount = 0,
    this.summary,
  });

  factory Conversation.fromMap(Map<String, Object?> m) => Conversation(
        id: m['id']! as String,
        title: m['title']! as String,
        isArchived: (m['isArchived']! as int) == 1,
        isPinned: (m['isPinned']! as int) == 1,
        createdAt: m['createdAt']! as int,
        updatedAt: m['updatedAt']! as int,
        lastMessagePreview: m['lastMessagePreview'] as String?,
        messageCount: (m['messageCount']! as int),
        summary: m['summary'] as String?,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'isArchived': isArchived ? 1 : 0,
        'isPinned': isPinned ? 1 : 0,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'lastMessagePreview': lastMessagePreview,
        'messageCount': messageCount,
        'summary': summary,
      };
}
