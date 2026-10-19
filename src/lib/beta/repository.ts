import { randomBytes, randomUUID } from "node:crypto";
import type { Database, SQL } from "./database";
import { APIError, day, digest, iso, resetTime, type Line, type Operation, type Quota, type Reply, type Style } from "./contracts";

type Job = { id: string; tester_id: string; creation_id: string; digest: string; style: Style | null; status: string; reply: Reply | null; quota_day: string; lease_until: Date; expires_at: Date };
type Creation = { id: string; digest: string; ready: boolean; expires_at: Date; swaps: number; versions: Record<Style, string[]> };
export type Claim = { job: Job; previous: string[]; execute: boolean; quota: Quota };
export class BetaRepository {
  constructor(private db: Database, private now: () => number = Date.now, private dailyCalls = 40) {}
  private async tester<T>(id: string, work: (sql: SQL) => Promise<T>) {
    return this.db.transaction(async sql => {
      const row = (await sql.query<{ id: string }>("SELECT id FROM sanju_beta.testers WHERE id=$1 AND NOT revoked AND expires_at>$2 FOR UPDATE", [id, new Date(this.now())])).rows[0];
      if (!row) throw new APIError(401, "unauthorized", "内测资格已过期，请重新输入有效邀请码。");
      await this.expire(sql, id);
      return work(sql);
    });
  }
  private async quotaIn(sql: SQL, id: string): Promise<Quota> {
    const used = (await sql.query<{ used: number }>("SELECT used FROM sanju_beta.usage WHERE tester_id=$1 AND day=$2", [id, day(this.now())])).rows[0]?.used ?? 0;
    return { remaining: Math.max(0, 5 - used), resetsAt: iso(resetTime(this.now())) };
  }
  private async failIn(sql: SQL, job: Job, code: string) {
    await sql.query("UPDATE sanju_beta.jobs SET status='failed', failure_code=$2 WHERE id=$1", [job.id, code]);
    if (!job.style) {
      await sql.query("UPDATE sanju_beta.usage SET used=GREATEST(0,used-1) WHERE tester_id=$1 AND day=$2", [job.tester_id, job.quota_day]);
      await sql.query("DELETE FROM sanju_beta.creations WHERE id=$1 AND NOT ready", [job.creation_id]);
    }
  }
  private async expire(sql: SQL, id: string) {
    const stale = (await sql.query<Job>("SELECT * FROM sanju_beta.jobs WHERE tester_id=$1 AND status='processing' AND lease_until<=$2 FOR UPDATE", [id, new Date(this.now())])).rows;
    for (const job of stale) await this.failIn(sql, job, "interrupted");
  }
  async session(code: string, address: string) {
    if (!/^[A-Za-z0-9_-]{20,100}$/.test(code)) throw new APIError(401, "invalid_invite", "邀请码无效或已过期。");
    return this.db.transaction(async sql => {
      const key = digest(address);
      const limit = (await sql.query<{ attempts: number }>(`INSERT INTO sanju_beta.login_limits(address_hash,started_at,attempts) VALUES($1,$2,1)
        ON CONFLICT(address_hash) DO UPDATE SET attempts=CASE WHEN sanju_beta.login_limits.started_at<$2::timestamptz-interval '1 minute' THEN 1 ELSE sanju_beta.login_limits.attempts+1 END,
        started_at=CASE WHEN sanju_beta.login_limits.started_at<$2::timestamptz-interval '1 minute' THEN $2 ELSE sanju_beta.login_limits.started_at END RETURNING attempts`, [key, new Date(this.now())])).rows[0];
      // Return an error value rather than throwing: failed logins must commit their rate count.
      if (limit.attempts > 10) return { error: new APIError(429, "rate_limited", "尝试次数较多，请一分钟后再试。") };
      const tester = (await sql.query<{ id: string; expires_at: Date }>("SELECT id,expires_at FROM sanju_beta.testers WHERE code_hash=$1 AND NOT revoked AND expires_at>$2 FOR UPDATE", [digest(code), new Date(this.now())])).rows[0];
      if (!tester) return { error: new APIError(401, "invalid_invite", "邀请码无效或已过期。") };
      const token = randomBytes(32).toString("base64url");
      const expiresAt = new Date(Math.min(new Date(tester.expires_at).getTime(), this.now() + 30 * 86400_000));
      await sql.query("INSERT INTO sanju_beta.sessions(token_hash,tester_id,expires_at) VALUES($1,$2,$3)", [digest(token), tester.id, expiresAt]);
      return { token, expiresAt: iso(expiresAt) };
    }).then(result => { if ("error" in result) throw result.error; return result; });
  }
  async authenticate(token: string) {
    if (!/^[A-Za-z0-9_-]{43}$/.test(token)) throw new APIError(401, "unauthorized", "请先输入内测邀请码。");
    const tester = (await this.db.query<{ tester_id: string }>(`SELECT s.tester_id FROM sanju_beta.sessions s JOIN sanju_beta.testers t ON t.id=s.tester_id
      WHERE s.token_hash=$1 AND s.expires_at>$2 AND t.expires_at>$2 AND NOT t.revoked`, [digest(token), new Date(this.now())])).rows[0];
    if (!tester) throw new APIError(401, "unauthorized", "内测资格已过期，请重新输入邀请码。");
    return tester.tester_id;
  }
  async signOut(token: string) { await this.db.query("DELETE FROM sanju_beta.sessions WHERE token_hash=$1", [digest(token)]); }
  async quota(id: string) { return this.tester(id, sql => this.quotaIn(sql, id)); }
  async get(id: string, requestId: string) {
    return this.tester(id, async sql => {
      const job = (await sql.query<Job>("SELECT * FROM sanju_beta.jobs WHERE id=$1 AND tester_id=$2", [requestId, id])).rows[0];
      if (!job) throw new APIError(404, "not_found", "没有找到这次请求。");
      if (new Date(job.expires_at).getTime() <= this.now()) throw new APIError(410, "expired", "这次请求的恢复期限已结束。");
      return { job, quota: await this.quotaIn(sql, id) };
    });
  }
  async claim(id: string, op: Operation): Promise<Claim> {
    return this.tester(id, async sql => {
      const existing = (await sql.query<Job>("SELECT * FROM sanju_beta.jobs WHERE id=$1", [op.requestId])).rows[0];
      if (existing) {
        if (existing.tester_id !== id) throw new APIError(404, "not_found", "没有找到这次请求。");
        if (existing.digest !== op.digest) throw new APIError(409, "conflict", "请求内容发生变化，请重新创作。");
        if (new Date(existing.expires_at).getTime() <= this.now()) throw new APIError(410, "expired", "这次请求的恢复期限已结束。");
        return { job: existing, previous: [], execute: false, quota: await this.quotaIn(sql, id) };
      }
      const active = (await sql.query("SELECT id FROM sanju_beta.jobs WHERE tester_id=$1 AND status='processing' LIMIT 1", [id])).rows[0];
      if (active) throw new APIError(409, "busy", "有一句还在写，请先确认上次结果。");
      const record = (await sql.query<Creation>("SELECT * FROM sanju_beta.creations WHERE id=$1 AND tester_id=$2 FOR UPDATE", [op.creationId, id])).rows[0];
      if (op.style) {
        if (!record?.ready || new Date(record.expires_at).getTime() <= this.now()) throw new APIError(410, "expired", "这份创作的换句机会已到期。");
        if (record.digest !== op.inputDigest) throw new APIError(409, "conflict", "换句需要保留原来的画面和心情。");
        if (record.swaps <= 0) throw new APIError(429, "swaps_exhausted", "本次换句已用完。");
      } else if (record) throw new APIError(409, "conflict", "这份创作已经存在，请查看原结果。");
      const now = new Date(this.now()); const today = day(this.now());
      await sql.query("INSERT INTO sanju_beta.usage(tester_id,day,minute_at) VALUES($1,$2,$3) ON CONFLICT DO NOTHING", [id, today, now]);
      const usage = (await sql.query<{ used: number; calls: number; minute_at: Date }>("SELECT * FROM sanju_beta.usage WHERE tester_id=$1 AND day=$2 FOR UPDATE", [id, today])).rows[0];
      if (!op.style && usage.used >= 5) throw new APIError(429, "quota_exhausted", "今天的创作次数已用完，明天00:00恢复。");
      const calls = new Date(usage.minute_at).getTime() + 60_000 <= this.now() ? 0 : usage.calls;
      if (calls >= 6) throw new APIError(429, "rate_limited", "写得有些快，请一分钟后再试。");
      await sql.query("INSERT INTO sanju_beta.budget(day) VALUES($1) ON CONFLICT DO NOTHING", [today]);
      const budget = (await sql.query<{ calls: number }>("SELECT calls FROM sanju_beta.budget WHERE day=$1 FOR UPDATE", [today])).rows[0];
      // Reserve both possible model calls. Failed work still costs money; never refund this cap.
      if (budget.calls + 2 > this.dailyCalls) throw new APIError(429, "service_budget", "今天的内测服务额度已用完，明天再来。");
      await sql.query("UPDATE sanju_beta.budget SET calls=calls+2 WHERE day=$1", [today]);
      await sql.query("UPDATE sanju_beta.usage SET used=used+$3,calls=$4,minute_at=$5 WHERE tester_id=$1 AND day=$2", [id, today, op.style ? 0 : 1, calls + 1, calls === 0 ? now : usage.minute_at]);
      if (!op.style) await sql.query("INSERT INTO sanju_beta.creations(id,tester_id,digest,expires_at) VALUES($1,$2,$3,$4)", [op.creationId, id, op.inputDigest, new Date(this.now() + 86400_000)]);
      const job = (await sql.query<Job>(`INSERT INTO sanju_beta.jobs(id,tester_id,creation_id,digest,style,status,quota_day,lease_until,created_at,expires_at)
        VALUES($1,$2,$3,$4,$5,'processing',$6,$7,$8,$9) RETURNING *`, [op.requestId, id, op.creationId, op.digest, op.style ?? null, today, new Date(this.now() + 120_000), now, new Date(this.now() + 7 * 86400_000)])).rows[0];
      return { job, previous: op.style ? record.versions[op.style] : [], execute: true, quota: await this.quotaIn(sql, id) };
    });
  }
  async finish(id: string, requestId: string, lines: Line[]) {
    return this.tester(id, async sql => {
      const job = (await sql.query<Job>("SELECT * FROM sanju_beta.jobs WHERE id=$1 AND tester_id=$2 FOR UPDATE", [requestId, id])).rows[0];
      if (!job || job.status !== "processing") throw new APIError(409, "interrupted", "这次请求已中断，次数已保留，请重新创作。");
      const record = (await sql.query<Creation>("SELECT * FROM sanju_beta.creations WHERE id=$1 AND tester_id=$2 FOR UPDATE", [job.creation_id, id])).rows[0];
      if (!record) throw new Error("record_missing");
      for (const line of lines) record.versions[line.style].push(line.text);
      const swaps = record.swaps - (job.style ? 1 : 0);
      await sql.query("UPDATE sanju_beta.creations SET ready=true,swaps=$2,versions=$3::jsonb WHERE id=$1", [record.id, swaps, JSON.stringify(record.versions)]);
      const reply: Reply = { creationId: record.id, lines, swapsRemaining: swaps, expiresAt: iso(record.expires_at), quota: await this.quotaIn(sql, id) };
      await sql.query("UPDATE sanju_beta.jobs SET status='succeeded',reply=$2::jsonb WHERE id=$1", [job.id, JSON.stringify(reply)]);
      return reply;
    });
  }
  async fail(id: string, requestId: string) {
    return this.tester(id, async sql => {
      const job = (await sql.query<Job>("SELECT * FROM sanju_beta.jobs WHERE id=$1 AND tester_id=$2 FOR UPDATE", [requestId, id])).rows[0];
      if (job?.status === "processing") await this.failIn(sql, job, "generation_failed");
    });
  }
  async feedback(id: string, creationId: string | undefined, category: string, note: string) {
    return this.tester(id, async sql => {
      if (creationId && !(await sql.query("SELECT id FROM sanju_beta.creations WHERE id=$1 AND tester_id=$2", [creationId, id])).rows[0]) throw new APIError(404, "not_found", "没有找到这份创作。");
      const count = (await sql.query<{ count: string }>("SELECT count(*) FROM sanju_beta.feedback WHERE tester_id=$1 AND created_at>$2", [id, new Date(this.now() - 3600_000)])).rows[0];
      if (Number(count.count) >= 10) throw new APIError(429, "rate_limited", "反馈已收到，请稍后再提交。");
      await sql.query("INSERT INTO sanju_beta.feedback(id,tester_id,creation_id,category,note,created_at) VALUES($1,$2,$3,$4,$5,$6)", [randomUUID(), id, creationId ?? null, category, note, new Date(this.now())]);
    });
  }
}
