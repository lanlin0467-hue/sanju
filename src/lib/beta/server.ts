import { createBetaAPI } from "./api";
import { database } from "./database";
import { liveWriter } from "./model";
import { json, problem } from "./contracts";

export function betaEnabled() { return process.env.SANJU_BETA_ENABLED === "1"; }
export function betaAPI() {
  if (!betaEnabled() || !process.env.DATABASE_URL || process.env.FAKE_MODEL === "1") throw new Error("beta_not_configured");
  const limit = Number(process.env.SANJU_BETA_DAILY_MODEL_CALLS ?? 40);
  if (!Number.isSafeInteger(limit) || limit < 2 || limit > 10000) throw new Error("invalid_budget");
  return createBetaAPI(database(), liveWriter(), { dailyCalls: limit });
}
export async function invoke(method: "GET" | "POST" | "join" | "signOut" | "feedback", request: Request) {
  try { return await betaAPI()[method](request); } catch (error) { return problem(error); }
}
export async function health() {
  try {
    if (!betaEnabled() || process.env.FAKE_MODEL === "1" || !(process.env.SANJU_MODEL_API_KEY || process.env.MODEL_API_KEY)) throw new Error();
    await database().query("SELECT 1 FROM sanju_beta.testers LIMIT 1");
    return json({ status: "ready", mode: "live", apiVersion: 1, provider: process.env.SANJU_MODEL_PROVIDER ?? "openrouter" });
  } catch { return json({ status: "unavailable" }, 503); }
}
