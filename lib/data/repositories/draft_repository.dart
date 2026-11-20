import 'package:sqflite/sqflite.dart';

import '../../core/utils/ids.dart';
import '../database/app_db.dart';

/// Per-conversation composer drafts (FR-CHAT-03). Survive restarts;
/// deleted with their conversation (see ConversationRepository.delete).
abstract class DraftRepository {
  Future<String?> get(String conversationId);
  Future<void> set(String conversationId, String body);
  Future<void> clear(String conversationId);
}

class SqlDraftRepository implements DraftRepository {
  final AppDb appDb;
  SqlDraftRepository(this.appDb);

  @override
  Future<String?> get(String conversationId) async {
    final rows = await appDb.db.query(
      'kv_drafts',
      columns: ['body'],
      where: 'conversationId = ?',
      whereArgs: [conversationId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['body'] as String;
  }

  @override
  Future<void> set(String conversationId, String body) async {
    if (body.trim().isEmpty) {
      await clear(conversationId);
      return;
    }
    await appDb.db.insert('kv_drafts', {
      'conversationId': conversationId,
      'body': body,
      'updatedAt': nowMs(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> clear(String conversationId) async {
    await appDb.db.delete(
      'kv_drafts',
      where: 'conversationId = ?',
      whereArgs: [conversationId],
    );
  }
}
