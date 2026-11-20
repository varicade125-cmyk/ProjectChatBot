/// Message row. Mirrors `messages` (docs/08 + Phase 6 metadata).
enum MessageRole { user, assistant, system }

enum MessageStatus {
  sending,
  sent,
  failedRetryable,
  failedFinal,
  queuedOffline,
  streaming,
  interrupted,
}

/// Which backend produced an assistant message. Null on user rows and on
/// rows written before Phase 6 (treated as local — that era was local-only).
enum MessageProvider { local, remote }

class Message {
  final String id;
  final String conversationId;
  final MessageRole role;
  final String body;
  final MessageStatus status;
  final int createdAt;
  final int updatedAt;
  final String? requestId;
  final MessageProvider? provider;
  final String? error;

  const Message({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.body,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.requestId,
    this.provider,
    this.error,
  });

  static MessageRole _roleOf(String s) => MessageRole.values.byName(s);

  static MessageStatus _statusOf(String s) {
    switch (s) {
      case 'failed_retryable':
        return MessageStatus.failedRetryable;
      case 'failed_final':
        return MessageStatus.failedFinal;
      case 'queued_offline':
        return MessageStatus.queuedOffline;
      default:
        return MessageStatus.values.byName(s);
    }
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

  static MessageProvider? _providerOf(Object? raw) {
    if (raw == null) return null;
    if (raw == 'remote') return MessageProvider.remote;
    return MessageProvider.local;
  }

  factory Message.fromMap(Map<String, Object?> m) => Message(
        id: m['id']! as String,
        conversationId: m['conversationId']! as String,
        role: _roleOf(m['role']! as String),
        body: m['body']! as String,
        status: _statusOf(m['status']! as String),
        createdAt: m['createdAt']! as int,
        updatedAt: m['updatedAt']! as int,
        requestId: m['requestId'] as String?,
        provider: _providerOf(m['provider']),
        error: m['error'] as String?,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'conversationId': conversationId,
        'role': role.name,
        'body': body,
        'status': _statusName(status),
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'requestId': requestId,
        'provider': provider?.name,
        'error': error,
      };
}
