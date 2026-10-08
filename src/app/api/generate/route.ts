import { callModel } from "@/lib/modelClient";

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

  const prompt = `画面：${scene}\n心情：${mood}\n请用一句话简短回应。`;

  try {
    const reply = await callModel(prompt);
    return Response.json({ reply });
  } catch (error) {
    const message =
      error instanceof Error ? error.message : "生成失败,请稍后再试";
    return Response.json({ error: message }, { status: 500 });
  }
}
