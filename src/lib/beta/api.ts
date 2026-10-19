import type { Database } from "./database";
import { APIError, body, json, operation, problem, styles, uuid } from "./contracts";
import { BetaRepository, type Claim } from "./repository";
import type { Writer } from "./model";

export function createBetaAPI(db: Database, write: Writer, options: { now?: () => number; dailyCalls?: number } = {}) {
  const repo = new BetaRepository(db, options.now, options.dailyCalls);
  const token = (request: Request) => request.headers.get("authorization")?.replace(/^Bearer /, "") ?? "";
  async function owner(request: Request) { return repo.authenticate(token(request)); }
  function replay(value: Pick<Claim, "job" | "quota">) {
    if (value.job.status === "succeeded" && value.job.reply) return json({ ...value.job.reply, quota: value.quota });
    if (value.job.status === "failed") return json({ error: "这次没有写好，次数已保留，请重新创作。", code: "generation_failed" }, 502);
    return json({ status: "processing" }, 202);
  }
  return {
    async GET(request: Request) {
      try {
        const id = await owner(request); const requestId = new URL(request.url).searchParams.get("requestId")?.toLowerCase();
        if (!requestId) return json({ quota: await repo.quota(id) });
        if (!uuid.test(requestId)) throw new APIError(400, "invalid_input", "请求标识无效。");
        return replay(await repo.get(id, requestId));
      } catch (error) { return problem(error); }
    },
    async POST(request: Request) {
      try {
        const id = await owner(request); const op = operation(await body(request, 750_000));
        const claim = await repo.claim(id, op);
        if (!claim.execute) return replay(claim);
        let lines;
        try { lines = await write(op.input, op.style ? [op.style] : styles, claim.previous); }
        catch {
          // If the refund cannot be persisted, keep the result uncertain so the
          // original request can be reconciled after its lease instead of re-run.
          await repo.fail(id, op.requestId);
          return json({ error: "这次没有写好，次数已保留，请稍后重试。", code: "generation_failed" }, 502);
        }
        // Never mark a model failure after an ambiguous database commit.
        return json(await repo.finish(id, op.requestId, lines));
      } catch (error) { return problem(error); }
    },
    async join(request: Request) {
      try {
        const raw = await body(request, 1024);
        if (typeof raw.code !== "string") throw new APIError(400, "invalid_input", "请输入内测邀请码。");
        const address = request.headers.get("x-vercel-forwarded-for") ?? request.headers.get("x-real-ip") ?? "local";
        return json(await repo.session(raw.code.trim(), address));
      } catch (error) { return problem(error); }
    },
    async signOut(request: Request) {
      try { await owner(request); await repo.signOut(token(request)); return json({ ok: true }); }
      catch (error) { return problem(error); }
    },
    async feedback(request: Request) {
      try {
        const id = await owner(request); const raw = await body(request, 4096);
        if (!["quality", "inappropriate", "problem"].includes(String(raw.category)) || typeof raw.note !== "string" || raw.note.length > 500 || !raw.note.trim()) throw new APIError(400, "invalid_input", "请填写500字以内的反馈。");
        if (raw.creationId != null && (typeof raw.creationId !== "string" || !uuid.test(raw.creationId))) throw new APIError(400, "invalid_input", "创作标识无效。");
        await repo.feedback(id, raw.creationId as string | undefined, raw.category as string, raw.note.trim());
        return json({ ok: true });
      } catch (error) { return problem(error); }
    },
  };
}
