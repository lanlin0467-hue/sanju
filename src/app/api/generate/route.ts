import { NextResponse } from "next/server";
import { validateImageDataUrl } from "@/lib/image";
import { allStylesLengthOk, isCopyLengthOk } from "@/lib/length";
import { callModel, type ModelContent } from "@/lib/modelClient";
import {
  buildPrompt,
  buildReplacePrompt,
  isStyleName,
  parseOneStyle,
  parseThreeStyles,
  type StyleName,
} from "@/lib/prompt";
import { consumeModelBudget } from "@/lib/rateLimit";

/** OpenRouter 偶发 30s+;Vercel 默认过短会断成「没连上后厨」。 */
export const maxDuration = 60;

type GenerateBody = {
  mood?: unknown;
  scene?: unknown;
  image?: unknown;
  replaceStyle?: unknown;
  previous?: unknown;
};

type ThreeStyles = Record<StyleName, string>;

const VISITOR_COOKIE = "sanju_vid";

export async function POST(request: Request) {
  let body: GenerateBody;

  try {
    body = (await request.json()) as GenerateBody;
  } catch {
    return NextResponse.json({ error: "请求体不是合法的 JSON" }, { status: 400 });
  }

  if (typeof body.mood !== "string" || body.mood.trim() === "") {
    return NextResponse.json({ error: "请提供心情" }, { status: 400 });
  }

  const mood = body.mood.trim();
  const sceneText =
    typeof body.scene === "string" ? body.scene.trim() : "";

  let image: string | undefined;
  if (typeof body.image === "string" && body.image.trim() !== "") {
    const checked = validateImageDataUrl(body.image);
    if (!checked.ok) {
      return NextResponse.json({ error: checked.message }, { status: 400 });
    }
    image = checked.value;
    const approxKb = Math.max(
      1,
      Math.round(((image.split(",")[1]?.length ?? 0) * 3) / 4 / 1024),
    );
    console.info(`收到图片 ${approxKb} KB`);
  }

  if (!sceneText && !image) {
    return NextResponse.json(
      { error: "请提供画面(图片或描述)" },
      { status: 400 },
    );
  }

  const scene = sceneText || "（见上传图片）";
  const replaceStyle =
    typeof body.replaceStyle === "string" ? body.replaceStyle.trim() : "";
  let previous: string[] = [];

  if (replaceStyle) {
    if (!isStyleName(replaceStyle)) {
      return NextResponse.json(
        { error: "只能换鲁迅、莎士比亚、江南其中一种" },
        { status: 400 },
      );
    }
    previous = normalizePrevious(body.previous);
    if (previous.length === 0) {
      return NextResponse.json(
        { error: "换句时要带上之前出现过的句子" },
        { status: 400 },
      );
    }
  }

  const visitorId = readVisitorId(request) ?? crypto.randomUUID();
  const budget = consumeModelBudget(visitorId);
  if (!budget.ok) {
    return withVisitorCookie(
      NextResponse.json({ error: budget.message }, { status: budget.status }),
      visitorId,
    );
  }

  try {
    if (replaceStyle && isStyleName(replaceStyle)) {
      const line = await replaceWithLengthRetry({
        mood,
        scene: sceneText || "（画面理解以文字为准）",
        style: replaceStyle,
        previous,
      });
      return withVisitorCookie(
        NextResponse.json({ [replaceStyle]: line }),
        visitorId,
      );
    }

    const result = await generateWithLengthRetry({ mood, scene, image });
    return withVisitorCookie(NextResponse.json(result), visitorId);
  } catch (error) {
    const message =
      error instanceof Error ? error.message : "生成失败,请稍后再试";
    const status = message.startsWith("生成失败") ? 502 : 500;
    return withVisitorCookie(
      NextResponse.json({ error: message }, { status }),
      visitorId,
    );
  }
}

function readVisitorId(request: Request): string | undefined {
  const raw = request.headers.get("cookie") ?? "";
  const match = raw.match(new RegExp(`(?:^|;\\s*)${VISITOR_COOKIE}=([^;]+)`));
  return match?.[1] ? decodeURIComponent(match[1]) : undefined;
}

function withVisitorCookie(response: NextResponse, visitorId: string) {
  response.cookies.set(VISITOR_COOKIE, visitorId, {
    httpOnly: true,
    sameSite: "lax",
    path: "/",
    maxAge: 60 * 60 * 24 * 365,
  });
  return response;
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

function toContent(prompt: string, image?: string): ModelContent {
  if (!image) return prompt;
  return [
    { type: "text", text: prompt },
    { type: "image_url", image_url: { url: image } },
  ];
}

async function generateWithLengthRetry(input: {
  mood: string;
  scene: string;
  image?: string;
}): Promise<ThreeStyles> {
  const prompt = buildPrompt({ mood: input.mood, scene: input.scene });
  const firstRaw = await callModel(toContent(prompt, input.image));
  const first = parseThreeStyles(firstRaw);
  if (allStylesLengthOk(first)) {
    return first;
  }

  console.info("字数不合格,已重写 1 次");
  const secondRaw = await callModel(
    toContent(
      `${prompt}

上一稿字数不合要求(每句须约 16–25 字,标点不计)。请重写三句,仍然只输出同样字段的 JSON。`,
      input.image,
    ),
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
