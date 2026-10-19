import { createHash } from "node:crypto";
import { validateImageDataUrl } from "@/lib/image";

export const styles = ["cool", "romantic", "youth"] as const;
export type Style = typeof styles[number];
export type Input = { scene: string; mood: string; image?: string };
export type Operation = { requestId: string; creationId: string; input: Input; style?: Style; inputDigest: string; digest: string };
export type Line = { style: Style; text: string };
export type Quota = { remaining: number; resetsAt: string };
export type Reply = { creationId: string; lines: Line[]; swapsRemaining: number; expiresAt: string; quota: Quota };
export const uuid = /^[\da-f]{8}-[\da-f]{4}-[\da-f]{4}-[\da-f]{4}-[\da-f]{12}$/i;
export const digest = (text: string) => createHash("sha256").update(text).digest("hex");
export const iso = (time: number | Date) => new Date(time).toISOString().replace(/\.\d{3}Z$/, "Z");
export const day = (time: number) => new Date(time + 8 * 3600_000).toISOString().slice(0, 10);
export const resetTime = (time: number) => Date.parse(`${day(time)}T00:00:00+08:00`) + 24 * 3600_000;
export class APIError extends Error {
  constructor(public status: number, public code: string, message: string) { super(message); }
}
export const json = (value: unknown, status = 200) => Response.json(value, { status, headers: { "Cache-Control": "no-store", "X-Content-Type-Options": "nosniff" } });
export function problem(error: unknown) {
  if (error instanceof APIError) return json({ error: error.message, code: error.code }, error.status);
  return json({ error: "服务暂时无法连接，请稍后确认结果。", code: "unavailable" }, 503);
}
// Read incrementally; Content-Length is optional and must not bypass the limit.
export async function body(request: Request, limit: number): Promise<Record<string, unknown>> {
  if (!request.headers.get("content-type")?.startsWith("application/json")) throw new APIError(415, "invalid_input", "请使用 JSON 请求。");
  if (Number(request.headers.get("content-length")) > limit) throw new APIError(413, "invalid_input", "请求内容太大。");
  const reader = request.body?.getReader();
  if (!reader) throw new APIError(400, "invalid_input", "请求内容为空。");
  const chunks: Uint8Array[] = []; let bytes = 0;
  try {
    while (true) {
      const { done, value } = await reader.read(); if (done) break;
      bytes += value.byteLength;
      if (bytes > limit) { await reader.cancel(); throw new APIError(413, "invalid_input", "请求内容太大。"); }
      chunks.push(value);
    }
    const object = JSON.parse(Buffer.concat(chunks).toString("utf8"));
    if (!object || typeof object !== "object" || Array.isArray(object)) throw new Error();
    return object;
  } catch (error) {
    if (error instanceof APIError) throw error;
    throw new APIError(400, "invalid_input", "请求内容无效。");
  } finally { reader.releaseLock(); }
}
export function operation(raw: Record<string, unknown>): Operation {
  const requestId = typeof raw.requestId === "string" ? raw.requestId.toLowerCase() : "";
  const creationId = typeof raw.creationId === "string" ? raw.creationId.toLowerCase() : "";
  if (!uuid.test(requestId) || !uuid.test(creationId)) throw new APIError(400, "invalid_input", "请求标识无效。");
  const source = raw.input as Record<string, unknown>;
  if (!source || typeof source.scene !== "string" || typeof source.mood !== "string") throw new APIError(400, "invalid_input", "请提供画面和心情。");
  const input: Input = { scene: source.scene.trim(), mood: source.mood.trim() };
  if (!input.mood || Array.from(input.mood).length > 30 || Array.from(input.scene).length > 200) throw new APIError(400, "invalid_input", "画面最多200字，心情最多30字。");
  if (source.image != null) {
    if (typeof source.image !== "string") throw new APIError(400, "invalid_input", "图片格式不正确。");
    const checked = validateImageDataUrl(source.image);
    if (!checked.ok) throw new APIError(400, "invalid_input", checked.message);
    input.image = checked.value;
  }
  if (!input.scene && !input.image) throw new APIError(400, "invalid_input", "请添加照片或填写画面。");
  const style = raw.style == null ? undefined : styles.find(value => value === raw.style);
  if (raw.style != null && !style) throw new APIError(400, "invalid_input", "未知文风。");
  const inputDigest = digest(JSON.stringify(input));
  return { requestId, creationId, input, style, inputDigest, digest: digest(JSON.stringify({ creationId, inputDigest, style })) };
}
