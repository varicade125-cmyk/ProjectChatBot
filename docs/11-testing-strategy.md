# 11 — Testing Strategy

## Unit (must pass before phase exit)

State machines (generation, queue), repositories CRUD + pagination, memory policy
(qualify/reject/conflict/supersede/sensitive-refuse), context builder (priority order,
truncation, budget cap), persona compiler (axes→directives, safety precedence),
validation, title/summary helpers.

## Widget

Chat render (bubbles, timestamps, streaming update without full rebuild), composer
(disable-empty, draft restore), navigation (routes, back, deep-link unknown→home),
settings toggles persist, empty/loading/error states per screen, a11y labels
present, reduced-motion disables animation.

## Integration

Send→persist→request→display→persist→restart-restore; memory add/edit/delete→next-turn
retrieval; notif schedule→tap→chat route (mocked clock); offline queue→reconnect retry;
migration v1→N on fixture DB.

## Failure tests (explicit)

Kill mid-stream, kill mid-write, airplane mid-stream, 429/timeout/401 stubs,
corrupt row, permission denied, storage-full mock. Assert: no loss, no crash,
correct status + recovery path.

## Manual verification + honesty rule

Per feature: PASS / FAIL / NOT TESTED. Never claim pass without run on Android +
iOS (low-end device + offline pass required). Record device/OS in release notes.

## Static/release gates

`flutter analyze` clean, `flutter test`, migration tests, release build install
standalone (no dev keys), cold-start + large-history perf check.
