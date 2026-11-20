# Local Companion / Friend App (NON-AI) — Index

Status: implemented through P4; P5 release readiness done; store
publication deferred. Reconstructed 2026-09-25 after source loss
(originals written 2026-09-22/23; milestone records 13–16 reproduced in
full, spec docs 01–12 condensed — normative behavior verified by code
and the 47-test suite).

## Original specification (deliverables)

| # | Deliverable | File |
|---|---|---|
| 01 | Product definition, target users, user journeys | docs/01-*.md |
| 02 | Feature inventory, MVP scope, functional + non-functional reqs (FR-AI-* removed) | docs/02-*.md |
| 03 | Screen/navigation map | docs/03-*.md |
| 04 | AI behavior spec — SUPERSEDED, retained for reference only | docs/04-*.md |
| 05–07 | Memory / safety+moderation / privacy+security+offline | docs/05-*.md … docs/07-*.md |
| 08 | Database schema (v1 DDL) | docs/08-*.md |
| 09 | App + state architecture, dependencies (AI parts superseded; as-built: AppScope + Navigator 1.0 + sqflite) | docs/09-*.md |
| 10–11 | Error states + 25 edge cases / testing strategy | docs/10-*.md, docs/11-*.md |
| 12 | Roadmap, risks, acceptance (P3/P4-AI cancelled; P5-local–P7 valid) | docs/12-*.md |

## Implementation milestones (as built)

| Milestone | Record | State |
|---|---|---|
| M1 foundation/UI | P1/M1 report in chat history | done, verified |
| P2 persistence | chat history | done, verified (host tests) |
| AI removal (cancels P3-AI, P4-AI-memory) | docs/13-ai-removal.md | done |
| P3 local companion (profile, programmed replies, activities, daily, settings) | docs/14-p3-local-companion.md | done, 35/35 tests |
| P4 local polish (pin/archive, copy/delete, search, export/import, about) | docs/15-p4-local-polish.md | done, 46/46 tests |
| P5 release readiness | docs/16-p5-release-readiness.md | done; store deferred |
| P6 optional AI backend (default local-only) | docs/17-phase6-ai-integration.md | done, 68/68 tests |

## Architecture (as built, non-AI)

Flutter/Dart, SQLite via sqflite (v1 schema, no migrations needed yet),
AppScope + repositories (interface/SQL/fake), named routes, local-only:
no network calls, no keys, no accounts. Deps: flutter, cupertino_icons,
sqflite, path (+dev: flutter_test, flutter_lints, sqflite_common_ffi).

## Known limitations

- No cloud sync/accounts (by design). Export/import is JSON-via-clipboard.
- No OS notifications (daily content is in-app). No FTS5 yet (LIKE search).
- App icon is Flutter default; applicationId keeps its `com.example.*`
  form; no keystore exists. All store-publication items are intentionally
  deferred — local install testing is the supported path.
- iOS never tested (no macOS host). Device frame timing not measured.
