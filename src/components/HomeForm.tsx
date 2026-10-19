"use client";

import { useRef, useState } from "react";
import { compressImage, formatKb } from "@/lib/compressImage";
import { limits } from "@/lib/config";
import { requestGeneration } from "@/lib/clientApi";
import { copyText, isNativeApp, pickNativeImage, shareText } from "@/lib/native";

const PRIVACY_TEXT = "上传图片请注意隐私与备份。三句服务端不保存您的图片；生成时图片会发送给第三方 AI 服务处理，其保留规则以服务商公示为准。";

type StyleName = "鲁迅" | "莎士比亚" | "江南";

type Styles = Record<StyleName, string>;

type History = Record<StyleName, string[]>;

const EMPTY_HISTORY: History = {
  鲁迅: [],
  莎士比亚: [],
  江南: [],
};

export function HomeForm() {
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [scene, setScene] = useState("");
  const [mood, setMood] = useState("");
  const [imageDataUrl, setImageDataUrl] = useState("");
  const [previewUrl, setPreviewUrl] = useState("");
  const [compressedLabel, setCompressedLabel] = useState("");
  const [imageError, setImageError] = useState("");
  const [pickingImage, setPickingImage] = useState(false);
  const [errors, setErrors] = useState<string[]>([]);
  const [showPrivacy, setShowPrivacy] = useState(false);
  const [privacyAccepted, setPrivacyAccepted] = useState(false);
  const [loading, setLoading] = useState(false);
  const [replacingStyle, setReplacingStyle] = useState<StyleName | "">("");
  const [failMessage, setFailMessage] = useState("");
  const [result, setResult] = useState<Styles | null>(null);
  const [history, setHistory] = useState<History>(EMPTY_HISTORY);
  const [copiedStyle, setCopiedStyle] = useState<StyleName | "">("");
  const [swapsLeft, setSwapsLeft] = useState<number>(limits.swaps);

  async function openFilePicker() {
    if (!isNativeApp()) {
      fileInputRef.current?.click();
      return;
    }
    setPickingImage(true);
    setImageError("");
    try {
      const file = await pickNativeImage();
      if (file) await onPickImage(file);
    } catch {
      setImageError("无法打开照片，请在系统设置中检查相机或照片权限后重试");
    } finally {
      setPickingImage(false);
    }
  }

  function onChooseImageClick() {
    if (!privacyAccepted) {
      setShowPrivacy(true);
      return;
    }
    void openFilePicker();
  }

  function onPrivacyAccept() {
    setShowPrivacy(false);
    setPrivacyAccepted(true);
    void openFilePicker();
  }

  async function onPickImage(file: File | undefined) {
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

  async function onCopy(style: StyleName, line: string) {
    try {
      await copyText(line);
    } catch {
      setFailMessage("复制失败，请长按句子复制");
      return;
    }
    setCopiedStyle(style);
    window.setTimeout(() => {
      setCopiedStyle((current) => (current === style ? "" : current));
    }, 1500);
  }

  async function onShare(style: StyleName, line: string) {
    try {
      if ((await shareText(line)) === "copied") {
        setCopiedStyle(style);
        window.setTimeout(() => setCopiedStyle(""), 1500);
      }
    } catch (error) {
      if (error instanceof Error && error.name === "AbortError") return;
      setFailMessage("分享失败，请稍后再试，也可以复制句子");
    }
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
    setHistory(EMPTY_HISTORY);
    try {
      const data = await requestGeneration<Styles>({
        mood: mood.trim(),
        ...(scene.trim() ? { scene: scene.trim() } : {}),
        ...(imageDataUrl ? { image: imageDataUrl } : {}),
      });
      if (!data.鲁迅 || !data.莎士比亚 || !data.江南) {
        setFailMessage("生成失败,请稍后再试");
        return;
      }
      const nextResult = {
        鲁迅: data.鲁迅,
        莎士比亚: data.莎士比亚,
        江南: data.江南,
      };
      setResult(nextResult);
      setHistory({
        鲁迅: [nextResult.鲁迅],
        莎士比亚: [nextResult.莎士比亚],
        江南: [nextResult.江南],
      });
      setSwapsLeft(limits.swaps);
    } catch (error) {
      setFailMessage(error instanceof Error ? error.message : "生成失败，请稍后再试");
    } finally {
      setLoading(false);
    }
  }

  async function onReplace(style: StyleName) {
    if (!result || replacingStyle || swapsLeft <= 0) return;

    setFailMessage("");
    setReplacingStyle(style);
    const previous = history[style];
    try {
      const data = await requestGeneration<Partial<Styles>>({
        mood: mood.trim(),
        scene: scene.trim() || "（见上传图片）",
        replaceStyle: style,
        previous,
      });
      if (!data[style]) {
        setFailMessage("换句失败,请稍后再试");
        return;
      }
      const line = data[style] as string;
      setResult({ ...result, [style]: line });
      setHistory({
        ...history,
        [style]: [...previous, line],
      });
      setSwapsLeft((n) => Math.max(0, n - 1));
    } catch (error) {
      setFailMessage(error instanceof Error ? error.message : "换句失败，请稍后再试");
    } finally {
      setReplacingStyle("");
    }
  }

  const styles = (
    [
      ["鲁迅", result?.鲁迅],
      ["莎士比亚", result?.莎士比亚],
      ["江南", result?.江南],
    ] as const
  ).filter((item): item is [StyleName, string] => Boolean(item[1]));

  return (
    <main className="mx-auto min-h-dvh w-full max-w-md px-4 pb-[max(7rem,calc(env(safe-area-inset-bottom)+2rem))] pt-[max(2rem,calc(env(safe-area-inset-top)+1rem))]">
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
            className="hidden"
            onChange={(event) => void onPickImage(event.target.files?.[0])}
          />
          <button
            type="button"
            onClick={onChooseImageClick}
            disabled={pickingImage}
            className="min-h-12 w-full rounded-md border border-neutral-300 px-4 py-3 text-left text-base"
          >
            {pickingImage ? "正在读取照片…" : "选择图片"}
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
            className="w-full resize-none rounded-md border border-neutral-300 px-3 py-3 text-base outline-none focus:border-neutral-800"
          />
        </label>

        <label className="block space-y-2">
          <span className="text-sm font-medium">心情</span>
          <input
            type="text"
            value={mood}
            onChange={(event) => setMood(event.target.value)}
            placeholder="比如：怅然、开心、有点孤单"
            className="min-h-12 w-full rounded-md border border-neutral-300 px-3 py-3 text-base outline-none focus:border-neutral-800"
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
          disabled={loading || Boolean(replacingStyle)}
          className="min-h-12 w-full rounded-md bg-neutral-900 px-4 py-3 text-base font-medium text-white disabled:opacity-60"
        >
          {loading ? "正在写…" : "生成"}
        </button>
        <p className="text-xs leading-5 text-neutral-500">
          生成时，画面、心情及所选图片将发送至第三方 AI 服务处理。请勿提交敏感个人信息。
        </p>
      </form>

      {loading ? (
        <p className="mt-6 text-sm text-neutral-600">正在写三种味道，稍等片刻。</p>
      ) : null}

      {result ? (
        <section className="mt-8 space-y-4">
          <p className="text-sm text-neutral-600">还能换 {swapsLeft} 次</p>
          {swapsLeft === 0 ? (
            <p className="text-sm text-neutral-500">
              这三次已经换完。改画面或心情后重新点「生成」，次数才会恢复。
            </p>
          ) : null}

          {styles.map(([name, line]) => {
            const busy = replacingStyle === name;
            const replaceDisabled =
              swapsLeft <= 0 || Boolean(replacingStyle) || loading;
            return (
              <article
                key={name}
                className="rounded-md border border-neutral-200 p-4"
              >
                <div className="flex items-center justify-between gap-3">
                  <h2 className="text-sm font-medium text-neutral-500">
                    {name}
                  </h2>
                  <div className="flex items-center gap-3">
                    <button
                      type="button"
                      onClick={() => void onShare(name, line)}
                      className="min-h-11 px-1 text-sm text-neutral-800"
                    >
                      分享
                    </button>
                    <button
                      type="button"
                      onClick={() => void onCopy(name, line)}
                      className="min-h-11 px-1 text-sm text-neutral-800 underline-offset-2 hover:underline"
                    >
                      {copiedStyle === name ? "已复制" : "复制"}
                    </button>
                    <button
                      type="button"
                      disabled={replaceDisabled}
                      onClick={() => void onReplace(name)}
                      className="min-h-11 px-1 text-sm text-neutral-800 underline-offset-2 hover:underline disabled:text-neutral-400 disabled:no-underline"
                    >
                      {busy ? "正在写…" : "换这句"}
                    </button>
                  </div>
                </div>
                <p className="mt-2 text-base leading-7">
                  {busy ? "正在重写这一句…" : line}
                </p>
              </article>
            );
          })}
        </section>
      ) : null}

      {showPrivacy ? (
        <div role="dialog" aria-modal="true" aria-label="图片隐私说明" className="fixed inset-0 z-50 flex items-end bg-black/40 p-4 pb-[max(1rem,env(safe-area-inset-bottom))] sm:items-center sm:justify-center">
          <div className="w-full max-w-md rounded-lg bg-white p-5 shadow-lg">
            <p className="text-base leading-7 text-neutral-900">{PRIVACY_TEXT}</p>
            <button
              type="button"
              onClick={onPrivacyAccept}
              className="mt-5 min-h-12 w-full rounded-md bg-neutral-900 px-4 py-3 text-base font-medium text-white"
            >
              知道了
            </button>
            <button type="button" onClick={() => setShowPrivacy(false)} className="mt-2 min-h-11 w-full text-sm text-neutral-600">
              暂不上传
            </button>
          </div>
        </div>
      ) : null}
    </main>
  );
}
