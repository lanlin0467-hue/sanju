import { describe, expect, it, vi } from "vitest";
import { createNativeGenerationAPI, nativeSamples } from "./nativeGeneration";
import type { ModelContent } from "./modelClient";

const owner = "00000000-0000-4000-8000-000000000001";
const id = (value: number) => `00000000-0000-4000-8000-${String(value).padStart(12, "0")}`;
const output = JSON.stringify(Object.fromEntries(Object.entries(nativeSamples).map(([style, lines]) => [style, lines[0]])));
const image = "data:image/jpeg;base64,/9j/2Q==";
const input = { scene: "黄昏的海边", mood: "平静", image };
const request = (body: object) => new Request("http://localhost/api/v1/generations", { method: "POST", headers: { "X-Sanju-Installation": owner, "Content-Type": "application/json" }, body: JSON.stringify(body) });
const get = (requestId?: string, installation = owner) => new Request(`http://localhost/api/v1/generations${requestId ? `?requestId=${requestId}` : ""}`, { headers: { "X-Sanju-Installation": installation } });
const operation = (value = 2) => ({ requestId: id(value), creationId: id(90), input });

describe("native generation contract", () => {
  it("creates three styles once and replays a lost response without charging twice", async () => {
    const model = vi.fn<(content: ModelContent) => Promise<string>>(async () => output);
    const api = createNativeGenerationAPI({ enabled: () => true, model, fixture: () => false });
    const reply = await (await api.POST(request(operation()))).json();
    expect(reply.lines.map((line: { style: string }) => line.style)).toEqual(["cool", "romantic", "youth"]);
    expect(reply.quota.remaining).toBe(4);
    expect((await (await api.POST(request(operation()))).json()).quota.remaining).toBe(4);
    expect((await (await api.GET(get(id(2)))).json()).creationId).toBe(id(90));
    expect(model).toHaveBeenCalledTimes(1);
  });
  it("preserves the original picture for replacements and validates the input snapshot", async () => {
    const model = vi.fn<(content: ModelContent) => Promise<string>>(async () => output);
    const api = createNativeGenerationAPI({ enabled: () => true, model, fixture: () => false });
    await api.POST(request(operation()));
    model.mockResolvedValue(JSON.stringify({ cool: nativeSamples.cool[1] }));
    const response = await api.POST(request({ ...operation(3), style: "cool", previous: [] }));
    expect(response.status).toBe(200);
    const reply = await response.json();
    expect(reply.swapsRemaining).toBe(2); expect(reply.quota.remaining).toBe(4);
    expect(model.mock.calls[1][0]).toContainEqual({ type: "image_url", image_url: { url: image } });
    const text = JSON.stringify(model.mock.calls[1][0]);
    expect(text).toContain(nativeSamples.cool[0]);
    expect(text).not.toContain("鲁迅");
    expect((await api.POST(request({ ...operation(4), style: "cool", input: { ...input, mood: "开心" } }))).status).toBe(409);
    expect(model).toHaveBeenCalledTimes(2);
  });
  it("refunds failed creations and hides upstream error details", async () => {
    const api = createNativeGenerationAPI({ enabled: () => true, fixture: () => false, model: async () => { throw new Error("SECRET upstream detail"); } });
    const response = await api.POST(request(operation()));
    expect(response.status).toBe(502);
    expect(await response.text()).not.toContain("SECRET");
    expect((await (await api.GET(get())).json()).quota.remaining).toBe(5);
  });
  it("does not accept malformed or still invalid output after one repair", async () => {
    const model = vi.fn(async () => JSON.stringify({ cool: "短", romantic: "短", youth: "短" }));
    const api = createNativeGenerationAPI({ enabled: () => true, fixture: () => false, model });
    expect((await api.POST(request(operation()))).status).toBe(502);
    expect(model).toHaveBeenCalledTimes(2);
    expect((await (await api.GET(get())).json()).quota.remaining).toBe(5);
  });
  it("only allows three successful swaps and ignores client supplied old versions", async () => {
    const api = createNativeGenerationAPI({ enabled: () => true, fixture: () => true });
    await api.POST(request(operation()));
    for (let number = 3; number < 6; number++) {
      expect((await (await api.POST(request({ ...operation(number), style: "cool", previous: [] }))).json()).swapsRemaining).toBe(5 - number);
    }
    expect((await api.POST(request({ ...operation(6), style: "cool" }))).status).toBe(429);
    expect((await (await api.GET(get())).json()).quota.remaining).toBe(4);
  });
  it("prevents another installation from accessing a job", async () => {
    const api = createNativeGenerationAPI({ enabled: () => true, fixture: () => true });
    await api.POST(request(operation()));
    expect((await api.GET(get(id(2), id(20)))).status).toBe(404);
  });
  it("recovers a pending request without calling the model again", async () => {
    let finish!: (value: string) => void;
    const model = vi.fn(() => new Promise<string>(resolve => { finish = resolve; }));
    const api = createNativeGenerationAPI({ enabled: () => true, fixture: () => false, model });
    const pending = api.POST(request(operation()));
    await vi.waitFor(() => expect(model).toHaveBeenCalledTimes(1));
    expect((await api.GET(get(id(2)))).status).toBe(202);
    expect((await api.POST(request(operation()))).status).toBe(202);
    finish(output); expect((await pending).status).toBe(200);
    expect(model).toHaveBeenCalledTimes(1);
  });
  it("resets the user quota at Beijing midnight while keeping 24-hour swaps", async () => {
    let time = Date.parse("2026-10-19T15:59:00Z");
    const api = createNativeGenerationAPI({ enabled: () => true, fixture: () => true, now: () => time });
    const reply = await (await api.POST(request(operation()))).json();
    expect(reply.quota.resetsAt).toBe("2026-10-19T16:00:00Z");
    time += 120_000;
    expect((await (await api.GET(get())).json()).quota.remaining).toBe(5);
    expect((await api.POST(request({ ...operation(3), style: "cool" }))).status).toBe(200);
  });
  it("keeps the development-only backend closed when disabled", async () => {
    const model = vi.fn(); const api = createNativeGenerationAPI({ enabled: () => false, model });
    expect((await api.POST(request(operation()))).status).toBe(503);
    expect(model).not.toHaveBeenCalled();
  });
});
