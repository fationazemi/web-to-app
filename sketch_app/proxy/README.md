# Sketch AI proxy

A Cloudflare Worker that holds the Claude API key so the app never ships it.
The app sends exactly the request it would send to `api.anthropic.com`
(minus the key) and the worker relays it, streaming included.

What it adds on top of a plain relay:

| Check | How |
|---|---|
| App authentication | `x-sketch-token` must equal the `APP_TOKEN` secret (constant-time compare) |
| Burst protection | 10 requests / minute / device via the Workers rate-limit binding |
| Daily free quota | `FREE_DAILY_LIMIT` requests / UTC day / device, counted in KV; only successful upstream calls count |
| Pro users | `isPro(deviceId)` skips the quota; wire it to receipt validation (see below) |
| Request validation | model allow-list, `max_tokens` cap, JSON body |
| Pass-through | `anthropic-version` and `anthropic-beta` headers, SSE bodies, error JSON in Anthropic's own shape |

## Deploy

```bash
cd sketch_app/proxy
npm install
npx wrangler login
npx wrangler kv namespace create USAGE      # paste the id into wrangler.toml
npx wrangler secret put ANTHROPIC_API_KEY   # your Claude key
npx wrangler secret put APP_TOKEN           # e.g. `openssl rand -hex 32`
npm run deploy
```

Then build the app against it:

```bash
cd sketch_app
flutter build apk --release \
  --dart-define=SKETCH_AI_PROXY_URL=https://sketch-ai-proxy.<you>.workers.dev \
  --dart-define=SKETCH_AI_APP_TOKEN=<the APP_TOKEN>
```

The GitHub Actions workflow reads the same two values from repository
secrets `SKETCH_AI_PROXY_URL` and `SKETCH_AI_APP_TOKEN`.

## Local development

```bash
echo 'ANTHROPIC_API_KEY=sk-ant-...' >  .dev.vars
echo 'APP_TOKEN=dev-token'          >> .dev.vars
npm run dev                          # http://localhost:8787
```

In the app, set Settings › Sketch AI › Proxy endpoint to
`http://10.0.2.2:8787` (Android emulator) or `http://localhost:8787` (iOS
simulator) and leave the key empty.

## Tests

```bash
npm test          # vitest, no network: fetch is injected
npm run typecheck
```

## Pro entitlements

`defaultIsPro` returns `false`, so every device is on the free tier. To lift
the quota for paying users, replace it with a check against your receipt
validation:

1. When the app completes a purchase, POST the store receipt and the device
   id to a new `/v1/entitlements` route (add it next to `/v1/messages`).
2. Verify the receipt with the App Store Server API / Google Play Developer
   API and store `pro:<deviceId> = expiry` in KV.
3. `isPro` reads that key.

Until then the app's own quota (`AppSettings.freeAiRequestsPerDay`) and the
proxy's quota are both enforced; keep the two limits equal.

## Threat model

The app token is a shared secret embedded in the binary, so treat it as a
speed bump, not a wall: it stops casual abuse and drive-by scanners, and the
per-device rate limits bound the damage if it leaks. Rotate it by setting a
new secret and shipping a new build. For stronger guarantees add App Attest /
Play Integrity verification in front of the token check.
