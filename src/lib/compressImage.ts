import { imageMaxBytes } from "@/lib/config";

const MAX_EDGE = 1280;

export type CompressResult =
  | {
      ok: true;
      dataUrl: string;
      bytes: number;
      previewUrl: string;
    }
  | {
      ok: false;
      message: string;
    };

export async function compressImage(file: File): Promise<CompressResult> {
  if (!file.type.startsWith("image/")) {
    return { ok: false, message: "请选择图片" };
  }

  let bitmap: ImageBitmap;
  try {
    bitmap = await createImageBitmap(file);
  } catch {
    return { ok: false, message: "这张照片格式不支持,请换一张 JPG 或 PNG" };
  }

  const scale = Math.min(1, MAX_EDGE / Math.max(bitmap.width, bitmap.height));
  const width = Math.max(1, Math.round(bitmap.width * scale));
  const height = Math.max(1, Math.round(bitmap.height * scale));

  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = height;
  const ctx = canvas.getContext("2d");
  if (!ctx) {
    bitmap.close();
    return { ok: false, message: "图片处理失败,请换一张再试" };
  }
  ctx.drawImage(bitmap, 0, 0, width, height);
  bitmap.close();

  let quality = 0.9;
  let dataUrl = canvas.toDataURL("image/jpeg", quality);
  let bytes = dataUrlByteLength(dataUrl);

  while (bytes > imageMaxBytes && quality > 0.45) {
    quality -= 0.08;
    dataUrl = canvas.toDataURL("image/jpeg", quality);
    bytes = dataUrlByteLength(dataUrl);
  }

  if (bytes > imageMaxBytes) {
    // 再缩一边
    const shrink = Math.sqrt(imageMaxBytes / bytes) * 0.95;
    const w2 = Math.max(1, Math.round(width * shrink));
    const h2 = Math.max(1, Math.round(height * shrink));
    canvas.width = w2;
    canvas.height = h2;
    ctx.drawImage(
      await createImageBitmap(await (await fetch(dataUrl)).blob()),
      0,
      0,
      w2,
      h2,
    );
    dataUrl = canvas.toDataURL("image/jpeg", 0.8);
    bytes = dataUrlByteLength(dataUrl);
  }

  if (bytes > imageMaxBytes) {
    return { ok: false, message: "图片太大,压缩后仍超限,请换一张更小的" };
  }

  return {
    ok: true,
    dataUrl,
    bytes,
    previewUrl: dataUrl,
  };
}

function dataUrlByteLength(dataUrl: string): number {
  const base64 = dataUrl.split(",")[1] ?? "";
  return Math.floor((base64.length * 3) / 4);
}

export function formatKb(bytes: number): string {
  return `${Math.max(1, Math.round(bytes / 1024))} KB`;
}
