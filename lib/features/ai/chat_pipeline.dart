import '../../core/scope/app_scope.dart';
import '../../data/models/message.dart';
import 'ai_provider.dart';
import 'ai_runtime.dart';

/// Outcome of one send/retry, for UI state (typing off, error card, caption).
enum ChatSendOutcome {
  /// Assistant reply persisted from the local provider.
  sentLocal,

  /// Assistant reply persisted from the remote provider.
  sentRemote,

  /// Remote failed in `remoteOnly` mode: user message kept, NO assistant
  /// row persisted. UI must show retry UI, never a fake reply.
  remoteFailed,
}

class ChatSendResult {
  final ChatSendOutcome outcome;

  /// Set on [ChatSendOutcome.remoteFailed]. Safe to display verbatim.
  final AiFailure? failure;

  /// The user text that failed (for retry without duplicating the row).
  final String userText;

  /// True when `auto` mode fell back to a labeled local reply.
  final bool fallbackUsed;

  const ChatSendResult({
    required this.outcome,
    required this.userText,
    this.failure,
    this.fallbackUsed = false,
  });
}

AiMode parseAiMode(String raw) {
  switch (raw) {
    case 'auto':
      return AiMode.auto;
    case 'remoteOnly':
      return AiMode.remoteOnly;
    default:
      return AiMode.localOnly;
  }
}

/// Owns one chat screen's send lifecycle: persistence, provider selection,
/// remote calls, fallback, and cancellation. Construct per screen, call
/// [cancel] from dispose.
class ChatPipeline {
  final AppScopeData scope;
  final AiRuntime ai;
  AiCompanionProvider? _activeRemote;

  ChatPipeline({required this.scope, required this.ai});

  /// Full send: persists the user message, resolves the reply per AI mode,
  /// persists the assistant reply (unless remoteOnly failure), touches the
  /// conversation. Draft clearing stays with the UI (it owns the composer).
  Future<ChatSendResult> send(String conversationId, String text) async {
    await scope.messages.insert(
      conversationId: conversationId,
      role: MessageRole.user,
      body: text,
    );
    return _resolve(conversationId, text, allowFallback: true);
  }

  /// Retry after a [ChatSendOutcome.remoteFailed]: attempts the remote call
  /// again WITHOUT persisting another user row.
  Future<ChatSendResult> retry(String conversationId, String userText) =>
      _resolve(conversationId, userText, allowFallback: false);

  /// Explicit labeled-local reply (the "use programmed reply instead"
  /// button). Always persists a local assistant row.
  Future<ChatSendResult> sendLocalFallback(
      String conversationId, String userText) async {
    await _persistAssistant(
      conversationId,
      await ai.local.reply(userText),
      MessageProvider.local,
      touchPreview: true,
    );
    return ChatSendResult(
        outcome: ChatSendOutcome.sentLocal, userText: userText);
  }

  Future<ChatSendResult> _resolve(
    String conversationId,
    String userText, {
    required bool allowFallback,
  }) async {
    final enabled = await scope.settings.aiEnabled();
    final mode = parseAiMode(await scope.settings.aiModeName());
    if (!enabled || mode == AiMode.localOnly) {
      if (!await scope.settings.autoReply()) {
        // Programmed replies off: user message stands alone. Touch metadata
        // so history/count stay correct; no assistant row is written.
        final count = await scope.messages.count(conversationId);
        await scope.conversations.touch(
          id: conversationId,
          preview: userText.length <= 120
              ? userText
              : '${userText.substring(0, 120)}…',
          messageCount: count,
        );
        return ChatSendResult(
            outcome: ChatSendOutcome.sentLocal, userText: userText);
      }
      await _persistAssistant(
        conversationId,
        await ai.local.reply(userText),
        MessageProvider.local,
        touchPreview: true,
      );
      return ChatSendResult(
          outcome: ChatSendOutcome.sentLocal, userText: userText);
    }

    final remote = await ai.resolveRemote(
      enabled: true,
      baseUrl: await scope.settings.aiBaseUrl(),
      model: await scope.settings.aiModel(),
    );
    if (remote == null) {
      // Misconfigured endpoint: same handling as a remote failure.
      return _remoteFailed(
        conversationId,
        userText,
        AiFailure.misconfigured(
          'The AI service address looks wrong. Check it in Settings → AI.',
        ),
        allowFallback: allowFallback && mode == AiMode.auto,
      );
    }

    final profile = await scope.companion.getOrCreate();
    _activeRemote = remote;
    try {
      final reply = await remote.sendMessage(AiChatRequest(
        conversationId: conversationId,
        userText: userText,
        companionName: profile.name,
        userName: profile.userName,
        verbosity: profile.respLength,
      ));
      await _persistAssistant(
        conversationId,
        reply,
        MessageProvider.remote,
        touchPreview: true,
      );
      return ChatSendResult(
          outcome: ChatSendOutcome.sentRemote, userText: userText);
    } on AiFailure catch (e) {
      return _remoteFailed(
        conversationId,
        userText,
        e,
        allowFallback: allowFallback && mode == AiMode.auto,
      );
    } finally {
      _activeRemote = null;
    }
  }

  Future<ChatSendResult> _remoteFailed(
    String conversationId,
    String userText,
    AiFailure failure, {
    required bool allowFallback,
  }) async {
    if (allowFallback) {
      // Labeled fallback: the persisted row says local, the caption says
      // programmed — never presented as an AI reply.
      await _persistAssistant(
        conversationId,
        await ai.local.reply(userText),
        MessageProvider.local,
        touchPreview: true,
      );
      return ChatSendResult(
        outcome: ChatSendOutcome.sentLocal,
        userText: userText,
        failure: failure,
        fallbackUsed: true,
      );
    }
    return ChatSendResult(
      outcome: ChatSendOutcome.remoteFailed,
      userText: userText,
      failure: failure,
    );
  }

  Future<void> _persistAssistant(
    String conversationId,
    String body,
    MessageProvider provider, {
    required bool touchPreview,
  }) async {
    await scope.messages.insert(
      conversationId: conversationId,
      role: MessageRole.assistant,
      body: body,
      provider: provider,
    );
    if (touchPreview) {
      final count = await scope.messages.count(conversationId);
      await scope.conversations.touch(
        id: conversationId,
        preview: body.length <= 120 ? body : '${body.substring(0, 120)}…',
        messageCount: count,
      );
    }
  }

  /// Cancels the in-flight remote call, if any. Safe to call anytime.
  void cancel() {
    _activeRemote?.cancelRequest();
    _activeRemote = null;
  }
}
