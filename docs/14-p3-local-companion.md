# 14 — P3 Local Companion Milestone (NON-AI) — IMPLEMENTED 2026-09-23

AI stays removed (docs/13). P3 makes the app a useful offline companion
with zero network dependencies (deps: flutter, cupertino_icons, sqflite,
path; dev: flutter_test, flutter_lints, sqflite_common_ffi).

## Shipped

1. Companion profile: name, avatar (6 built-ins), 5 style axes, humor/emoji,
   reply length, interests, avoid-topics, user name. Persisted in
   `companion_profile`; customization screen with Save + reset-with-confirm.
2. Conversation experience: history list (preview, timestamp, count),
   new/rename (dialog)/delete (confirm), per-conversation chat opening,
   message timestamps, drafts, empty/error states.
3. Programmed replies: `LocalResponder` — keyword rules + prewritten pools,
   seeded Random for tests. Toggle in Settings (default ON). Assistant
   bubbles captioned "programmed reply • not AI". Never claims AI.
4. Activities (modular registry): starters, self-checked trivia,
   would-you-rather, journaling, brainstorm, reflection, daily prompt,
   coin/dice instant fun. Copy / Another / Open-in-chat actions.
5. Daily companion: in-app greeting + question on Home (toggles in Settings).
   No OS notifications plugin, no background work, no guilt copy.
6. Settings: theme, companion, daily, programmed-replies, text size
   (80–130%, live + persisted), reduced motion, privacy/data, about.
7. Privacy/data: export JSON to clipboard, delete all conversations
   (confirm), full reset (confirm → onboarding). Local-only statement.
8. Accessibility: 48dp targets, labels/tooltips, text scaling, reduced-motion
   pager, AA-contrast themes, responsive lists.

## Architecture notes

- Repository interfaces + SQL impls; `AppScopeData.real/fake`. Widget tests
  use fakes because ffi sqlite deadlocks under TestWidgetsFlutterBinding
  here; SQL covered by binding-free db tests (incl. reopen/migration,
  cascade, clearAllData).
- Fixed real bug found by tests: rename-dialog controller disposed during
  exit transition (now owned by dialog State).
- No new packages. No network calls. No keys. Manifests declare no INTERNET.

## Verification (2026-09-23)

- `flutter analyze`: clean.
- `flutter test` (db 11 + responder 12 + widget 12): 35/35 PASS.
- Grep: no AI API calls, keys, or AI dependencies, SQLite persistence re-verified.
