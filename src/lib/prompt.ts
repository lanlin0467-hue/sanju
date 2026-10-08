export const STYLE_NAMES = ["鲁迅", "莎士比亚", "江南"] as const;
export type StyleName = (typeof STYLE_NAMES)[number];

type PromptInput = {
  mood: string;
  scene: string;
};

type ReplaceInput = PromptInput & {
  style: StyleName;
  previous: string[];
};

const STYLE_BLURBS: Record<StyleName, string> = {
  鲁迅: "冷峻、讽刺的笔调",
  莎士比亚: "朱生豪式译本的腔调",
  江南: "《龙族》作者江南的叙述味道",
};

const STYLE_SAMPLES = `腔调样例(只学味道,禁止照抄):

鲁迅:
- 街灯亮着,人们却像影子一样匆匆走过。
- 所谓热闹,不过是彼此不相干的一次凑巧。
- 他笑着说没事,眼里却盛满了不肯说的话。
- 雨打在伞上,却打不进别人的心事里去。
- 日子一天天过去,只留下没写完的句子。

莎士比亚(朱生豪式):
- 夜色替我把相思轻轻铺在潮汐之上了。
- 若时光肯回头,我愿把沉默换成一支长歌。
- 星子低垂,仿佛也为我今夜轻轻添了忧愁。
- 海风啊,请把我的名字送到她耳旁去吧。
- 月光替人间收拾了白天所有的嘈杂声。

江南(《龙族》作者):
- 路灯把影子拉得很长,像少年未说完的话。
- 世界那么大,他却只记得窗前那盏小灯。
- 雨停了,故事却还在街角等着某一个人。
- 他回头看了一眼,那一眼像压住整座城。
- 有些告别轻得像一句再普通不过的晚安。`;

/**
 * 写作说明书。提示词只放在这个文件里。
 */
export function buildPrompt({ mood, scene }: PromptInput): string {
  return `你是文案写手。根据用户给出的画面和心情,写三句中文配文。

要求:
1. 一次只输出三句,分别是三种文风:
   - 鲁迅:${STYLE_BLURBS.鲁迅}
   - 莎士比亚:${STYLE_BLURBS.莎士比亚}
   - 江南:${STYLE_BLURBS.江南}
2. 每句大约 16 到 25 个字(标点可不计),一句说完,不要分段。
3. 三句都要紧扣画面和心情,意思相关,腔调明显不同。
4. 只模仿腔调,不要照抄原著原句,也不要照抄下面的样例原句。
5. 只输出一个 JSON 对象,不要前言后语,不要 Markdown 代码块。字段名必须且只能是这三个:鲁迅、莎士比亚、江南。

${STYLE_SAMPLES}

用户输入:
画面:${scene}
心情:${mood}

若同时附上了图片,以图片内容为主,文字描述为补充。
请直接输出 JSON,例如:
{"鲁迅":"……","莎士比亚":"……","江南":"……"}`;
}

export function buildReplacePrompt({
  mood,
  scene,
  style,
  previous,
}: ReplaceInput): string {
  const avoid = previous.map((line, i) => `${i + 1}. ${line}`).join("\n");
  return `你是文案写手。根据用户给出的画面和心情,只重写一种文风的一句配文。

要求:
1. 只要写「${style}」这一句,文风是:${STYLE_BLURBS[style]}。
2. 大约 16 到 25 个字(标点可不计),一句说完。
3. 紧扣画面和心情。
4. 只模仿腔调,不要照抄原著原句,也不要照抄样例。
5. 新句子必须和下列旧句子都不同,不要只改两三个字:
${avoid || "(无)"}
6. 只输出一个 JSON 对象,不要前言后语。字段名必须且只能是「${style}」。

${STYLE_SAMPLES}

用户输入:
画面:${scene}
心情:${mood}

请直接输出 JSON,例如:
{"${style}":"……"}`;
}

export function isStyleName(value: string): value is StyleName {
  return (STYLE_NAMES as readonly string[]).includes(value);
}

export function parseThreeStyles(raw: string): Record<StyleName, string> {
  const record = parseJsonObject(raw);
  const result = {
    鲁迅: asOneLine(record["鲁迅"]),
    莎士比亚: asOneLine(record["莎士比亚"]),
    江南: asOneLine(record["江南"]),
  };

  if (!result.鲁迅 || !result.莎士比亚 || !result.江南) {
    throw new Error("三种风格没有写全");
  }

  return result;
}

export function parseOneStyle(raw: string, style: StyleName): string {
  const record = parseJsonObject(raw);
  const line = asOneLine(record[style]);
  if (!line) {
    throw new Error(`${style}这句没写出来`);
  }
  return line;
}

function parseJsonObject(raw: string): Record<string, unknown> {
  const trimmed = raw.trim();
  const fenced = trimmed.match(/```(?:json)?\s*([\s\S]*?)```/i);
  const candidate = (fenced?.[1] ?? trimmed).trim();
  const objectMatch = candidate.match(/\{[\s\S]*\}/);
  if (!objectMatch) {
    throw new Error("模型没有返回 JSON");
  }

  let data: unknown;
  try {
    data = JSON.parse(objectMatch[0]);
  } catch {
    throw new Error("模型返回的 JSON 无法解析");
  }

  if (!data || typeof data !== "object") {
    throw new Error("模型返回的不是对象");
  }

  return data as Record<string, unknown>;
}

function asOneLine(value: unknown): string {
  if (typeof value !== "string") return "";
  return value.replace(/\s+/g, " ").trim();
}
