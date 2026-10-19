import type { NextConfig } from "next";
import path from "node:path";

// 只导出界面；动态 API 仍由根目录的 Next.js 项目部署。
const config: NextConfig = {
  output: "export",
  trailingSlash: true,
  env: {
    NEXT_PUBLIC_NATIVE_API_BASE_URL:
      process.env.NEXT_PUBLIC_NATIVE_API_BASE_URL || "https://sanju-two.vercel.app",
  },
  turbopack: {
    root: path.resolve(__dirname, ".."),
    rules: {
      "*.css": {
        loaders: ["@tailwindcss/turbopack"],
        as: "*.css",
      },
    },
  },
};

export default config;
