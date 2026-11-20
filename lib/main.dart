import 'package:flutter/material.dart';

import 'core/scope/app_scope.dart';
import 'data/database/app_db.dart';
import 'data/repositories/companion_repository.dart';
import 'data/repositories/conversation_repository.dart';
import 'data/repositories/draft_repository.dart';
import 'data/repositories/message_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'features/ai/ai_credentials.dart';
import 'features/ai/ai_runtime.dart';
import 'features/ai/local_companion_provider.dart';
import 'features/ai/remote_ai_provider.dart';
import 'navigation/app_router.dart';
import 'theme/app_themes.dart';

/// Entry: async bootstrap restores persisted state (theme, text scale,
/// onboarding) before first frame routing.
/// Local-only companion: no network calls, no AI.
/// Spec ref: docs/12 P2; docs/13 AI removal; FR-DB-01, FR-THEME-01, FR-ONB-01.
void main() {
  runApp(const CompanionApp());
}

/// Live theme selection. Initialized from SQLite during bootstrap;
/// pickers write through to [SettingsRepository].
final ValueNotifier<AppThemeMode> themeSelection =
    ValueNotifier<AppThemeMode>(AppThemeMode.system);

/// Live text scaler (1.0 = 100%). Initialized from SQLite during bootstrap;
/// Settings writes through to [SettingsRepository].
final ValueNotifier<double> textScaleSelection =
    ValueNotifier<double>(1.0);

class CompanionApp extends StatelessWidget {
  /// Test hook: host widget tests inject an in-memory scope and skip
  /// device-filesystem bootstrap. Production always passes null.
  final AppScopeData? scopeOverride;
  final String? initialRouteOverride;
  const CompanionApp({super.key, this.scopeOverride, this.initialRouteOverride});

  @override
  Widget build(BuildContext context) {
    if (scopeOverride != null) {
      return _App(
        scope: scopeOverride!,
        initialRoute: initialRouteOverride ?? AppRoutes.home,
      );
    }
    return const _Bootstrap();
  }
}

class _BootResult {
  final AppScopeData scope;
  final String initialRoute;
  _BootResult(this.scope, this.initialRoute);
}

Future<_BootResult> _boot() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await AppDb.open();
  // AI composition root: local responder reads the live profile; remote
  // backends are built per request from settings + secure-storage key.
  // Nothing here performs network I/O at startup.
  final credentials = const SecureAiCredentialStore();
  late final SqlCompanionRepository companionRepo;
  final scope = AppScopeData(
    conversations: SqlConversationRepository(db),
    messages: SqlMessageRepository(db),
    drafts: SqlDraftRepository(db),
    settings: SqlSettingsRepository(db),
    companion: companionRepo = SqlCompanionRepository(db),
    resetAll: db.clearAllData,
    close: db.close,
    db: db,
    credentials: credentials,
    ai: AiRuntime(
      local: LocalCompanionProvider(
        profileReader: () => companionRepo.getOrCreate(),
      ),
      credentials: credentials,
      remoteFactory: (config) => RemoteAIProvider.withDefaultClient(
        readApiKey: credentials.readKey,
        baseUrl: config.baseUrl,
        model: config.model,
      ),
    ),
  );
  themeSelection.value = await scope.settings.themeMode();
  textScaleSelection.value = await scope.settings.textScale();
  final done = await scope.settings.isOnboardingDone();
  return _BootResult(
    scope,
    done ? AppRoutes.home : AppRoutes.onboarding,
  );
}

class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  Future<_BootResult>? _bootFuture;

  @override
  void initState() {
    super.initState();
    _bootFuture = _boot();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_BootResult>(
      future: _bootFuture,
      builder: (context, snap) {
        if (snap.hasData) {
          return _App(scope: snap.data!.scope, initialRoute: snap.data!.initialRoute);
        }
        // Loading + error states are explicit (spec: every failure recoverable).
        return MaterialApp(
          home: Scaffold(
            body: Center(
              child: snap.hasError
                  ? _BootError(
                      message: '${snap.error}',
                      onRetry: () =>
                          setState(() => _bootFuture = _boot()),
                    )
                  : const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading companion…'),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _BootError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _BootError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: 12),
          const Text('Could not open local data.'),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _App extends StatelessWidget {
  final AppScopeData scope;
  final String initialRoute;
  const _App({required this.scope, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return AppScope(
      data: scope,
      child: ListenableBuilder(
        listenable:
            Listenable.merge([themeSelection, textScaleSelection]),
        builder: (context, _) {
          final mode = themeSelection.value;
          final isOled = mode == AppThemeMode.oled;
          return MaterialApp(
            title: 'BEN',
            theme: AppThemes.light(),
            darkTheme: isOled ? AppThemes.oled() : AppThemes.dark(),
            themeMode: AppThemes.toMaterialMode(mode),
            initialRoute: initialRoute,
            onGenerateRoute: AppRoutes.onGenerateRoute,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler:
                    TextScaler.linear(textScaleSelection.value),
              ),
              child: child ?? const SizedBox.shrink(),
            ),
          );
        },
      ),
    );
  }
}
