import { describe, expect, it } from "vitest";
import { handleRequest, type Env } from "../src/proxy";

class MemoryKV {
  store = new Map<string, string>();
  async get(key: string) {
    return this.store.get(key) ?? null;
  }
  async put(key: string, value: string) {
    this.store.set(key, value);
  }
}

function env(overrides: Partial<Env> = {}): Env {
  return {
    ANTHROPIC_API_KEY: "sk-real",
    APP_TOKEN: "app-token",
    FREE_DAILY_LIMIT: "2",
    ALLOWED_MODELS: "claude-opus-5",
    MAX_TOKENS_CAP: "1000",
    USAGE: new MemoryKV() as unknown as KVNamespace,
    ...overrides,
  };
}

function request(body: unknown, headers: Record<string, string> = {}): Request {
  return new Request("https://proxy.example/v1/messages", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "anthropic-version": "2023-06-01",
      "anthropic-beta": "server-side-fallback-2026-07-01",
      "x-sketch-token": "app-token",
      "x-sketch-device": "device-12345678",
      ...headers,
    },
    body: JSON.stringify(body),
  });
}

const okBody = { model: "claude-opus-5", max_tokens: 500, messages: [{ role: "user", content: "hi" }] };

describe("proxy", () => {
  it("forwards a valid request with the real key and beta header", async () => {
    let seen: { url: string; init: RequestInit } | null = null;
    const fetchMock: typeof fetch = async (url, init) => {
      seen = { url: String(url), init: init! };
      return new Response('{"ok":true}', { status: 200, headers: { "content-type": "application/json" } });
    };
    const res = await handleRequest(request(okBody), env(), { fetch: fetchMock });
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ ok: true });
    const headers = new Headers(seen!.init.headers);
    expect(seen!.url).toBe("https://api.anthropic.com/v1/messages");
    expect(headers.get("x-api-key")).toBe("sk-real");
    expect(headers.get("anthropic-beta")).toBe("server-side-fallback-2026-07-01");
    expect(headers.get("x-sketch-token")).toBeNull();
    expect(res.headers.get("x-sketch-quota")).toBe("1/2");
  });

  it("rejects a wrong app token and a missing device id", async () => {
    const fetchMock: typeof fetch = async () => new Response("{}", { status: 200 });
    const bad = await handleRequest(request(okBody, { "x-sketch-token": "nope" }), env(), { fetch: fetchMock });
    expect(bad.status).toBe(401);
    const noDevice = await handleRequest(request(okBody, { "x-sketch-device": "" }), env(), { fetch: fetchMock });
    expect(noDevice.status).toBe(400);
  });

  it("enforces the daily quota per device and skips it for Pro", async () => {
    const fetchMock: typeof fetch = async () => new Response("{}", { status: 200 });
    const e = env();
    expect((await handleRequest(request(okBody), e, { fetch: fetchMock })).status).toBe(200);
    expect((await handleRequest(request(okBody), e, { fetch: fetchMock })).status).toBe(200);
    const third = await handleRequest(request(okBody), e, { fetch: fetchMock });
    expect(third.status).toBe(429);
    expect(((await third.json()) as { error: { message: string } }).error.message).toContain("Daily free limit");

    const pro = await handleRequest(request(okBody), e, { fetch: fetchMock, isPro: async () => true });
    expect(pro.status).toBe(200);
    expect(pro.headers.get("x-sketch-quota")).toBe("pro");
  });

  it("does not burn quota on upstream failures", async () => {
    const fetchMock: typeof fetch = async () => new Response("{}", { status: 500 });
    const e = env();
    for (let i = 0; i < 3; i++) {
      expect((await handleRequest(request(okBody), e, { fetch: fetchMock })).status).toBe(500);
    }
  });

  it("validates the model and caps max_tokens", async () => {
    let forwarded: { max_tokens: number } | null = null;
    const fetchMock: typeof fetch = async (_url, init) => {
      forwarded = JSON.parse(String(init!.body));
      return new Response("{}", { status: 200 });
    };
    const badModel = await handleRequest(request({ ...okBody, model: "claude-haiku-4-5" }), env(), { fetch: fetchMock });
    expect(badModel.status).toBe(400);
    const res = await handleRequest(request({ ...okBody, max_tokens: 99999 }), env(), { fetch: fetchMock });
    expect(res.status).toBe(200);
    expect(forwarded!.max_tokens).toBe(1000);
  });

  it("streams SSE bodies through untouched", async () => {
    const sse = "event: message_start\ndata: {}\n\n";
    const fetchMock: typeof fetch = async () =>
      new Response(sse, { status: 200, headers: { "content-type": "text/event-stream" } });
    const res = await handleRequest(request({ ...okBody, stream: true }), env(), { fetch: fetchMock });
    expect(res.headers.get("content-type")).toBe("text/event-stream");
    expect(await res.text()).toBe(sse);
  });

  it("answers health checks and unknown routes", async () => {
    const health = await handleRequest(new Request("https://proxy.example/health"), env());
    expect(health.status).toBe(200);
    const other = await handleRequest(new Request("https://proxy.example/nope", { method: "POST" }), env());
    expect(other.status).toBe(404);
  });
});
