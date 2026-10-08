import { imageMaxBytes } from "@/lib/config";

const ALLOWED = /^data:image\/(jpeg|jpg|png|webp);base64,/i;

export function validateImageDataUrl(image: string): {
  ok: true;
  value: string;
} | {
  ok: false;
  message: string;
} {
  const value = image.trim();
  if (!ALLOWED.test(value)) {
    return { ok: false, message: "图片格式不对,请上传 JPG、PNG 或 WEBP" };
  }

  const base64 = value.slice(value.indexOf(",") + 1);
  const bytes = Buffer.from(base64, "base64").byteLength;
  if (bytes <= 0) {
    return { ok: false, message: "图片内容是空的" };
  }
  if (bytes > imageMaxBytes) {
    return { ok: false, message: "图片太大,请先压缩后再传" };
  }

  return { ok: true, value };
}
