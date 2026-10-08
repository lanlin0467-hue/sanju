"use client";

import { useEffect, useState } from "react";

type BeforeInstallPromptEvent = Event & {
  prompt: () => Promise<void>;
  userChoice: Promise<{ outcome: "accepted" | "dismissed" }>;
};

function isStandalone() {
  if (typeof window === "undefined") return false;
  const media = window.matchMedia("(display-mode: standalone)").matches;
  const ios = "standalone" in navigator && Boolean((navigator as Navigator & { standalone?: boolean }).standalone);
  return media || ios;
}

function isIosSafari() {
  if (typeof navigator === "undefined") return false;
  const ua = navigator.userAgent;
  const iOS = /iPad|iPhone|iPod/.test(ua) || (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1);
  const webkit = /WebKit/.test(ua);
  const notOther = !/CriOS|FxiOS|EdgiOS|OPiOS|DuckDuckGo/.test(ua);
  return iOS && webkit && notOther;
}

/** 引导把网页装到主屏幕；已是独立窗口时不显示。 */
export function InstallHint() {
  const [hidden, setHidden] = useState(true);
  const [deferred, setDeferred] = useState<BeforeInstallPromptEvent | null>(null);
  const [ios, setIos] = useState(false);

  useEffect(() => {
    if (isStandalone()) {
      setHidden(true);
      return;
    }
    const dismissed = sessionStorage.getItem("sanju_install_dismissed") === "1";
    if (dismissed) {
      setHidden(true);
      return;
    }

    setIos(isIosSafari());
    setHidden(false);

    function onBeforeInstall(event: Event) {
      event.preventDefault();
      setDeferred(event as BeforeInstallPromptEvent);
    }
    window.addEventListener("beforeinstallprompt", onBeforeInstall);
    return () => window.removeEventListener("beforeinstallprompt", onBeforeInstall);
  }, []);

  if (hidden) return null;

  async function onInstallClick() {
    if (!deferred) return;
    await deferred.prompt();
    await deferred.userChoice;
    setDeferred(null);
    setHidden(true);
  }

  function onDismiss() {
    sessionStorage.setItem("sanju_install_dismissed", "1");
    setHidden(true);
  }

  return (
    <aside className="mt-6 rounded-md border border-neutral-200 bg-neutral-50 px-3 py-3 text-sm leading-6 text-neutral-700">
      <p className="font-medium text-neutral-900">装到手机主屏幕</p>
      {deferred ? (
        <p className="mt-1">点下面按钮，可像 App 一样全屏打开（仍走本机网页服务，不会上传商店）。</p>
      ) : ios ? (
        <p className="mt-1">
          用 Safari 打开本页 → 点底部分享 →「添加到主屏幕」。微信里请用右上角「在 Safari 打开」。
        </p>
      ) : (
        <p className="mt-1">
          Chrome / Edge：菜单里选「安装应用」或「添加到主屏幕」。本机局域网请用手机浏览器打开电脑 IP
          地址（不要用微信内置浏览器测安装）。
        </p>
      )}
      <div className="mt-3 flex flex-wrap gap-2">
        {deferred ? (
          <button
            type="button"
            onClick={() => void onInstallClick()}
            className="min-h-11 rounded-md bg-neutral-900 px-3 text-sm font-medium text-white"
          >
            安装三句
          </button>
        ) : null}
        <button
          type="button"
          onClick={onDismiss}
          className="min-h-11 rounded-md px-3 text-sm text-neutral-600 underline-offset-2 hover:underline"
        >
          知道了
        </button>
      </div>
    </aside>
  );
}
