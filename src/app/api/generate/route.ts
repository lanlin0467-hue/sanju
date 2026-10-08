import { allStylesLengthOk, isCopyLengthOk } from "@/lib/length";
import { callModel } from "@/lib/modelClient";
import {
  buildPrompt,
  buildReplacePrompt,
  isStyleName,
  parseOneStyle,
  parseThreeStyles,
  type StyleName,
} from "@/lib/prompt";

type GenerateBody = {
  mood?: unknown;
  scene?: unknown;
  replaceStyle?: unknown;
  previous?: unknown;
};

type ThreeStyles = Record<StyleName, string>;

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

  const replaceStyle =
    typeof body.replaceStyle === "string" ? body.replaceStyle.trim() : "";

  try {
    if (replaceStyle) {
      if (!isStyleName(replaceStyle)) {
        return Response.json(
          { error: "只能换鲁迅、莎士比亚、江南其中一种" },
          { status: 400 },
        );
      }
      const previous = normalizePrevious(body.previous);
      if (previous.length === 0) {
        return Response.json(
          { error: "换句时要带上之前出现过的句子" },
          { status: 400 },
        );
      }
      const line = await replaceWithLengthRetry({
        mood,
        scene,
        style: replaceStyle,
        previous,
      });
      return Response.json({ [replaceStyle]: line });
    }

    const result = await generateWithLengthRetry({ mood, scene });
    return Response.json(result);
  } catch (error) {
    const message =
      error instanceof Error ? error.message : "生成失败,请稍后再试";
    return Response.json({ error: message }, { status: 500 });
  }
}

function normalizePrevious(value: unknown): string[] {
  if (typeof value === "string" && value.trim()) {
    return [value.trim()];
  }
  if (Array.isArray(value)) {
    return value
      .filter((item): item is string => typeof item === "string")
      .map((item) => item.trim())
      .filter(Boolean);
  }
  return [];
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

async function replaceWithLengthRetry(input: {
  mood: string;
  scene: string;
  style: StyleName;
  previous: string[];
}): Promise<string> {
  const firstRaw = await callModel(buildReplacePrompt(input));
  let line = parseOneStyle(firstRaw, input.style);

  if (!isCopyLengthOk(line) || input.previous.includes(line)) {
    console.info("字数不合格,已重写 1 次");
    const secondRaw = await callModel(
      `${buildReplacePrompt(input)}

上一稿不合格:字数须约 16–25,且不能与旧句相同。请再写一句,仍然只输出 {"${input.style}":"……"}。`,
    );
    line = parseOneStyle(secondRaw, input.style);
  }

  if (input.previous.includes(line)) {
    throw new Error("这句和上一句重复了");
  }

  return line;
}
