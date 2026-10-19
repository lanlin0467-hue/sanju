import { cp, rm } from "node:fs/promises";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import nextEnv from "@next/env";

const root = fileURLToPath(new URL("../", import.meta.url));
nextEnv.loadEnvConfig(root, false);
const apiBase = process.env.NEXT_PUBLIC_NATIVE_API_BASE_URL || "https://sanju-two.vercel.app";
const url = new URL(apiBase);
if (url.protocol !== "https:" || url.username || url.password || url.search || url.hash || url.pathname !== "/") {
  throw new Error("NEXT_PUBLIC_NATIVE_API_BASE_URL 必须为 HTTPS 站点根地址，例如 https://sanju-two.vercel.app");
}

await rm(new URL("../mobile/public", import.meta.url), { recursive: true, force: true });
await cp(new URL("../public", import.meta.url), new URL("../mobile/public", import.meta.url), {
  recursive: true,
  filter: (source) => !source.endsWith(".DS_Store"),
});
const result = spawnSync(process.execPath, ["node_modules/next/dist/bin/next", "build", "mobile"], {
  cwd: root,
  stdio: "inherit",
  env: { ...process.env, NEXT_PUBLIC_NATIVE_API_BASE_URL: url.origin },
});
process.exit(result.status ?? 1);
