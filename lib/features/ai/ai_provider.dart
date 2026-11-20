/// AI provider abstraction (Phase 6). The app talks ONLY to this interface;
/// local and remote backends are interchangeable behind it.
/// Local-first guarantees: default mode never touches the network; every
/// failure is classified (never a crash, never a fake reply); no secret
/// ever appears in logs, errors, or persisted rows.
enum AiMode {
  /// Programmed replies only. Zero network requests, always.
  localOnly,

  /// Try remote; on any failure persist a labeled local reply instead.
  auto,

  /// Remote only: on failure persist nothing, surface retry UI.
  remoteOnly,
}

enum AiFailureKind {
  network,
  timeout,
  auth,
  rateLimit,
  server,
  malformed,
  cancelled,
  misconfigured,
}

/// Classified remote failure. [userMessage] is safe to display verbatim:
/// it never contains keys, tokens, URLs with credentials, or raw bodies.
class AiFailure implements Exception {
  final AiFailureKind kind;
  final String userMessage;
  const AiFailure(this.kind, this.userMessage);

  @override
  String toString() => 'AiFailure($kind)';

  static AiFailure network() => const AiFailure(
        AiFailureKind.network,
        'Could not reach the AI service. Check your connection and retry.',
      );
  static AiFailure timeout() => const AiFailure(
        AiFailureKind.timeout,
        'The AI service took too long to answer. Retry when ready.',
      );
  static AiFailure auth() => const AiFailure(
        AiFailureKind.auth,
        'The AI service rejected the credentials. Check the API key in Settings.',
      );
  static AiFailure rateLimit() => const AiFailure(
        AiFailureKind.rateLimit,
        'The AI service is rate-limiting requests. Wait a moment and retry.',
      );
  static AiFailure server() => const AiFailure(
        AiFailureKind.server,
        'The AI service had a problem. Retry in a little while.',
      );
  static AiFailure malformed() => const AiFailure(
        AiFailureKind.malformed,
        'The AI service returned something unexpected. Retry or use a programmed reply.',
      );
  static AiFailure cancelled() => const AiFailure(
        AiFailureKind.cancelled,
        'The AI request was cancelled.',
      );
  static AiFailure misconfigured(String detail) => AiFailure(
        AiFailureKind.misconfigured,
        detail,
      );
}

/// Single-turn request. History/context shaping is intentionally out of
/// scope for v1 (local companion continuity lives in SQLite, not prompts).
class AiChatRequest {
  final String conversationId;
  final String userText;
  final String companionName;
  final String? userName;
  final String verbosity;
  final Duration timeout;

  const AiChatRequest({
    required this.conversationId,
    required this.userText,
    required this.companionName,
    this.userName,
    this.verbosity = 'medium',
    this.timeout = const Duration(seconds: 30),
  });
}

/// One AI backend behind the abstraction. Implementations:
/// [LocalCompanionProvider] (prewritten, offline) and [RemoteAIProvider]
/// (OpenAI-compatible HTTPS API). Streaming reserved for a later version.
abstract class AiCompanionProvider {
  /// Stable id stored nowhere sensitive: 'local' | 'openai-compatible' (+future).
  String get id;

  /// Short human label shown under AI replies, e.g. 'Programmed replies'.
  /// Must never claim model identity the backend cannot prove.
  String get displayName;

  /// Returns the reply text or throws [AiFailure]. Never returns fake text
  /// on failure; never throws raw transport exceptions.
  Future<String> sendMessage(AiChatRequest request);

  /// Best-effort cancellation of an in-flight [sendMessage].
  void cancelRequest();

  /// Releases resources (HTTP clients, timers). Idempotent.
  Future<void> dispose();
}
