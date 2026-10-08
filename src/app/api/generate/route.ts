import { allStylesLengthOk } from "@/lib/length";
import { callModel } from "@/lib/modelClient";
import { buildPrompt, parseThreeStyles } from "@/lib/prompt";

type GenerateBody = {
  mood?: unknown;
  scene?: unknown;
};

type ThreeStyles = {
  鲁迅: string;
  莎士比亚: string;
  江南: string;
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
    const result = await generateWithLengthRetry({ mood, scene });
    return Response.json(result);
  } catch (error) {
    const message =
      error instanceof Error ? error.message : "生成失败,请稍后再试";
    return Response.json({ error: message }, { status: 500 });
  }
}

async function generateWithLengthRetry(input: {
  mood: string;
  scene: string;
}): Promise<ThreeStyles> {
  const firstRaw = await callModel(buildPrompt(input));
  const first = parseThreeStyles(firstRaw);
  if (allStylesLengthOk(first)) {
    return first;
  }

  console.info("字数不合格,已重写 1 次");
  const secondRaw = await callModel(
    `${buildPrompt(input)}

上一稿字数不合要求(每句须约 16–25 字,标点不计)。请重写三句,仍然只输出同样字段的 JSON。`,
  );
  return parseThreeStyles(secondRaw);
}
