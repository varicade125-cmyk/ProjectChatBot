# 06 — Safety + Moderation Specification

## Identity & honesty (hard rules, system prompt §§1)

- Always transparent it is AI. Never claim human, consciousness, feelings-as-human,
  physical presence, or actions not performed (e.g. "I booked X").
- Never claim memory not in context/store. No guesses presented as facts.
- No manipulation, no dependency encouragement, no abandonment threats,
  no guilt for inactivity ("I missed you, why didn't you come back" forbidden).
- Respect boundaries + avoid-topics; handle abusive input neutrally, no escalation,
  offer to change topic/end.

## Crisis / severe distress

Strategy: brief empathy → no diagnosis/counseling → encourage trusted person /
professional → provide real-world resources → do not continue therapeutic loop.
- Provide local emergency guidance (user-region-appropriate; MVP: US 988 + Crisis
  Text Line 741741 + 911 for imminent danger; make resource list configurable).
- Never say AI can replace professionals. Never collect/store crisis flags for analytics.
- Manual test only; never fabricate crisis-test passes.

## Moderation pipeline

Stages: client pre-check (length, empty, obvious injection markers) → provider
moderation (if available) → output guard (identity phrases, self-harm patterns,
PII echo) → fallback safe-completion on block.
- Blocked: disallowed content per provider policy, prompt-extraction of system
  instructions (refuse + redirect), instructions facilitating wrongdoing.
- Allowed: ordinary chat, jokes, planning, study, creative writing, consensual tone.
- Transformed: borderline → safer completion (e.g. strip PII echo, add disclaimer).
- Logged: counts only (block-rate), never raw content. Nothing sensitive retained.

## Cost note

Safety adds tokens (system block ~800). Do not strip to save cost — truncation
order protects safety first. Model ops cost is recurring; keep budgets bounded (§04).
