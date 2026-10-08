"use client";

import { useState } from "react";

export function HomeForm() {
  const [scene, setScene] = useState("");
  const [mood, setMood] = useState("");
  const [imageName, setImageName] = useState("");
  const [errors, setErrors] = useState<string[]>([]);

  function onPickImage(fileList: FileList | null) {
    const file = fileList?.[0];
    setImageName(file ? file.name : "");
  }

  function onGenerate() {
    const next: string[] = [];
    if (!mood.trim()) next.push("请填写心情");
    if (!scene.trim() && !imageName) next.push("请提供画面：上传图片或填写描述");
    setErrors(next);
    if (next.length > 0) return;
    // 任务 11:暂不连后厨。
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
        <label className="block space-y-2">
          <span className="text-sm font-medium">选择图片</span>
          <input
            type="file"
            accept="image/*"
            capture="environment"
            className="block w-full text-sm file:mr-3 file:rounded-md file:border-0 file:bg-neutral-900 file:px-3 file:py-2 file:text-sm file:text-white"
            onChange={(event) => onPickImage(event.target.files)}
          />
          {imageName ? (
            <span className="block text-xs text-neutral-500">已选：{imageName}</span>
          ) : null}
        </label>

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
    </main>
  );
}
