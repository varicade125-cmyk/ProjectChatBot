# 07 — Privacy & Security Specification

## Privacy (what/where/who/retention/delete)

| Data | Stored locally | Sent externally | Retention / delete |
|---|---|---|---|
| Messages | SQLite `messages` | Current bounded context only, TLS, transient | Until conv delete / wipe |
| Memories | SQLite `memories` | Only ≤5 retrieved per request | Per-item delete / clear |
| Persona/prefs/settings | SQLite + secure prefs | Included as directives (no bulk history) | Resettable |
| API key (if user-supplied) | Keychain/Keystore only, never SQLite/logs | As auth header to chosen provider | Deletable in settings |
| Schedules | SQLite + OS scheduler | None | Delete with routine |
| Analytics/crash | Counts only, opt-in, no content | No raw text, no PII | Opt-out stops all |

- No telemetry on content. Crash reports scrubbed. Export = JSON (convs+memories+prefs), offline-capable.
- Third parties: AI provider (inference only) + OS (notifications). No ads/trackers in MVP.
- Decision — local-only MVP, no accounts: Problem: accounts force backend, cost,
  breach surface before core proven. Alternative: cloud-first (rejected).
  Trade-off: no multi-device until sync engine (reserved with tombstones).

## Security

- No privileged server keys in client. User key → `flutter_secure_storage`.
- TLS only; no plaintext export over network (share-sheet only).
- Rate-limit sends client-side (e.g. 1 req/2s, backoff on 429); cap stream time.
- DB tamper: WAL + txns + integrity_check on open; malformed → backup + safe-mode.
- Prompt injection: system block immutable; user persona fields length-capped +
  escaped; extraction attempts refused (case_24).
- Compromised provider: adapter can be disabled remotely via config flag; chat
  degrades to offline mode with clear banner.
- Abuse: per-device caps; no server → no global ban needed MVP.

## Offline behavior

Works offline: browse history/memories, edit settings/persona, compose drafts.
Send offline → `queued_offline` → auto/manual retry on reconnect. Never silent loss.
