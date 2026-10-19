import { timingSafeEqual } from "node:crypto";
import type { Database } from "./database";
export function validCronAuthorization(value: string | null) {
  const expected = process.env.CRON_SECRET;
  if (!expected || !value) return false;
  const a = Buffer.from(value); const b = Buffer.from(`Bearer ${expected}`);
  return a.length === b.length && timingSafeEqual(a,b);
}
export async function cleanup(db: Database) {
  await db.transaction(async sql => {
    // Daily pruning bounds physical retention to 8 and 31 days respectively.
    await sql.query("DELETE FROM sanju_beta.jobs WHERE expires_at<now()");
    await sql.query("DELETE FROM sanju_beta.creations WHERE expires_at<now()-interval '6 days'");
    await sql.query("DELETE FROM sanju_beta.feedback WHERE created_at<now()-interval '30 days'");
    await sql.query("DELETE FROM sanju_beta.sessions WHERE expires_at<now()");
    await sql.query("DELETE FROM sanju_beta.login_limits WHERE started_at<now()-interval '1 day'");
    await sql.query("DELETE FROM sanju_beta.usage WHERE day<to_char(now()-interval '8 days','YYYY-MM-DD')");
    await sql.query("DELETE FROM sanju_beta.budget WHERE day<to_char(now()-interval '8 days','YYYY-MM-DD')");
  });
}
