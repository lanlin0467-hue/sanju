"use client";

import { useRef, useState } from "react";
import { compressImage, formatKb } from "@/lib/compressImage";

const PRIVACY_TEXT = "上传图片请注意隐私与备份，本站不留存您的图片";

export function HomeForm() {
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [scene, setScene] = useState("");
  const [mood, setMood] = useState("");
  const [hasImage, setHasImage] = useState(false);
  const [previewUrl, setPreviewUrl] = useState("");
  const [compressedLabel, setCompressedLabel] = useState("");
  const [imageError, setImageError] = useState("");
  const [errors, setErrors] = useState<string[]>([]);
  const [showPrivacy, setShowPrivacy] = useState(false);
  const [privacyAccepted, setPrivacyAccepted] = useState(false);

  function openFilePicker() {
    fileInputRef.current?.click();
  }

  function onChooseImageClick() {
    if (!privacyAccepted) {
      setShowPrivacy(true);
      return;
    }
    openFilePicker();
  }

  function onPrivacyAccept() {
    setShowPrivacy(false);
    setPrivacyAccepted(true);
    // 等弹层关掉后再打开系统选图,避免被拦截。
    window.setTimeout(() => openFilePicker(), 0);
  }

  async function onPickImage(fileList: FileList | null) {
    const file = fileList?.[0];
    if (!file) return;

    setImageError("");
    setCompressedLabel("");
    setPreviewUrl("");
    setHasImage(false);

    const result = await compressImage(file);
    if (!result.ok) {
      setImageError(result.message);
      if (fileInputRef.current) fileInputRef.current.value = "";
      return;
    }

    setHasImage(true);
    setPreviewUrl(result.previewUrl);
    setCompressedLabel(`压缩后 ${formatKb(result.bytes)}`);
  }

  function onGenerate() {
    const next: string[] = [];
    if (!mood.trim()) next.push("请填写心情");
    if (!scene.trim() && !hasImage) {
      next.push("请提供画面：上传图片或填写描述");
    }
    setErrors(next);
    if (next.length > 0) return;
    // 任务 12:仍不连后厨。
  }

  return (
    <main className="mx-auto min-h-dvh w-full max-w-md px-4 py-8">
      <h1 className="text-3xl font-semibold tracking-tight">三句</h1>
      <p className="mt-2 text-sm leading-6 text-neutral-600">
        把画面和心情写成三种味道，挑一句就用。
      </p>

      <form
        className="mt-8 space-y-5"
        onSubmit={(event) => {
          event.preventDefault();
          onGenerate();
        }}
      >
        <div className="space-y-2">
          <span className="text-sm font-medium">选择图片</span>
          <input
            ref={fileInputRef}
            type="file"
            accept="image/*"
            capture="environment"
            className="hidden"
            onChange={(event) => onPickImage(event.target.files)}
          />
          <button
            type="button"
            onClick={onChooseImageClick}
            className="w-full rounded-md border border-neutral-300 px-4 py-3 text-left text-base"
          >
            选择图片
          </button>
          {compressedLabel ? (
            <p className="text-xs text-neutral-500">{compressedLabel}</p>
          ) : null}
          {previewUrl ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img
              src={previewUrl}
              alt="压缩后的预览"
              className="mt-2 max-h-56 w-full rounded-md object-cover"
            />
          ) : null}
          {imageError ? (
            <p className="text-sm text-red-600">{imageError}</p>
          ) : null}
        </div>

        <label className="block space-y-2">
          <span className="text-sm font-medium">画面描述</span>
          <textarea
            value={scene}
            onChange={(event) => setScene(event.target.value)}
            rows={3}
            placeholder="也可以只写文字，比如：黄昏的海边"
            className="w-full resize-none rounded-md border border-neutral-300 px-3 py-2 text-base outline-none focus:border-neutral-800"
          />
        </label>

        <label className="block space-y-2">
          <span className="text-sm font-medium">心情</span>
          <input
            type="text"
            value={mood}
            onChange={(event) => setMood(event.target.value)}
            placeholder="比如：怅然、开心、有点孤单"
            className="w-full rounded-md border border-neutral-300 px-3 py-2 text-base outline-none focus:border-neutral-800"
          />
        </label>

        {errors.length > 0 ? (
          <ul className="space-y-1 text-sm text-red-600">
            {errors.map((item) => (
              <li key={item}>{item}</li>
            ))}
          </ul>
        ) : null}

        <button
          type="submit"
          className="w-full rounded-md bg-neutral-900 px-4 py-3 text-base font-medium text-white"
        >
          生成
        </button>
      </form>

      {showPrivacy ? (
        <div className="fixed inset-0 z-50 flex items-end bg-black/40 p-4 sm:items-center sm:justify-center">
          <div className="w-full max-w-md rounded-lg bg-white p-5 shadow-lg">
            <p className="text-base leading-7 text-neutral-900">{PRIVACY_TEXT}</p>
            <button
              type="button"
              onClick={onPrivacyAccept}
              className="mt-5 w-full rounded-md bg-neutral-900 px-4 py-3 text-base font-medium text-white"
            >
              知道了
            </button>
          </div>
        </div>
      ) : null}
    </main>
  );
}
