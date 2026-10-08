import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "三句",
  description: "脚手架已就绪",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="zh-CN">
      <body>{children}</body>
    </html>
  );
}
