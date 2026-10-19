import type { Metadata, Viewport } from "next";
import type { ReactNode } from "react";
import "../../src/app/globals.css";

export const metadata: Metadata = {
  title: "三句",
  description: "把画面和心情写成三种味道，挑一句就用。",
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
  themeColor: "#ffffff",
  colorScheme: "light",
};

export default function MobileLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="zh-CN">
      <body>{children}</body>
    </html>
  );
}
