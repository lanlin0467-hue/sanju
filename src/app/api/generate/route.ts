import { callModel } from "@/lib/modelClient";
import { buildPrompt, parseThreeStyles } from "@/lib/prompt";

type GenerateBody = {
  mood?: unknown;
  scene?: unknown;
};

export async function POST(request: Request) {
  let body: GenerateBody;

  try {
    body = (await request.json()) as GenerateBody;
  } catch {
    return Response.json({ error: "请求体不是合法的 JSON" }, { status: 400 });
  }

  if (typeof body.mood !== "string" || body.mood.trim() === "") {
    return Response.json({ error: "请提供心情 mood" }, { status: 400 });
  }

  const mood = body.mood.trim();
  const scene =
    typeof body.scene === "string" && body.scene.trim() !== ""
      ? body.scene.trim()
      : "（未提供画面描述）";

  try {
    const raw = await callModel(buildPrompt({ mood, scene }));
    const result = parseThreeStyles(raw);
    return Response.json(result);
  } catch (error) {
    const message =
      error instanceof Error ? error.message : "生成失败,请稍后再试";
    return Response.json({ error: message }, { status: 500 });
  }
}
