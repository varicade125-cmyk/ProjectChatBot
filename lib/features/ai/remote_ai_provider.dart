import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'ai_provider.dart';

/// Remote backend over an OpenAI-compatible Chat Completions API
/// (`POST {baseUrl}/chat/completions`, `GET {baseUrl}/models` for tests).
///
/// Security rules (enforced, tested):
/// - The API key arrives per call via [readApiKey] (platform secure storage
///   in production, memory in tests). It is NEVER logged, never embedded in
///   error text, never persisted, never hard-coded.
/// - HTTPS required, except http loopback (localhost/127.0.0.1/[::1]) so
///   users may point at a local OpenAI-compatible server.
/// - Every failure maps to [AiFailure]; raw transport exceptions never leak.
/// - Cancellation closes only the in-flight call's client.
class RemoteAIProvider implements AiCompanionProvider {
  final http.Client Function() clientFactory;
  final Future<String?> Function() readApiKey;
  final Uri _endpoint;
  final Uri _modelsEndpoint;
  final String model;

  http.Client? _activeClient;
  bool _cancelled = false;
  bool _disposed = false;

  RemoteAIProvider({
    required this.clientFactory,
    required this.readApiKey,
    required String baseUrl,
    required this.model,
  })  : _endpoint = _resolve(baseUrl, 'chat/completions'),
        _modelsEndpoint = _resolve(baseUrl, 'models');

  /// Production constructor with a real HTTP client. Used by main.dart
  /// and by Settings → Test connection (same code path as real calls).
  factory RemoteAIProvider.withDefaultClient({
    required Future<String?> Function() readApiKey,
    required String baseUrl,
    required String model,
  }) =>
      RemoteAIProvider(
        clientFactory: http.Client.new,
        readApiKey: readApiKey,
        baseUrl: baseUrl,
        model: model,
      );

  /// Validates + normalizes the configured base URL. Throws [AiFailure]
  /// (misconfigured) for anything that is not https or http-loopback.
  /// Pure and unit-tested; also used by Settings before saving.
  static Uri resolveEndpoint(String raw, String path) =>
      _resolve(raw, path);

  static Uri _resolve(String raw, String path) {
    final trimmed = raw.trim().replaceAll(RegExp(r'/+$'), '');
    final base = Uri.tryParse(trimmed);
    final host = base?.host ?? '';
    final okScheme = base != null &&
        (base.scheme == 'https' ||
            (base.scheme == 'http' && _isLoopback(host)));
    if (!okScheme || host.isEmpty) {
      throw AiFailure.misconfigured(
        'The AI service address must be an https URL '
        '(http is allowed only for localhost).',
      );
    }
    return Uri.parse('$trimmed/$path');
  }

  static bool _isLoopback(String host) {
    final h = host.toLowerCase();
    return h == 'localhost' || h == '127.0.0.1' || h == '[::1]' || h == '::1';
  }

  @override
  String get id => 'openai-compatible';

  @override
  String get displayName => 'Remote AI';

  @override
  Future<String> sendMessage(AiChatRequest request) async {
    if (_disposed) {
      throw AiFailure.misconfigured('The AI provider was disposed.');
    }
    _cancelled = false;
    final key = await readApiKey();
    if (key == null || key.isEmpty) {
      throw AiFailure.misconfigured(
        'No API key is configured. Add one in Settings → AI.',
      );
    }
    final client = clientFactory();
    _activeClient = client;
    try {
      final body = jsonEncode({
        'model': model,
        'messages': [
          {'role': 'user', 'content': request.userText},
        ],
        'max_tokens': 500,
        'temperature': 0.7,
      });
      final response = await client
          .post(
            _endpoint,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $key',
            },
            body: body,
          )
          .timeout(request.timeout);
      if (_cancelled) throw AiFailure.cancelled();
      return _parseReply(response);
    } on TimeoutException {
      throw AiFailure.timeout();
    } on http.ClientException {
      // Client closed by cancelRequest() surfaces here too.
      throw _cancelled ? AiFailure.cancelled() : AiFailure.network();
    } on SocketException {
      throw _cancelled ? AiFailure.cancelled() : AiFailure.network();
    } on AiFailure {
      rethrow;
    } catch (_) {
      // Anything else (codec edge, mock misuse): never leak internals.
      throw _cancelled ? AiFailure.cancelled() : AiFailure.malformed();
    } finally {
      _activeClient = null;
      client.close();
    }
  }

  String _parseReply(http.Response response) {
    switch (response.statusCode) {
      case 200:
        break;
      case 401:
      case 403:
        throw AiFailure.auth();
      case 429:
        throw AiFailure.rateLimit();
      default:
        if (response.statusCode >= 500) throw AiFailure.server();
        throw AiFailure.server();
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) throw const FormatException('root');
      final choices = decoded['choices'];
      if (choices is! List || choices.isEmpty) {
        throw const FormatException('choices');
      }
      final first = choices.first;
      if (first is! Map) throw const FormatException('choice');
      final message = first['message'];
      if (message is! Map) throw const FormatException('message');
      final content = message['content'];
      if (content is! String || content.trim().isEmpty) {
        throw const FormatException('content');
      }
      return content.trim();
    } on AiFailure {
      rethrow;
    } catch (_) {
      throw AiFailure.malformed();
    }
  }

  /// Connectivity + credential check for Settings → Test connection.
  /// Returns normally only on HTTP 200; anything else throws the matching
  /// classified [AiFailure] (401 surfaces as auth — still proves reachability
  /// to the user via the message wording).
  Future<void> testConnection({Duration timeout = const Duration(seconds: 10)}) async {
    final key = await readApiKey();
    if (key == null || key.isEmpty) {
      throw AiFailure.misconfigured(
        'No API key is configured. Add one in Settings → AI.',
      );
    }
    final client = clientFactory();
    try {
      final response = await client
          .get(
            _modelsEndpoint,
            headers: {'Authorization': 'Bearer $key'},
          )
          .timeout(timeout);
      if (response.statusCode == 200) return;
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw AiFailure.auth();
      }
      if (response.statusCode == 429) throw AiFailure.rateLimit();
      throw AiFailure.server();
    } on TimeoutException {
      throw AiFailure.timeout();
    } on http.ClientException {
      throw AiFailure.network();
    } on SocketException {
      throw AiFailure.network();
    } on AiFailure {
      rethrow;
    } catch (_) {
      throw AiFailure.malformed();
    } finally {
      client.close();
    }
  }

  @override
  void cancelRequest() {
    _cancelled = true;
    // Closing aborts the in-flight call; the catch block maps it to
    // AiFailure.cancelled via the flag.
    try {
      _activeClient?.close();
    } catch (_) {
      // Close is best-effort; the flag alone still cancels logically.
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    cancelRequest();
  }
}
