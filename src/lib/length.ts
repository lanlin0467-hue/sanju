import { copyLength } from "@/lib/config";

/** 只数汉字、字母、数字;标点与空白不计。 */
export function countCopyLength(text: string): number {
  return Array.from(text).filter((ch) => /[\u4e00-\u9fffA-Za-z0-9]/.test(ch))
    .length;
}

export function isCopyLengthOk(text: string): boolean {
  const n = countCopyLength(text);
  return n >= copyLength.min && n <= copyLength.max;
}

export function allStylesLengthOk(lines: {
  鲁迅: string;
  莎士比亚: string;
  江南: string;
}): boolean {
  return (
    isCopyLengthOk(lines.鲁迅) &&
    isCopyLengthOk(lines.莎士比亚) &&
    isCopyLengthOk(lines.江南)
  );
}
