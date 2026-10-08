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

export class ModelCallError extends Error {
  constructor(message = "生成失败,请稍后再试") {
    super(message);
    this.name = "ModelCallError";
  }
}

export async function callModel(userContent: ModelContent): Promise<string> {
  const apiKey = process.env.MODEL_API_KEY?.trim();
  if (!apiKey) {
    throw new ModelCallError("生成失败,请稍后再试");
  }

  let response: Response;
  try {
    response = await fetch(OPENROUTER_CHAT_URL, {
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
  } catch {
    throw new ModelCallError("生成失败,请稍后再试");
  }

  let payload: {
    choices?: Array<{ message?: { content?: string } }>;
    error?: { message?: string };
  } = {};

  try {
    payload = (await response.json()) as typeof payload;
  } catch {
    throw new ModelCallError("生成失败,请稍后再试");
  }

  if (!response.ok) {
    // 不把服务商原文或密钥细节回给前端。
    throw new ModelCallError("生成失败,请稍后再试");
  }

  const content = payload.choices?.[0]?.message?.content?.trim();
  if (!content) {
    throw new ModelCallError("生成失败,请稍后再试");
  }

  return content;
}
