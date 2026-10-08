"use client";

import { useEffect } from "react";

/** 注册 Service Worker，满足可安装条件；开发环境也注册以便本机体验。 */
export function PwaRegister() {
  useEffect(() => {
    if (!("serviceWorker" in navigator)) return;
    void navigator.serviceWorker.register("/sw.js").catch(() => {
      /* 本机体验失败时静默，不影响主流程 */
    });
  }, []);

  return null;
}
