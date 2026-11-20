import 'ai_credentials.dart';
import 'ai_provider.dart';
import 'local_companion_provider.dart';
import 'remote_ai_provider.dart';

/// What the app needs to reach a remote backend. Read from app_settings at
/// call time (base URL + model); the key always comes from [credentials].
class RemoteAiConfig {
  final String baseUrl;
  final String model;
  const RemoteAiConfig({
    required this.baseUrl,
    required this.model,
  });
}

/// Runtime bundle: always-local responder plus the pieces to build a remote
/// backend on demand. Production wires secure storage + real HTTP; tests
/// wire memory credentials + scripted fakes. Nothing here performs I/O.
class AiRuntime {
  final LocalCompanionProvider local;
  final AiCredentialStore credentials;
  final AiCompanionProvider Function(RemoteAiConfig config) remoteFactory;

  AiRuntime({
    required this.local,
    required this.credentials,
    required this.remoteFactory,
  });

  /// Builds a remote backend from live settings, or returns null when AI
  /// is disabled or misconfigured (bad URL) — never throws for config reads.
  Future<AiCompanionProvider?> resolveRemote({
    required bool enabled,
    required String baseUrl,
    required String model,
  }) async {
    if (!enabled) return null;
    try {
      RemoteAIProvider.resolveEndpoint(baseUrl, 'chat/completions');
    } on AiFailure {
      return null;
    }
    return remoteFactory(
      RemoteAiConfig(baseUrl: baseUrl, model: model),
    );
  }
}
