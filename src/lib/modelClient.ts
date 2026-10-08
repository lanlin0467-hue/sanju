/**
 * 调用大模型的唯一入口。换服务商时只改这个文件。
 */

const OPENROUTER_CHAT_URL = "https://openrouter.ai/api/v1/chat/completions";
const MODEL_ID = "qwen/qwen3.7-flash";

export type ModelContent =
  | string
  | Array<
      | { type: "text"; text: string }
      | { type: "image_url"; image_url: { url: string } }
    >;

export async function callModel(userContent: ModelContent): Promise<string> {
  const apiKey = process.env.MODEL_API_KEY?.trim();
  if (!apiKey) {
    throw new Error("缺少 MODEL_API_KEY,请在 .env.local 里配置");
  }

  const response = await fetch(OPENROUTER_CHAT_URL, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: MODEL_ID,
      messages: [{ role: "user", content: userContent }],
    }),
  });

  const payload = (await response.json()) as {
    choices?: Array<{ message?: { content?: string } }>;
    error?: { message?: string };
  };

  if (!response.ok) {
    const detail = payload.error?.message ?? `HTTP ${response.status}`;
    throw new Error(`模型调用失败: ${detail}`);
  }

  const content = payload.choices?.[0]?.message?.content?.trim();
  if (!content) {
    throw new Error("模型没有返回文字");
  }

  return content;
}
