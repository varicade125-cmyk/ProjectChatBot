# 12 — Roadmap, Risks, Acceptance (condensed, post-AI-removal)
(Reconstructed 2026-09-25.)

Order built: P1 shell → P2 persistence → P5-local experience (profile,
programmed replies, activities, daily, journal-lite) → P6-local hardening
(export/wipe) → P7 release (analyze/tests, emulator verification).
P3-AI/P4-AI-memory cancelled (docs/13).

Risks (as faced): unbounded context N/A (no AI); provider risk N/A;
migration corruption (mitigated: backup discipline + reopen tests);
recall-trust (mitigated: everything shown is a stored row, editable);
notification annoyance (mitigated: in-app only, toggles, no guilt copy);
test-env flakiness (ffi/widget-binding deadlock → fakes; OneDrive build
locks → build outside synced folder).

Acceptance (met): journeys defined; MVP fixed; data model + v1 schema;
memory/safety/privacy controls; screens; edge rules; 47-test suite green;
deps minimal and justified; order dependency-correct.

Future (local-only): FTS5 search, OS reminders, export file picker,
pin/archive already done. No AI reintroduction without reversing docs/13.
