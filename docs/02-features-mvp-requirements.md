# 02 — Feature Inventory, MVP Scope, Functional + Non-Functional Requirements
(Reconstructed 2026-09-25; FR-AI-01/02 removed per docs/13.)

## Inventory (as built)

Chat (local log, programmed replies, copy/delete, drafts), conversations
(create/rename/delete/archive/pin/search), companion customization,
skippable onboarding, theme (light/dark/OLED/system), settings, privacy
(export/import/wipe), activities hub, daily card, journal/reflection.
Post-MVP: FTS search, OS notifications, sync. Excluded: social, AI,
gamification, analytics, accounts.

## Functional requirements (abridged)

FR-CHAT-01 write+persist locally <500ms, failed write keeps composer text.
FR-CHAT-03 draft persistence per conversation across restart.
FR-CONV-01 create/rename/delete/archive/pin, sorted by activity.
FR-CONV-03 paging (never full-load large threads).
FR-PERS-01 companion profile edit/reset. FR-ONB-01 skippable, zero required.
FR-MEM-01 notes/preferences view/add/edit/delete/clear (local).
FR-THEME-01 centralized light/dark/OLED + system.
FR-PRIV-01 JSON export, per-item + wipe delete, offline-capable.
FR-DB-01 SQLite + versioning + migrations + pagination + transactions.
FR-OFF-01 offline browse/compose; never lose input.
~~FR-AI-01/02 removed (docs/13).~~

## Non-functional (measurable)

Cold start ≤2s; msg persist ≤500ms; 60fps 500-msg scroll via paging;
no full-list rebuild per message; zero silent loss; WAL+transactions;
no secrets (none exist); WCAG AA contrast; 48dp targets; dynamic type;
reduced motion; `flutter analyze` clean; 10k-msg paging without jank;
OS-scheduled nothing (no background work); full offline reads/writes.
