# 17 — Phase 6 AI Integration (OPTIONAL backend, local-first)

Status: implemented + verified. Reverses docs/13 ONLY as an opt-in layer:
default remains local-only; `LocalResponder` is untouched and is the
fallback. No AI code runs unless the user enables it in Settings → AI.

## Architecture

```
ChatScreen --uses--> ChatPipeline --uses--> AiRuntime
                                            |-- local: LocalCompanionProvider
                                            |           (LocalResponder, offline)
                                            |-- remote: AiCompanionProvider
                                                        (RemoteAIProvider today;
                                                         more backends later)
Credentials: AiCredentialStore (platform Keychain/Keystore in prod,
             memory fakes in tests). Settings rows hold only URL/model/mode.
```

- `AiCompanionProvider`: `sendMessage` / `cancelRequest` / `dispose`.
  Streaming reserved (not implemented).
- `RemoteAIProvider`: OpenAI-compatible `POST {base}/chat/completions`
  (+ `GET {base}/models` for Test connection). 30s request timeout.
- Modes: `localOnly` (default, zero network), `auto` (remote w/ labeled
  local fallback), `remoteOnly` (error card + retry, nothing fake persisted).
- Message rows gained nullable `provider` (`local`|`remote`) + `error`
  columns (schema v1→v2 migration, old rows read as local-era).
- Assistant captions: remote → "AI reply • remote service"; otherwise
  "programmed reply • not AI". Pre-Phase-6 rows show the programmed caption.
- Failures classify to `AiFailure` (network/timeout/auth/rateLimit/server/
  malformed/cancelled/misconfigured) with display-safe text. Keys never
  appear in errors, logs (none exist), or persisted rows.

## Configuration (no hard-coded secrets anywhere)

Settings → AI: enable switch, mode (Auto fallback/Remote only), provider
label, service address (https required; http allowed only for localhost),
model, API key field (obscure, write-only — UI shows configured/not only),
Test connection, Clear AI configuration, privacy explanation.
Key storage: `flutter_secure_storage` (`ai_api_key`). `.env` files are not
used; `.gitignore` bans `.env*`, keystores, certificates.

Client-side key warning: a key shipped in/typed into a mobile app can be
extracted from a rooted device or proxy; for production use, prefer a
backend proxy that holds the key. The app makes no claim otherwise.

## Data that leaves the device (remote AI enabled only)

Per reply request, over HTTPS: the typed message text, model name, and
`max_tokens`/`temperature` parameters. Nothing else (no history, no profile,
no drafts). Local-only mode transmits nothing. The app makes NO claim about
provider-side encryption, retention, or deletion — check the provider policy.

## Tests (deterministic, MockClient/scripted fakes, zero real network)

17 provider/pipeline tests (success, timeout, network, auth, rate-limit,
server, malformed ×5, key-leakage, cancellation, fallback, disabled,
retry-no-duplicate, disable-returns-local, endpoint validation, metadata
restart, credential round-trip) + v1→v2 migration test + 3 AI widget tests
(AI caption, error card + retry recovery, settings toggle).
Full suite: 68/68. Local-only zero-network proven by call counters.
