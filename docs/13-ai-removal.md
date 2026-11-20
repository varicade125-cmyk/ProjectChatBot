# 13 — AI Removal Decision Record (supersedes AI scope)

Date: 2026-09-23. Status: ACCEPTED AND IMPLEMENTED.

## Decision

AI integration is removed from this project entirely. No P3 AI integration,
no remote provider/API, no API keys, no remote requests, no AI service or
provider interfaces in code.

## What this changes

- The app is a **local-only companion**: onboarding, themes, conversations,
  messages, drafts, SQLite persistence. Chat is a local conversation log —
  entries are saved on this device; nothing generates replies.
- Removed from scope: FR-AI-01, FR-AI-02 (docs/02), P3 AI integration (docs/12),
  AI behavior spec (docs/04, superseded), AI service abstraction (docs/09,
  superseded), AI long-term memory (P4), AI-dependent features (streaming,
  regeneration, summarization, prompt-based memory proposal).
- No code deletion was needed for providers: none were ever created.
  No AI dependencies existed in pubspec: none removed. Verified clean.

## What remains true

- All M1/P2 UI, navigation, and persistence behavior unchanged.
- v1 SQLite schema unchanged (role/status enums are inert stored values).
- Privacy posture improves: zero data leaves the device, no credentials exist.
- Future local-only features (routines/reminders, journaling, history search,
  export) remain valid extension points. No AI reintroduction without a new
  explicit decision reversing this record.

## Verification required with this change

`flutter analyze` clean, `flutter test` green, grep confirms no AI API calls,
keys, or AI dependencies, SQLite persistence re-verified.
