# 05–07 — Memory, Safety, Privacy Notes (condensed)
(Reconstructed 2026-09-25.)

## Memory (local notes, not AI memory)

Short-term: current thread + drafts. Long-term: user-editable notes and
preferences (name, interests, routines as plain stored values). Companion
config separate and versioned. No silent inference, no auto-ingest. Rule:
the app never claims recall it doesn't have; everything shown comes from
stored rows. View/edit/delete/clear per item.

## Safety

No human claims; identity is a labeled companion profile, replies captioned
"programmed reply • not AI". No manipulation, guilt, dependency pressure,
or abandonment threats. Distress input gets a supportive prewritten reply
with no diagnosis and a nudge toward trusted humans; no counseling loops.
Abusive input handled neutrally (stored as ordinary entries).

## Privacy/security/offline

SQLite on device is the only store; no network calls exist so nothing is
transmitted; no accounts/keys/telemetry. Export = clipboard JSON;
deletes are immediate (per-item, per-conversation, wipe + reset).
Offline: everything works (reads, writes, settings, drafts); nothing can
queue for a server because there is none. Secrets: none exist.
