#!/usr/bin/env node
/**
 * 验收任务 19。请先用 FAKE_MODEL=1 启动开发服务,避免真的刷模型余额:
 *   FAKE_MODEL=1 npm run dev
 * 再开一个终端:
 *   node scripts/rate-limit-check.mjs
 */

const base = process.env.BASE_URL ?? "http://localhost:3000";

async function post(cookie) {
  const res = await fetch(`${base}/api/generate`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...(cookie ? { cookie } : {}),
    },
    body: JSON.stringify({ mood: "测", scene: "海边" }),
  });
  const setCookie = res.headers.getSetCookie?.() ?? [];
  const data = await res.json();
  return { status: res.status, data, setCookie };
}

function pickCookie(setCookie, previous = "") {
  const line = setCookie.find((item) => item.startsWith("sanju_vid="));
  if (!line) return previous;
  return line.split(";")[0];
}

const results = [];
let cookie = "";
for (let i = 1; i <= 5; i++) {
  const out = await post(cookie);
  cookie = pickCookie(out.setCookie, cookie);
  results.push({ i, status: out.status, error: out.data.error ?? null });
}

console.log("minute burst:", results);
const okCount = results.filter((item) => item.status === 200).length;
const blocked = results.filter((item) => item.status === 429);
if (okCount !== 3 || blocked.length < 2) {
  console.error("FAIL: expected 3 success then frequent errors");
  process.exit(1);
}

console.log("wait 61s for minute window...");
await new Promise((r) => setTimeout(r, 61_000));

const fourth = await post(cookie);
cookie = pickCookie(fourth.setCookie, cookie);
console.log("4th of day:", fourth.status, fourth.data);
if (fourth.status !== 200) {
  console.error("FAIL: expected 4th daily call to succeed after one minute");
  process.exit(1);
}

const fifth = await post(cookie);
console.log("over daily:", fifth.status, fifth.data);
if (fifth.status !== 429 || !String(fifth.data.error || "").includes("今天已达上限")) {
  console.error("FAIL: expected daily limit");
  process.exit(1);
}

console.log("TASK19_OK");
