import '../../core/utils/ids.dart';
import '../database/app_db.dart';
import '../models/message.dart';

/// Message persistence contract (paged reads; FR-DB-01).
abstract class MessageRepository {
  Future<Message> insert({
    required String conversationId,
    required MessageRole role,
    required String body,
    MessageStatus status = MessageStatus.sent,
    String? requestId,
    MessageProvider? provider,
    String? error,
  });
  Future<List<Message>> page(String conversationId,
      {int limit = 50, int offset = 0});
  Future<int> count(String conversationId);
  Future<void> updateStatus(String id, MessageStatus status);
  Future<void> delete(String id);
}

class SqlMessageRepository implements MessageRepository {
  final AppDb appDb;
  SqlMessageRepository(this.appDb);

  @override
  Future<Message> insert({
    required String conversationId,
    required MessageRole role,
    required String body,
    MessageStatus status = MessageStatus.sent,
    String? requestId,
    MessageProvider? provider,
    String? error,
  }) async {
    final t = nowMs();
    final m = Message(
      id: newId('msg'),
      conversationId: conversationId,
      role: role,
      body: body,
      status: status,
      createdAt: t,
      updatedAt: t,
      requestId: requestId,
      provider: provider,
      error: error,
    );
    await appDb.db.insert('messages', m.toMap());
    return m;
  }

  @override
  Future<List<Message>> page(
    String conversationId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final rows = await appDb.db.query(
      'messages',
      where: 'conversationId = ?',
      whereArgs: [conversationId],
      orderBy: 'createdAt DESC, rowid DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(Message.fromMap).toList();
  }

  @override
  Future<int> count(String conversationId) async {
    final rows = await appDb.db.rawQuery(
      'SELECT COUNT(*) AS n FROM messages WHERE conversationId = ?',
      [conversationId],
    );
    return (rows.first['n']! as int);
  }

  @override
  Future<void> updateStatus(String id, MessageStatus status) async {
    await appDb.db.update(
      'messages',
      {'status': _statusName(status), 'updatedAt': nowMs()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> delete(String id) async {
    await appDb.db.delete('messages', where: 'id = ?', whereArgs: [id]);
  }

  static String _statusName(MessageStatus s) {
    switch (s) {
      case MessageStatus.failedRetryable:
        return 'failed_retryable';
      case MessageStatus.failedFinal:
        return 'failed_final';
      case MessageStatus.queuedOffline:
        return 'queued_offline';
      default:
        return s.name;
    }
  }
}
