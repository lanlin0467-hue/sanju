const cases = [
  { scene: "黄昏的海边", mood: "怅然" },
  { scene: "下雨的公交站,一个人撑黑伞", mood: "有点孤单" },
  { scene: "深夜便利店的冷柜前", mood: "睡不着" },
  { scene: "春日公园里的一棵开花的树", mood: "轻松" },
  { scene: "下班地铁里挤着的肩膀", mood: "疲惫" },
  { scene: "阳台上一盆快干的绿植", mood: "愧疚" },
  { scene: "旧书桌上一盏暖黄台灯", mood: "安静" },
  { scene: "朋友圈九宫格里的旅行照", mood: "羡慕" },
  { scene: "清晨空无一人的操场", mood: "振奋" },
  { scene: "冬夜窗口外的细雪", mood: "温柔" },
];

const base = process.env.BASE_URL ?? "http://localhost:3000";

function countChars(text) {
  return Array.from(text).filter((ch) => /[\u4e00-\u9fffA-Za-z0-9]/.test(ch))
    .length;
}

const rows = [];
for (let i = 0; i < cases.length; i++) {
  const item = cases[i];
  process.stderr.write(`trial ${i + 1}/${cases.length}...\n`);
  const res = await fetch(`${base}/api/generate`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(item),
  });
  const data = await res.json();
  if (!res.ok || data.error) {
    throw new Error(`case ${i + 1} failed: ${JSON.stringify(data)}`);
  }
  rows.push({
    n: i + 1,
    scene: item.scene,
    mood: item.mood,
    鲁迅: data.鲁迅,
    莎士比亚: data.莎士比亚,
    江南: data.江南,
    lengths: {
      鲁迅: countChars(data.鲁迅),
      莎士比亚: countChars(data.莎士比亚),
      江南: countChars(data.江南),
    },
  });
}

process.stdout.write(JSON.stringify(rows, null, 2));
