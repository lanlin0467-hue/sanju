import { describe, expect, it } from "vitest";
import { countCopyLength, isCopyLengthOk } from "@/lib/length";

describe("countCopyLength", () => {
  it("counts 20 Chinese characters without punctuation", () => {
    const text = "黄昏把海面染成了一片旧金色而风也慢了下来";
    expect(countCopyLength(text)).toBe(20);
    expect(isCopyLengthOk(text)).toBe(true);
  });

  it("ignores punctuation and still counts 24 characters", () => {
    const text = "黄昏把海面染成了一片旧金色,而风也慢了下来,我想起你。";
    expect(countCopyLength(text)).toBe(24);
    expect(isCopyLengthOk(text)).toBe(true);
  });

  it("rejects a single character", () => {
    expect(countCopyLength("好")).toBe(1);
    expect(isCopyLengthOk("好")).toBe(false);
  });

  it("rejects a doubled 20-character line (40)", () => {
    const once = "黄昏把海面染成了一片旧金色而风也慢了下来";
    const twice = once + once;
    expect(countCopyLength(twice)).toBe(40);
    expect(isCopyLengthOk(twice)).toBe(false);
  });
});
