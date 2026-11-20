# 09 — Application + State Architecture, Dependencies (as built)
(Reconstructed 2026-09-25.)

```
lib/ main.dart (bootstrap, theme/text-scale load, first-run routing)
  theme/ app_tokens.dart, app_themes.dart (light/dark/OLED/system)
  navigation/ app_router.dart (8 named routes, Map/String chat args)
  core/ utils(ids, format), scope(AppScope/AppScopeData), constants(app_info)
  data/ database(app_db), models(conversation, message, companion_profile),
        repositories(interface + Sql* impls ×5)
  features/ onboarding, home, chat, conversations, companion(responder,
        avatars, customization), activities, daily, settings(+about),
        data(export_import)
test/ test_scope (isolated temp-file SQL), fakes (in-memory repos),
  widget/db/responder/export_import/app_info/perf tests (47 total)
```

State: `AppScope` InheritedWidget exposes repository interfaces; screens
hold ephemeral UI state only; DB is source of truth. No Riverpod/Bloc
(need never arose). Deps: flutter, cupertino_icons, sqflite 2.4.4,
path 1.9.1 (+dev flutter_test, flutter_lints, sqflite_common_ffi 2.4.3).
Widget tests use fakes (ffi deadlocks under widget binding here); SQL
covered by binding-free tests.
