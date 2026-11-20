# 15 — P4 Local Polish — IMPLEMENTED 2026-09-23

Non-AI, offline, network-free. Zero new dependencies, zero schema changes.

## Shipped

1. Pin/archive: `setPinned/setArchived/listArchived` on the repository
   (columns + index already existed in v1 — **no migration required**);
   history screen gains Active/Archived segments and Pin/Unpin +
   Archive/Unarchive menu actions.
2. Per-message copy (clipboard) + delete (confirm dialog, count/preview
   refresh) via bubble long-press sheet.
3. Search: LIKE-based `search()` over titles, previews, message bodies with
   wildcard escaping; blank query returns full list; explicit no-match state.
   Schema stays FTS5-ready; no search dependency.
4. Export/import v1 (`companion-export`, version 1): `buildExport` serializes
   conversations + messages + flags + companion snapshot; `importData`
   validates (format/version/shape/caps), remaps all ids (never overwrites),
   skips + counts bad rows, reports counts. Companion profile exported for
   portability but never overwritten; drafts/settings excluded (transient /
   device-specific) — documented, tested. UI: Export copies JSON, Import
   pastes with pre-write confirm dialog showing validated counts.
5. About screen: name, version (const synced to pubspec by test, no
   package_info dependency), local-only guarantee.
6. Tests: +1 db (pin/archive/search incl. LIKE escaping), +3 export/import
   (round-trip incl. no-overwrite, validation, row-skipping), +1 version
   sync, +6 widget (search, pin/archive flows, copy, delete, import
   round-trip, about).

## Bugs found by tests (all fixed)

- Rename-dialog controller disposed during exit transition (P3 carryover,
  fixed via dialog-owned State).
- Shared in-memory test DB leaked rows between tests once a connection
  outlived its test → `makeTestScope` now opens a unique temp-file DB per
  test with cleanup on close.
- Test-hygiene findings (test-only): dialog-scoped TextField finder,
  scroll-into-view for lazy lists, single-pump route changes don't
  re-resolve initialRoute, snackbars queue behind unexpired ones.

## Verification (2026-09-23)

- `flutter analyze`: clean. `flutter test`: 46/46 PASS
  (db 12, export/import 3, app_info 1, responder 12, widget 18).
- Grep: no AI/API/network code, keys, deps, or manifest permissions.
- On-device restart persistence + store builds: NOT TESTED (Gradle SDK
  environment fault, unchanged since P2).
