import '../../core/scope/app_scope.dart';
import '../../data/models/message.dart';

/// Stable local export format (v1). Everything is plain JSON; no secrets or
/// credentials exist in this app, and none are exported.
/// ```json
/// {"format":"companion-export","version":1,"exportedAt":"...","companion":{...},
///  "conversations":[{"title":...,"messages":[{"role":"user","body":"..."}]}]}
/// ```
abstract final class ExportFormat {
  static const String format = 'companion-export';
  static const int version = 1;

  /// Practical caps so a hostile/oversized file cannot OOM the import.
  static const int maxConversations = 5000;
  static const int maxMessagesPerConversation = 20000;
  static const int maxBodyChars = 20000;
}

class ImportResult {
  final int importedConversations;
  final int importedMessages;
  final int skippedRows;
  final List<String> errors;
  const ImportResult({
    this.importedConversations = 0,
    this.importedMessages = 0,
    this.skippedRows = 0,
    this.errors = const [],
  });
  bool get ok => errors.isEmpty;
}

/// Serializes all user data. Throws only on repository failure (surfaced in
/// UI); output always validates via [validateExport].
Future<Map<String, Object?>> buildExport(AppScopeData scope) async {
  final convs = await scope.conversations.listRecent(limit: 100000);
  final archived = await scope.conversations.listArchived(limit: 100000);
  final all = [...convs, ...archived];
  final convJson = <Map<String, Object?>>[];
  for (final c in all) {
    final msgs = await scope.messages.page(c.id, limit: 100000);
    convJson.add({
      'title': c.title,
      'isArchived': c.isArchived,
      'isPinned': c.isPinned,
      'createdAt': c.createdAt,
      'updatedAt': c.updatedAt,
      'lastMessagePreview': c.lastMessagePreview,
      'messageCount': c.messageCount,
      'summary': c.summary,
      'messages': msgs.reversed
          .map((m) => {
                'role': m.role.name,
                'body': m.body,
                'status': m.status.name,
                'createdAt': m.createdAt,
                'updatedAt': m.updatedAt,
                'requestId': m.requestId,
              })
          .toList(),
    });
  }
  final profile = await scope.companion.getOrCreate();
  return {
    'format': ExportFormat.format,
    'version': ExportFormat.version,
    'exportedAt': DateTime.now().toIso8601String(),
    'aiService': 'none — local-only export',
    'companion': profile.toMap(),
    'conversations': convJson,
  };
}

/// Validates then imports. NEVER overwrites: every imported conversation and
/// message gets a fresh local id; existing data is untouched. Invalid rows
/// are skipped and counted. Returns counts for the confirm dialog/snackbar.
Future<ImportResult> importData(
  AppScopeData scope,
  Map<String, Object?> payload,
) async {
  final errors = <String>[];
  if (payload['format'] != ExportFormat.format) {
    return const ImportResult(
        errors: ['Not a companion export (bad format marker).']);
  }
  if (payload['version'] != ExportFormat.version) {
    return ImportResult(errors: [
      'Unsupported export version ${payload['version']} '
          '(this app reads v${ExportFormat.version}).'
    ]);
  }
  final rawConvs = payload['conversations'];
  if (rawConvs is! List) {
    return const ImportResult(errors: ['Export has no conversation list.']);
  }
  if (rawConvs.length > ExportFormat.maxConversations) {
    return ImportResult(errors: [
      'Too many conversations (${rawConvs.length} > '
          '${ExportFormat.maxConversations}).'
    ]);
  }

  var importedConvs = 0;
  var importedMsgs = 0;
  var skipped = 0;
  for (final raw in rawConvs) {
    if (raw is! Map) {
      skipped++;
      continue;
    }
    final m = raw.map((k, v) => MapEntry('$k', v));
    final title = m['title'];
    if (title is! String || title.trim().isEmpty) {
      skipped++;
      continue;
    }
    final conv = await scope.conversations.create(
      title: title.trim().substring(
          0, title.trim().length > 120 ? 120 : title.trim().length),
    );
    if (m['isPinned'] == true) {
      await scope.conversations.setPinned(conv.id, true);
    }
    if (m['isArchived'] == true) {
      await scope.conversations.setArchived(conv.id, true);
    }
    final rawMsgs = m['messages'];
    if (rawMsgs is List) {
      var n = 0;
      for (final rm in rawMsgs) {
        if (n >= ExportFormat.maxMessagesPerConversation) {
          skipped += rawMsgs.length - n;
          break;
        }
        if (rm is! Map) {
          skipped++;
          continue;
        }
        final mm = rm.map((k, v) => MapEntry('$k', v));
        final role = _roleOf(mm['role']);
        final body = mm['body'];
        if (role == null || body is! String || body.isEmpty) {
          skipped++;
          continue;
        }
        await scope.messages.insert(
          conversationId: conv.id,
          role: role,
          body: body.length > ExportFormat.maxBodyChars
              ? body.substring(0, ExportFormat.maxBodyChars)
              : body,
          status: _statusOf(mm['status']),
        );
        n++;
        importedMsgs++;
      }
      final count = await scope.messages.count(conv.id);
      final last =
          await scope.messages.page(conv.id, limit: 1);
      await scope.conversations.touch(
        id: conv.id,
        preview: last.isEmpty
            ? ''
            : (last.first.body.length > 120
                ? '${last.first.body.substring(0, 120)}…'
                : last.first.body),
        messageCount: count,
      );
    }
    importedConvs++;
  }
  // Touch uses fresh timestamps: imported threads sort as recent, which is
  // honest (they arrived now) and keeps ordering deterministic.
  return ImportResult(
    importedConversations: importedConvs,
    importedMessages: importedMsgs,
    skippedRows: skipped,
    errors: errors,
  );
}

MessageRole? _roleOf(Object? raw) {
  if (raw is! String) return null;
  for (final r in MessageRole.values) {
    if (r.name == raw) return r;
  }
  return null;
}

MessageStatus _statusOf(Object? raw) {
  if (raw is! String) return MessageStatus.sent;
  switch (raw) {
    case 'failedRetryable':
    case 'failed_retryable':
      return MessageStatus.failedRetryable;
    case 'failedFinal':
    case 'failed_final':
      return MessageStatus.failedFinal;
    case 'queuedOffline':
    case 'queued_offline':
      return MessageStatus.queuedOffline;
    case 'sending':
      return MessageStatus.sending;
    case 'streaming':
      return MessageStatus.streaming;
    case 'interrupted':
      return MessageStatus.interrupted;
    default:
      return MessageStatus.sent;
  }
}
