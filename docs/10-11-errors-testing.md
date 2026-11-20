# 10–11 — Errors, Edge Cases, Testing (condensed)
(Reconstructed 2026-09-25.)

## Error states (all explicit with recovery)

DB-open failure → retry screen. Thread load failure → retry. Save failure →
kept in composer. Delete/rename failures → snackbars, nothing lost.
Destructive actions double-confirmed. Reset → onboarding. No silent loss
anywhere; no crash paths leave data half-written (transactions).

## Edge cases (25-case matrix condensed to rules)

Empty input never persists; rapid sends serialize; kill mid-write rolls
back (WAL+txn); kill mid-stream equivalent N/A (no streaming; local writes
are atomic); persona change applies to next reply; deleting an open thread
falls back to default; offline is the only mode; migration failure path
reserved with backup discipline; reinstall starts clean (export/import is
the restore path); huge threads page; extraction attempts N/A (no system
prompt); no false action/memory claims by construction.

## Testing strategy (as executed)

Unit: responder/rules/daily/registry (seeded), format, models, import
validation. Widget (fakes): navigation, onboarding persist, send/persist,
drafts, auto-reply on/off + caption, history CRUD/pin/archive/search,
customize save, settings toggles, activities→chat, copy/delete, import
round-trip, about, unknown-route fallback. DB (ffi, binding-free): schema,
CRUD, paging, drafts, settings, reopen, cascade, companion, pin/archive/
search incl. LIKE escaping, clear ops, 10k perf bounds. Manual: emulator
install/launch/interaction screenshots + logcat.
