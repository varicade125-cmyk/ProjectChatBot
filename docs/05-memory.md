# 05 — Memory Specification

## Separation (A–F)

- A Short-term: last 20 msgs + active summary. Ephemeral, per-conversation.
- B Long-term: stable facts (name, interests, goals, routines, explicit saves).
- C Preferences: tone, length, topics, quiet hours. Lives in CompanionProfile/UserPreference.
- D Companion config: persona axes snapshot. Versioned, never auto-mutated from chat.
- E Recurring facts: e.g. "runs Tue/Thu". With optional `recurrence` hint.
- F Temporary: draft, pending routine context. TTL or session-scoped, never promoted silently.

**The companion memory rule:** never claim recall unless in A/B/C/E or current context.
Otherwise say "I don't have that saved" and offer to save.

## Write policy

Qualifies: preferred name; stable prefs; repeated goals/routines; explicit
"remember X"; user-corrected facts.
Does NOT qualify: one-off remarks; sensitive identifiers (passwords, full address,
financial, health diagnoses, other people's private data); transient emotion;
verbatim conversation dumps.

- Explicit save → write immediately (unless unsafe → refuse + explain).
- Implicit candidate → propose in-chat ("Want me to remember X?") or pending tray;
  default: do not write without confirm (configurable auto-write OFF for MVP).
- Conflicts: explicit > recent > older; keep one row, supersede old (`superseded_by`).
- Obsolete: update in place, keep `updatedAt`; never duplicate.
- Sensitive: refuse to store, warn, offer redacted alternative.

Schema hint: `memories(id, kind, key, value, source, confidence, sensitivity, createdAt, updatedAt, supersededBy)`.

## Retrieval (relevance, not dump-all)

Criteria: keyword overlap + kind boost (explicit save > pref > fact) + recency decay.
Limits: ≤5 per request, ≤150 chars each (truncate). Restrictions: `sensitivity=high`
excluded from auto-retrieval (explicit user invocation only). Stale (>180d untouched,
non-explicit) demoted + surfaced in Manager as "review". Vector/embeddings reserved:
`memory_embeddings(memoryId, model, vector)` table may be added later; retriever behind
`MemoryRetriever` interface so FTS→vector swap needs no chat rewrite.

Privacy-by-design: view/edit/delete/clear per memory; disable memory → B/E reads stop,
writes stop; export includes memories; wipe deletes all.
