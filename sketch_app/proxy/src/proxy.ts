/**
 * Transparent relay for the Claude Messages API.
 *
 * The app sends exactly the request it would send to api.anthropic.com,
 * minus the API key. The worker:
 *   1. checks the shared app token (x-sketch-token),
 *   2. applies a burst limit and a daily quota per device (x-sketch-device),
 *   3. validates the body (allowed model, max_tokens cap, streaming flag),
 *   4. forwards the request with the real key and streams the answer back
 *      unchanged, so SSE, structured outputs and fallbacks all work as-is.
 */

export interface Env {
  ANTHROPIC_API_KEY: string;
  APP_TOKEN: string;
  FREE_DAILY_LIMIT?: string;
  ALLOWED_MODELS?: string;
  MAX_TOKENS_CAP?: string;
  USAGE?: KVNamespace;
  BURST?: { limit(options: { key: string }): Promise<{ success: boolean }> };
}

export interface ProxyOptions {
  /** Injected for tests; defaults to the global fetch. */
  fetch?: typeof fetch;
  /** Injected for tests; defaults to Date.now(). */
  now?: () => number;
  /** Returns true when the device has an active Pro entitlement. */
  isPro?: (deviceId: string, env: Env) => Promise<boolean>;
}

const ANTHROPIC_URL = "https://api.anthropic.com/v1/messages";

const CORS_HEADERS: Record<string, string> = {
  "access-control-allow-origin": "*",
  "access-control-allow-methods": "POST, OPTIONS",
  "access-control-allow-headers": "content-type, anthropic-version, anthropic-beta, x-sketch-token, x-sketch-device",
};

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json", ...CORS_HEADERS },
  });
}

function apiError(status: number, type: string, message: string): Response {
  // Same shape as Anthropic's errors, so the app's parser shows the message.
  return json(status, { type: "error", error: { type, message } });
}

/** Constant-time string comparison. */
function safeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

function dayKey(deviceId: string, now: number): string {
  return `usage:${deviceId}:${new Date(now).toISOString().slice(0, 10)}`;
}

/** No entitlement store yet: everyone is on the free tier. Replace with
 * App Store / Play receipt validation keyed by device (see README). */
export async function defaultIsPro(_deviceId: string, _env: Env): Promise<boolean> {
  return false;
}

export async function handleRequest(request: Request, env: Env, options: ProxyOptions = {}): Promise<Response> {
  const doFetch = options.fetch ?? fetch;
  const now = options.now ?? Date.now;
  const isPro = options.isPro ?? defaultIsPro;

  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }
  const url = new URL(request.url);
  if (url.pathname === "/health") return json(200, { ok: true });
  if (request.method !== "POST" || url.pathname !== "/v1/messages") {
    return apiError(404, "not_found_error", "Not found");
  }
  if (!env.ANTHROPIC_API_KEY || !env.APP_TOKEN) {
    return apiError(500, "api_error", "Proxy is not configured");
  }

  // 1. App token
  const token = request.headers.get("x-sketch-token") ?? "";
  if (!safeEqual(token, env.APP_TOKEN)) {
    return apiError(401, "authentication_error", "Invalid app token");
  }
  const deviceId = (request.headers.get("x-sketch-device") ?? "").trim();
  if (!/^[A-Za-z0-9_-]{8,64}$/.test(deviceId)) {
    return apiError(400, "invalid_request_error", "Missing device id");
  }

  // 2. Burst limit and daily quota
  if (env.BURST) {
    const { success } = await env.BURST.limit({ key: deviceId });
    if (!success) return apiError(429, "rate_limit_error", "Too many requests. Slow down a little.");
  }
  const pro = await isPro(deviceId, env);
  const limit = Number(env.FREE_DAILY_LIMIT ?? "5");
  let usageKey: string | null = null;
  let used = 0;
  if (!pro && env.USAGE && limit > 0) {
    usageKey = dayKey(deviceId, now());
    used = Number((await env.USAGE.get(usageKey)) ?? "0");
    if (used >= limit) {
      return apiError(429, "rate_limit_error", `Daily free limit of ${limit} AI requests reached. Upgrade to Pro for unlimited.`);
    }
  }

  // 3. Validate the body
  let body: Record<string, unknown>;
  try {
    body = (await request.json()) as Record<string, unknown>;
  } catch {
    return apiError(400, "invalid_request_error", "Body must be JSON");
  }
  const allowed = (env.ALLOWED_MODELS ?? "claude-opus-5").split(",").map((m) => m.trim());
  if (typeof body.model !== "string" || !allowed.includes(body.model)) {
    return apiError(400, "invalid_request_error", "Model not allowed");
  }
  const cap = Number(env.MAX_TOKENS_CAP ?? "8192");
  if (typeof body.max_tokens !== "number" || body.max_tokens < 1) {
    return apiError(400, "invalid_request_error", "max_tokens is required");
  }
  if (body.max_tokens > cap) body.max_tokens = cap;
  if (body.stream !== undefined && typeof body.stream !== "boolean") {
    return apiError(400, "invalid_request_error", "stream must be a boolean");
  }

  // 4. Forward with the real key; pass the API version and beta headers through.
  const headers = new Headers({
    "content-type": "application/json",
    "x-api-key": env.ANTHROPIC_API_KEY,
    "anthropic-version": request.headers.get("anthropic-version") ?? "2023-06-01",
  });
  const beta = request.headers.get("anthropic-beta");
  if (beta) headers.set("anthropic-beta", beta);

  const upstream = await doFetch(ANTHROPIC_URL, {
    method: "POST",
    headers,
    body: JSON.stringify(body),
  });

  // Count successful requests only, so a failed call never burns quota.
  if (upstream.ok && usageKey && env.USAGE) {
    await env.USAGE.put(usageKey, String(used + 1), { expirationTtl: 60 * 60 * 36 });
  }

  const responseHeaders = new Headers(CORS_HEADERS);
  const contentType = upstream.headers.get("content-type");
  if (contentType) responseHeaders.set("content-type", contentType);
  responseHeaders.set("cache-control", "no-store");
  responseHeaders.set("x-sketch-quota", pro ? "pro" : `${Math.min(used + 1, limit)}/${limit}`);
  return new Response(upstream.body, { status: upstream.status, headers: responseHeaders });
}
