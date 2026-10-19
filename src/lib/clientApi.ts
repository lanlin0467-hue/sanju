import { Capacitor, CapacitorHttp } from "@capacitor/core";

/** 本地 App 资源没有 Node.js 服务；只把生成请求发给 HTTPS 后端。 */
export async function requestGeneration<T>(body: Record<string, unknown>): Promise<T> {
  let status: number;
  let data: unknown;
  try {
    if (Capacitor.isNativePlatform()) {
      const base = process.env.NEXT_PUBLIC_NATIVE_API_BASE_URL;
      if (!base || new URL(base).protocol !== "https:") {
        throw new Error("App 服务地址未配置");
      }
      const response = await CapacitorHttp.post({
        url: new URL("/api/generate", base).href,
        headers: { "Content-Type": "application/json" },
        data: body,
        responseType: "json",
        // iOS 使用 connectTimeout 优先于 readTimeout；只设一个，容纳后端的 60 秒处理窗口。
        readTimeout: 65_000,
      });
      status = response.status;
      data = response.data;
    } else {
      const response = await fetch("/api/generate", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
        signal: AbortSignal.timeout(65_000),
      });
      status = response.status;
      data = await response.text();
    }
  } catch {
    throw new Error("没连上后厨，请检查网络后重试");
  }

  if (typeof data === "string") {
    try {
      data = JSON.parse(data);
    } catch {
      throw new Error("后厨超时或返回异常，请稍后再试");
    }
  }
  if (!data || typeof data !== "object" || Array.isArray(data)) {
    throw new Error("后厨返回异常，请稍后再试");
  }
  const error = "error" in data && typeof data.error === "string" ? data.error : "";
  if (status < 200 || status >= 300 || error) {
    throw new Error(error || "生成失败，请稍后再试");
  }
  return data as T;
}
