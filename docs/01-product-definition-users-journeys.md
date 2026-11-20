# 01 — Product Definition, Target Users, User Journeys
(Reconstructed 2026-09-25; normative behavior verified by code + tests.)

## Product

Local-only Companion / Friend mobile app (Flutter/Dart, Android + iOS).
Core loop: open → companion immediately available → write/talk → entries
persist on-device → optional routines → user controls personality, data.
Not a therapist, social network, or game. No AI, no accounts, no network.

Decision — local-first + Flutter: SQLite for offline data, single codebase.
One companion (multi-companion reserved as extension point).

## Target users

Casual chatter, daily companion, work/study buddy, planner/reflector,
entertainment. Non-therapeutic framing: ordinary friendship-style use, no
forced reflection or motivation, no diagnosis, no guilt messaging.

Privacy-by-design: messages/memories/settings stored in on-device SQLite;
nothing transmitted anywhere; retention until user deletes; per-item and
wipe deletion; disabling a feature stops its data use.

## User journeys

J1 first open → skippable onboarding → default companion → empty-state
starters → first entry saved. J2 returning continuity (drafts, history).
J3 personalize (name/look/style, applies to new entries). J4 memory/privacy
control (view/edit/delete/clear/export). J5 optional daily check-in. J6
offline (browse/compose, never lose input). J7 distress (supportive
prewritten reply, no diagnosis, real-world resources pointer).
