import '../../data/models/companion_profile.dart';
import '../companion/local_responder.dart';
import 'ai_provider.dart';

/// Local backend: wraps [LocalResponder]. No network, no credentials,
/// no failure modes beyond profile storage (surfaced by the caller).
/// This provider is never removed: it is the default and the fallback.
class LocalCompanionProvider implements AiCompanionProvider {
  final Future<CompanionProfile> Function() _profileReader;

  // Note: explicit initializer (not `this._profileReader`, which would make
  // the public parameter private-named and unusable by callers).
  LocalCompanionProvider({
    required Future<CompanionProfile> Function() profileReader,
  }) : _profileReader = profileReader; // ignore: prefer_initializing_formals

  @override
  String get id => 'local';

  @override
  String get displayName => 'Programmed replies';

  /// Builds a reply from the live companion profile. Pure + synchronous
  /// under the hood; async only for the profile read.
  Future<String> reply(String userText) async {
    final profile = await _profileReader();
    return LocalResponder(
      companionName: profile.name,
      userName: profile.userName,
      verbosity: profile.respLength,
    ).respond(userText);
  }

  @override
  Future<String> sendMessage(AiChatRequest request) async {
    final profile = await _profileReader();
    return LocalResponder(
      companionName: request.companionName.isNotEmpty
          ? request.companionName
          : profile.name,
      userName: request.userName ?? profile.userName,
      verbosity: request.verbosity,
    ).respond(request.userText);
  }

  @override
  void cancelRequest() {
    // Nothing in flight is cancellable: replies resolve immediately.
  }

  @override
  Future<void> dispose() async {
    // No resources held.
  }
}
