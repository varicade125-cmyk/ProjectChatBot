import '../../core/utils/ids.dart';
import '../database/app_db.dart';
import '../models/conversation.dart';

/// Conversation persistence contract. SQL implementation below;
/// in-memory fake lives in test/fakes.dart (widget tests must not touch
/// ffi sqlite — it deadlocks under TestWidgetsFlutterBinding in this env).
abstract class ConversationRepository {
  Future<Conversation> create({required String title});
  Future<Conversation?> byId(String id);
  Future<List<Conversation>> listRecent({int limit = 50, int offset = 0});
  Future<Conversation> ensureDefault();
  Future<void> touch({
    required String id,
    required String preview,
    required int messageCount,
  });
  Future<void> rename(String id, String title);
  Future<void> delete(String id);

  /// Deletes every conversation (CASCADE messages) + all drafts.
  Future<void> clearAll();

  Future<void> setPinned(String id, bool pinned);
  Future<void> setArchived(String id, bool archived);

  /// Archived threads, most-recently-active first.
  Future<List<Conversation>> listArchived({int limit = 50, int offset = 0});

  /// Substring search over titles, previews, and message bodies
  /// (LIKE-based; schema stays FTS5-ready for a future upgrade).
  /// Blank query returns the full active/archived list.
  Future<List<Conversation>> search(String query,
      {bool archived = false, int limit = 100});
}

class SqlConversationRepository implements ConversationRepository {
  final AppDb appDb;
  SqlConversationRepository(this.appDb);

  @override
  Future<Conversation> create({required String title}) async {
    final t = nowMs();
    final c =
        Conversation(id: newId('conv'), title: title, createdAt: t, updatedAt: t);
    await appDb.db.insert('conversations', c.toMap());
    return c;
  }

  @override
  Future<Conversation?> byId(String id) async {
    final rows = await appDb.db.query(
      'conversations',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Conversation.fromMap(rows.first);
  }

  @override
  Future<List<Conversation>> listRecent(
      {int limit = 50, int offset = 0}) async {
    final rows = await appDb.db.query(
      'conversations',
      where: 'isArchived = 0',
      orderBy: 'isPinned DESC, updatedAt DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(Conversation.fromMap).toList();
  }

  @override
  Future<Conversation> ensureDefault() async {
    final existing = await listRecent(limit: 1);
    if (existing.isNotEmpty) return existing.first;
    return create(title: 'General');
  }

  @override
  Future<void> touch({
    required String id,
    required String preview,
    required int messageCount,
  }) async {
    await appDb.db.update(
      'conversations',
      {
        'lastMessagePreview': preview,
        'messageCount': messageCount,
        'updatedAt': nowMs(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> rename(String id, String title) async {
    await appDb.db.update(
      'conversations',
      {'title': title, 'updatedAt': nowMs()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> delete(String id) async {
    await appDb.db.transaction((txn) async {
      await txn.delete('conversations', where: 'id = ?', whereArgs: [id]);
      await txn.delete('kv_drafts',
          where: 'conversationId = ?', whereArgs: [id]);
    });
  }

  @override
  Future<void> clearAll() async {
    await appDb.db.transaction((txn) async {
      await txn.delete('messages');
      await txn.delete('conversations');
      await txn.delete('kv_drafts');
    });
  }

  @override
  Future<void> setPinned(String id, bool pinned) async {
    await appDb.db.update(
      'conversations',
      {'isPinned': pinned ? 1 : 0, 'updatedAt': nowMs()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> setArchived(String id, bool archived) async {
    await appDb.db.update(
      'conversations',
      {'isArchived': archived ? 1 : 0, 'updatedAt': nowMs()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<List<Conversation>> listArchived(
      {int limit = 50, int offset = 0}) async {
    final rows = await appDb.db.query(
      'conversations',
      where: 'isArchived = 1',
      orderBy: 'updatedAt DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(Conversation.fromMap).toList();
  }

  static String _likeEscape(String s) => s
      .replaceAll('\\', '\\\\')
      .replaceAll('%', '\\%')
      .replaceAll('_', '\\_');

  @override
  Future<List<Conversation>> search(String query,
      {bool archived = false, int limit = 100}) async {
    if (query.trim().isEmpty) {
      return archived
          ? listArchived(limit: limit)
          : listRecent(limit: limit);
    }
    final like = '%${_likeEscape(query.trim())}%';
    final rows = await appDb.db.rawQuery(
      '''SELECT DISTINCT c.* FROM conversations c
         LEFT JOIN messages m ON m.conversationId = c.id
         WHERE c.isArchived = ?
           AND (c.title LIKE ? ESCAPE '\\'
             OR c.lastMessagePreview LIKE ? ESCAPE '\\'
             OR m.body LIKE ? ESCAPE '\\')
         ORDER BY c.isPinned DESC, c.updatedAt DESC LIMIT ?''',
      [archived ? 1 : 0, like, like, like, limit],
    );
    return rows.map(Conversation.fromMap).toList();
  }
}
