import { Capacitor } from "@capacitor/core";

export const isNativeApp = () => Capacitor.isNativePlatform();

export async function pickNativeImage(): Promise<File | null> {
  const { Camera, CameraResultType, CameraSource } = await import("@capacitor/camera");
  try {
    const photo = await Camera.getPhoto({
      source: CameraSource.Prompt,
      resultType: CameraResultType.DataUrl,
      quality: 85,
      width: 1280,
      height: 1280,
      correctOrientation: true,
      saveToGallery: false,
      promptLabelHeader: "选择图片",
      promptLabelPhoto: "从相册选择",
      promptLabelPicture: "拍摄照片",
      promptLabelCancel: "取消",
    });
    if (!photo.dataUrl) throw new Error("未能读取照片，请重新选择");
    const blob = await (await fetch(photo.dataUrl)).blob();
    return new File([blob], `sanju.${photo.format}`, { type: blob.type });
  } catch (error) {
    if (error instanceof Error && /cancel/i.test(error.message)) return null;
    throw error;
  }
}

export async function copyText(text: string) {
  if (isNativeApp()) {
    const { Clipboard } = await import("@capacitor/clipboard");
    await Clipboard.write({ string: text });
    return;
  }
  try {
    await navigator.clipboard.writeText(text);
  } catch {
    const area = document.createElement("textarea");
    area.value = text;
    area.setAttribute("readonly", "");
    area.style.position = "fixed";
    area.style.left = "-9999px";
    document.body.appendChild(area);
    try {
      area.select();
      if (!document.execCommand("copy")) throw new Error("复制失败，请长按句子复制");
    } finally {
      area.remove();
    }
  }
}

export async function shareText(text: string) {
  if (isNativeApp()) {
    const { Share } = await import("@capacitor/share");
    try {
      await Share.share({ title: "三句", text, dialogTitle: "分享这句" });
    } catch (error) {
      if (!(error instanceof Error) || !/cancel/i.test(error.message)) throw error;
    }
  } else if (navigator.share) {
    await navigator.share({ title: "三句", text });
  } else {
    await copyText(text);
    return "copied";
  }
}
