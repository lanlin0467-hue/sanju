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
  if (process.env.FAKE_MODEL === "1") {
    const text =
      typeof userContent === "string"
        ? userContent
        : userContent.find((part) => part.type === "text")?.text ?? "";
    if (text.includes("只重写一种文风") || text.includes("只要写「")) {
      const style =
        (["鲁迅", "莎士比亚", "江南"] as const).find((name) =>
          text.includes(`只要写「${name}」`),
        ) ?? "鲁迅";
      return JSON.stringify({
        [style]: `${style}换句占位写满十六个汉字以上啊`,
      });
    }
    return JSON.stringify({
      鲁迅: "鲁迅占位句子写满十六个汉字以上啊啊",
      莎士比亚: "莎士比亚占位句子写满十六个汉字以上",
      江南: "江南占位句子写满十六个汉字以上啊啊啊",
    });
  }

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
    throw new ModelCallError("生成失败,请稍后再试");
  }

  const content = payload.choices?.[0]?.message?.content?.trim();
  if (!content) {
    throw new ModelCallError("生成失败,请稍后再试");
  }

  return content;
}
