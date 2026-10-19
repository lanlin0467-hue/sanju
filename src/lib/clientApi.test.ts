import { beforeEach, afterEach, describe, expect, it, vi } from "vitest";
import { requestGeneration } from "./clientApi";

const native = vi.hoisted(() => ({ isNative: vi.fn(), post: vi.fn() }));
vi.mock("@capacitor/core", () => ({
  Capacitor: { isNativePlatform: native.isNative },
  CapacitorHttp: { post: native.post },
}));

const body = { mood: "开心", scene: "海边" };
const result = { 鲁迅: "一句", 莎士比亚: "二句", 江南: "三句" };

beforeEach(() => {
  native.isNative.mockReturnValue(false);
  native.post.mockReset();
});
afterEach(() => {
  vi.unstubAllGlobals();
  vi.unstubAllEnvs();
});

describe("App 与网页的生成请求", () => {
  it("网页使用同源接口，保留浏览器 Cookie", async () => {
    const fetch = vi.fn().mockResolvedValue(new Response(JSON.stringify(result)));
    vi.stubGlobal("fetch", fetch);
    expect(await requestGeneration(body)).toEqual(result);
    expect(fetch).toHaveBeenCalledWith("/api/generate", expect.objectContaining({
      method: "POST", body: JSON.stringify(body),
    }));
    expect(native.post).not.toHaveBeenCalled();
  });

  it("原生 App 从本地页面调用配置的 HTTPS 后端", async () => {
    native.isNative.mockReturnValue(true);
    vi.stubEnv("NEXT_PUBLIC_NATIVE_API_BASE_URL", "https://api.example.com/");
    native.post.mockResolvedValue({ status: 200, data: result });
    const fetch = vi.fn();
    vi.stubGlobal("fetch", fetch);
    expect(await requestGeneration(body)).toEqual(result);
    expect(native.post).toHaveBeenCalledWith(expect.objectContaining({
      url: "https://api.example.com/api/generate", data: body, readTimeout: 65_000,
    }));
    expect(native.post.mock.calls[0][0]).not.toHaveProperty("connectTimeout");
    expect(fetch).not.toHaveBeenCalled();
  });

  it("拒绝原生 App 的明文 HTTP 后端", async () => {
    native.isNative.mockReturnValue(true);
    vi.stubEnv("NEXT_PUBLIC_NATIVE_API_BASE_URL", "http://api.example.com");
    await expect(requestGeneration(body)).rejects.toThrow("检查网络");
    expect(native.post).not.toHaveBeenCalled();
  });

  it("把服务端限流信息展示给用户", async () => {
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(new Response(
      JSON.stringify({ error: "今天已达上限" }), { status: 429 },
    )));
    await expect(requestGeneration(body)).rejects.toThrow("今天已达上限");
  });

  it("网关返回 HTML 时给出可读错误", async () => {
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(new Response("<html>Bad Gateway</html>", { status: 502 })));
    await expect(requestGeneration(body)).rejects.toThrow("后厨超时或返回异常");
  });

  it("网络失败时给出重试提示", async () => {
    vi.stubGlobal("fetch", vi.fn().mockRejectedValue(new TypeError("Failed to fetch")));
    await expect(requestGeneration(body)).rejects.toThrow("检查网络");
  });
});
