"use client";

import { useRef, useState } from "react";
import { compressImage, formatKb } from "@/lib/compressImage";

const PRIVACY_TEXT = "上传图片请注意隐私与备份，本站不留存您的图片";

type Styles = {
  鲁迅: string;
  莎士比亚: string;
  江南: string;
};

export function HomeForm() {
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [scene, setScene] = useState("");
  const [mood, setMood] = useState("");
  const [imageDataUrl, setImageDataUrl] = useState("");
  const [previewUrl, setPreviewUrl] = useState("");
  const [compressedLabel, setCompressedLabel] = useState("");
  const [imageError, setImageError] = useState("");
  const [errors, setErrors] = useState<string[]>([]);
  const [showPrivacy, setShowPrivacy] = useState(false);
  const [privacyAccepted, setPrivacyAccepted] = useState(false);
  const [loading, setLoading] = useState(false);
  const [failMessage, setFailMessage] = useState("");
  const [result, setResult] = useState<Styles | null>(null);
  const [copiedStyle, setCopiedStyle] = useState<keyof Styles | "">("");

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
    window.setTimeout(() => openFilePicker(), 0);
  }

  async function onPickImage(fileList: FileList | null) {
    const file = fileList?.[0];
    if (!file) return;

    setImageError("");
    setCompressedLabel("");
    setPreviewUrl("");
    setImageDataUrl("");

    const compressed = await compressImage(file);
    if (!compressed.ok) {
      setImageError(compressed.message);
      if (fileInputRef.current) fileInputRef.current.value = "";
      return;
    }

    setImageDataUrl(compressed.dataUrl);
    setPreviewUrl(compressed.previewUrl);
    setCompressedLabel(`压缩后 ${formatKb(compressed.bytes)}`);
  }

  async function onCopy(style: keyof Styles, line: string) {
    try {
      await navigator.clipboard.writeText(line);
    } catch {
      const area = document.createElement("textarea");
      area.value = line;
      area.setAttribute("readonly", "");
      area.style.position = "fixed";
      area.style.left = "-9999px";
      document.body.appendChild(area);
      area.select();
      document.execCommand("copy");
      document.body.removeChild(area);
    }
    setCopiedStyle(style);
    window.setTimeout(() => {
      setCopiedStyle((current) => (current === style ? "" : current));
    }, 1500);
  }

  async function onGenerate() {
    const next: string[] = [];
    if (!mood.trim()) next.push("请填写心情");
    if (!scene.trim() && !imageDataUrl) {
      next.push("请提供画面：上传图片或填写描述");
    }
    setErrors(next);
    setFailMessage("");
    if (next.length > 0) return;

    setLoading(true);
    setResult(null);
    try {
      const response = await fetch("/api/generate", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          mood: mood.trim(),
          ...(scene.trim() ? { scene: scene.trim() } : {}),
          ...(imageDataUrl ? { image: imageDataUrl } : {}),
        }),
      });
      const data = (await response.json()) as Styles & { error?: string };
      if (!response.ok || data.error) {
        setFailMessage(data.error || "生成失败,请稍后再试");
        return;
      }
      if (!data.鲁迅 || !data.莎士比亚 || !data.江南) {
        setFailMessage("生成失败,请稍后再试");
        return;
      }
      setResult({
        鲁迅: data.鲁迅,
        莎士比亚: data.莎士比亚,
        江南: data.江南,
      });
    } catch {
      setFailMessage("没连上后厨,请稍后再试");
    } finally {
      setLoading(false);
    }
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
          void onGenerate();
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
            onChange={(event) => void onPickImage(event.target.files)}
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

        {failMessage ? (
          <p className="text-sm text-red-600">{failMessage}</p>
        ) : null}

        <button
          type="submit"
          disabled={loading}
          className="w-full rounded-md bg-neutral-900 px-4 py-3 text-base font-medium text-white disabled:opacity-60"
        >
          {loading ? "正在写…" : "生成"}
        </button>
      </form>

      {loading ? (
        <p className="mt-6 text-sm text-neutral-600">正在写三种味道，稍等片刻。</p>
      ) : null}

      {result ? (
        <section className="mt-8 space-y-4">
          {(
            [
              ["鲁迅", result.鲁迅],
              ["莎士比亚", result.莎士比亚],
              ["江南", result.江南],
            ] as const
          ).map(([name, line]) => (
            <article
              key={name}
              className="rounded-md border border-neutral-200 p-4"
            >
              <div className="flex items-center justify-between gap-3">
                <h2 className="text-sm font-medium text-neutral-500">{name}</h2>
                <button
                  type="button"
                  onClick={() => void onCopy(name, line)}
                  className="text-sm text-neutral-800 underline-offset-2 hover:underline"
                >
                  {copiedStyle === name ? "已复制" : "复制"}
                </button>
              </div>
              <p className="mt-2 text-base leading-7">{line}</p>
            </article>
          ))}
        </section>
      ) : null}

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
