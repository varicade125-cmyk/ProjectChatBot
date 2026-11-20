# 12 — Roadmap, Risks, Acceptance, Next

> SUPERSEDED IN PART by docs/13-ai-removal.md (2026-09-23): AI integration
> removed. P3 AI, P4 AI-memory, and all AI-dependent items below are cancelled.
> Remaining valid phases: P0, P1, P2, P5-local (routines/notifs/journal-lite),
> P6-local (export/wipe, no secrets exist), P7 release.

## Phased roadmap (Phase → prereq → work → test → exit → next)

- P0 Spec/arch (this folder) → exit: acceptance checklist below true → P1.
- P1 Core app: setup, theme tokens, router, onboarding, companion profile, static chat UI.
  Test: widget + nav. Exit: cold start ≤2s, routes + theme switch work.
- P2 Persistence: SQLite + repos + convs/msgs/drafts/history + migrations.
  Test: unit+integration offline. Exit: restart restores all; migration test green.
- ~~P3 AI: interface + stub + OpenAI-compat adapter, context builder, streaming, retry.~~
  REMOVED per docs/13 (no remote calls, no providers, no keys).
- ~~P4 Memory: policy + retriever + Manager UI + conflicts.~~
  REMOVED per docs/13 (was AI-memory; local notes remain valid under P5-local).
- P5-local Experience: routines/notifs, journal-lite. Exit: disabled→zero fires.
- P6-local Hardening: export/wipe. Exit: wipe leaves empty DB (no secrets exist).
- P7 Release: analyze/unit/widget + Android/iOS + offline + standalone install.

Checkpoints: no phase starts until prior exit true; DB change requires migration test;
destructive UI requires confirm + test.

## Critical evaluation (cut/delay)

Cut from MVP: social, gamification, voice, multi-companion, analytics, sync — high
cost/privacy/maintenance, zero proof of core loop. All data is local; no server,
no recurring infra cost. Notif abuse risk mitigated by
caps + quiet hours + no-guilt copy. Cost: one-time dev only; zero recurring
cost (AI removal eliminated token/infra spend — docs/13).

## Future extension points (local-only)

History search (FTS5), routines/reminders, journaling, export/import, sync
engine (LWW+tombstones, only if accounts are ever wanted). No AI extension
points. No AI reintroduction without reversing docs/13.

## Risk register (AI risks removed per docs/13)

Architectural: 1) migration corruption (mitigate: backup+safe-mode+tests);
2) large-history jank (mitigate: paging, item-level rebuilds).
Product/UX: 1) local routines feel thin without AI (mitigate: keep scope honest —
journal + reminders, no fake replies); 2) notif annoyance/churn (mitigate: opt-in,
caps, quiet hours).

## Acceptance (ready for implementation when)

Core journeys defined ✓; MVP fixed ✓; data model ✓; local-only scope fixed (docs/13) ✓;
privacy/data controls ✓; screens ✓; edge cases ✓; testing exists ✓;
deps justified ✓; order dependency-correct ✓ (see P0–P2, P5-local–P7).

## Recommended implementation order + Next milestone

Order: P1→P2→P5-local→P6-local→P7 (never higher before lower stable).
Next after P2: conversation history UI + local routines/notifications + journal-lite,
then export/wipe hardening, then release.

**Smallest first milestone (M1 — why first):** project setup + theme tokens + router
skeleton + onboarding (skippable) + Home + empty Chat UI, no DB/AI yet.
Why: unblocks all navigation/UI work, validates toolchain + devices early, zero
dependency on DB/AI contracts. Files: `main.dart`, `theme/*`, `navigation/router.dart`,
`features/onboarding/*`, `features/home/*`, `features/chat/view_static.dart`.
Validate: `flutter analyze`, runs on Android+iOS, back/skip routing correct.
Report: PASS/FAIL/NOT TESTED (no fabrication). Next dependency after M1: SQLite repos (P2).
