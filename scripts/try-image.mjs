#!/usr/bin/env node
import { readFileSync } from "node:fs";
import { extname, resolve } from "node:path";

const [, , photoPath, mood, scene = ""] = process.argv;

if (!photoPath || !mood) {
  console.error("用法: npm run try -- <照片路径> <心情> [可选画面描述]");
  process.exit(1);
}

const abs = resolve(photoPath);
const ext = extname(abs).toLowerCase();
const mime =
  ext === ".png"
    ? "image/png"
    : ext === ".webp"
      ? "image/webp"
      : "image/jpeg";

const base64 = readFileSync(abs).toString("base64");
const image = `data:${mime};base64,${base64}`;
const body = {
  mood,
  image,
  ...(scene ? { scene } : {}),
};

const base = process.env.BASE_URL ?? "http://localhost:3000";
const res = await fetch(`${base}/api/generate`, {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify(body),
});
const data = await res.json();
if (!res.ok) {
  console.error(data);
  process.exit(1);
}
console.log(JSON.stringify(data, null, 2));
