import { beforeAll, beforeEach, afterAll, describe, expect, it, vi } from "vitest";
import { PGlite } from "@electric-sql/pglite";
import { readFileSync } from "node:fs";
import { createBetaAPI } from "./api";
import { digest, type Line } from "./contracts";
import type { Database, SQL } from "./database";
import { writer, type Writer, type Completion } from "./model";
import { nativeSamples } from "../nativeGeneration";

const id = (n: number) => `00000000-0000-4000-8000-${String(n).padStart(12,"0")}`;
const code = "Sanju_test_invitation_123456";
const input = { scene: "黄昏的海边", mood: "平静", image: "data:image/jpeg;base64,/9j/2Q==" };
const op = (n = 2, creation = 90) => ({ requestId: id(n), creationId: id(creation), input });
const lines: Line[] = ["cool","romantic","youth"].map(style => ({ style: style as Line["style"], text: nativeSamples[style as Line["style"]][0] }));
let pg: PGlite; let db: Database; let time: number;
function req(body?: object, token = "", path = "generations") { return new Request(`http://localhost/api/v1/${path}`, { method: body ? "POST" : "GET", headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json", "x-real-ip": "127.0.0.1" }, ...(body ? { body: JSON.stringify(body) } : {}) }); }
function adapter(pg: Pick<PGlite, "query">): SQL { return { async query<T>(text: string, values: unknown[] = []) { return { rows: (await pg.query(text, values)).rows as T[] }; } }; }
const setup = (model: Writer = async () => lines, budget = 200) => createBetaAPI(db, model, { now: () => time, dailyCalls: budget });
async function join(api = setup(), invitation = code) {
  const reply = await api.join(req({ code: invitation }, "", "sessions"));
  expect(reply.status).toBe(200); return (await reply.json()).token as string;
}

beforeAll(async () => {
  pg = new PGlite(); await pg.exec(readFileSync("db/migrations/001_beta.sql", "utf8"));
  db = { ...adapter(pg), transaction: work => pg.transaction(tx => work(adapter(tx as unknown as PGlite))) };
}, 30_000);
afterAll(async () => { await pg.close(); });
beforeEach(async () => {
  await pg.exec("TRUNCATE sanju_beta.testers,sanju_beta.budget,sanju_beta.login_limits CASCADE");
  time = Date.parse("2026-10-19T10:00:00Z");
  await db.query("INSERT INTO sanju_beta.testers(id,code_hash,label,expires_at) VALUES($1,$2,'tester',$3)", [id(1), digest(code), new Date(time + 30 * 86400_000)]);
});

describe("durable beta backend using PostgreSQL", () => {
  it("requires an invitation and rejects forged installation identities", async () => {
    const api = setup(); expect((await api.POST(req(op()))).status).toBe(401);
    expect((await api.join(req({ code: "wrong_invitation_1234567890" }))).status).toBe(401);
    const token = await join(); expect((await api.GET(req(undefined, token))).status).toBe(200);
    const stored = (await db.query<{ token_hash: string }>("SELECT token_hash FROM sanju_beta.sessions")).rows[0];
    expect(stored.token_hash).not.toBe(token); expect(stored.token_hash).toBe(digest(token));
  });
  it("persists across API instances and replays without another model call or quota charge", async () => {
    const model = vi.fn<Writer>(async () => lines); const api = setup(model); const token = await join(api);
    const first = await (await api.POST(req(op(), token))).json(); expect(first.quota.remaining).toBe(4);
    const another = setup(model);
    expect(await (await another.POST(req(op(), token))).json()).toEqual(first);
    expect((await another.GET(new Request(`http://localhost/api/v1/generations?requestId=${id(2)}`, { headers: { Authorization: `Bearer ${token}` } }))).status).toBe(200);
    expect(model).toHaveBeenCalledTimes(1);
    const dump = JSON.stringify((await db.query("SELECT * FROM sanju_beta.jobs")).rows);
    expect(dump).not.toContain(input.image); expect(dump).not.toContain(input.scene);
  });
  it("serializes concurrent reservations and only calls the model once", async () => {
    let finish!: (value: Line[]) => void;
    const model = vi.fn<Writer>(() => new Promise(resolve => { finish = resolve; }));
    const api = setup(model); const token = await join(api);
    const pending = api.POST(req(op(), token));
    await vi.waitFor(() => expect(model).toHaveBeenCalledTimes(1));
    expect((await setup(model).POST(req(op(), token))).status).toBe(202);
    expect((await setup(model).POST(req(op(3,91), token))).status).toBe(409);
    finish(lines); expect((await pending).status).toBe(200);
    expect(model).toHaveBeenCalledTimes(1);
  });
  it("uses original image and server versions on swaps, with exactly three shared swaps", async () => {
    const model = vi.fn<Writer>(async (_input, requested, previous) => requested.map(style => ({ style, text: nativeSamples[style].find(line => !previous.includes(line))! })));
    const api = setup(model); const token = await join(api); await api.POST(req(op(), token));
    for (let n = 3; n <= 5; n++) {
      const reply = await (await api.POST(req({ ...op(n), style: "cool", previous: ["forged"] }, token))).json();
      expect(reply.swapsRemaining).toBe(5-n); expect(reply.quota.remaining).toBe(4);
    }
    expect((await api.POST(req({ ...op(6), style: "romantic" }, token))).status).toBe(429);
    expect(model.mock.calls[1][0].image).toBe(input.image);
    expect(model.mock.calls[1][2]).toEqual([nativeSamples.cool[0]]);
    expect((await api.POST(req({ ...op(7), style: "cool", input: { ...input, mood: "开心" } }, token))).status).toBe(409);
  });
  it("refunds failed creation exactly once and keeps the global paid-call budget consumed", async () => {
    const model = vi.fn<Writer>(async () => { throw new Error("SECRET upstream key"); });
    const api = setup(model,2); const token = await join(api);
    expect((await api.POST(req(op(), token))).status).toBe(502);
    const replay = await api.POST(req(op(), token)); expect(replay.status).toBe(502); expect(await replay.text()).not.toContain("SECRET");
    expect((await (await api.GET(req(undefined, token))).json()).quota.remaining).toBe(5);
    expect((await api.POST(req(op(3,91), token))).status).toBe(429);
    expect(model).toHaveBeenCalledTimes(1);
  });
  it("reconciles a killed request without repeating a paid call", async () => {
    const model = vi.fn<Writer>(async () => lines); const api = setup(model); const token = await join(api);
    const { BetaRepository } = await import("./repository"); const { operation } = await import("./contracts");
    await new BetaRepository(db, () => time,200).claim(id(1), operation(op()));
    time += 121_000;
    expect((await api.POST(req(op(), token))).status).toBe(502);
    expect((await (await api.GET(req(undefined, token))).json()).quota.remaining).toBe(5);
    expect(model).not.toHaveBeenCalled();
  });
  it("shares quota between sessions, resets at Beijing midnight, and expires swaps after 24h", async () => {
    const api = setup(); const token = await join(api); const token2 = await join(api);
    await api.POST(req(op(), token));
    expect((await (await api.GET(req(undefined,token2))).json()).quota.remaining).toBe(4);
    time = Date.parse("2026-10-19T16:01:00Z");
    expect((await (await api.GET(req(undefined,token2))).json()).quota.remaining).toBe(5);
    time += 86400_000;
    expect((await api.POST(req({...op(3),style:"cool"},token))).status).toBe(410);
  });
  it("does not expose another tester's requests and supports immediate revocation", async () => {
    const api=setup(); const token=await join(api); await api.POST(req(op(),token));
    const otherCode="another_invitation_1234567890";
    await db.query("INSERT INTO sanju_beta.testers(id,code_hash,label,expires_at) VALUES($1,$2,'other',$3)",[id(10),digest(otherCode),new Date(time+86400_000)]);
    const other=await join(api,otherCode);
    expect((await api.POST(req(op(),other))).status).toBe(404);
    await db.query("UPDATE sanju_beta.testers SET revoked=true WHERE id=$1",[id(1)]);
    expect((await api.GET(req(undefined,token))).status).toBe(401);
  });
  it("limits unsuccessful joins without rolling back the counter", async () => {
    const api=setup();
    for(let n=0;n<10;n++) expect((await api.join(req({code:"wrong_invitation_1234567890"}))).status).toBe(401);
    expect((await api.join(req({code}))).status).toBe(429);
    time+=61_000; expect(await join(api)).toHaveLength(43);
  });
  it("rejects oversized bodies even with no Content-Length", async () => {
    const api=setup(); const token=await join(api);
    expect((await api.POST(req({...op(),padding:"x".repeat(750001)},token))).status).toBe(413);
  });
  it("stores feedback only after an authenticated explicit submission", async () => {
    const api=setup(); const token=await join(api); await api.POST(req(op(),token));
    expect((await api.feedback(req({creationId:id(90),category:"quality",note:"这句没有贴合画面"},token))).status).toBe(200);
    expect((await db.query("SELECT * FROM sanju_beta.feedback")).rows).toHaveLength(1);
    expect((await api.feedback(req({category:"quality",note:""},token))).status).toBe(400);
  });
});

describe("native live writer",()=>{
  it("gives measured lengths to the repair and accepts a valid corrected sentence",async()=>{
    const completion=vi.fn<Completion>().mockResolvedValueOnce(JSON.stringify({cool:"短"})).mockResolvedValueOnce(JSON.stringify({cool:nativeSamples.cool[0]}));
    const lines=await writer(completion)(input,["cool"],[]);
    expect(lines[0].text).toBe(nativeSamples.cool[0]);
    expect(completion.mock.calls[1][0]).toContain("cool=1");
    expect(completion.mock.calls[1][1]).toBe(input.image);
  });
  it("repairs once, preserves the image, and rejects invalid output",async()=>{
    const completion=vi.fn<Completion>(async()=>JSON.stringify({cool:"短"}));
    await expect(writer(completion)(input,["cool"],[])).rejects.toThrow("invalid_output");
    expect(completion).toHaveBeenCalledTimes(2); expect(completion.mock.calls[1][1]).toBe(input.image);
  });
});
