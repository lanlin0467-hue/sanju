import { afterEach, describe, expect, it } from "vitest";
import { limits } from "@/lib/config";
import { consumeModelBudget, resetRateLimitForTests } from "@/lib/rateLimit";

afterEach(() => {
  resetRateLimitForTests();
});

describe("consumeModelBudget", () => {
  it("allows perMinute requests then blocks", () => {
    for (let i = 0; i < limits.perMinute; i++) {
      expect(consumeModelBudget("v1").ok).toBe(true);
    }
    const blocked = consumeModelBudget("v1");
    expect(blocked.ok).toBe(false);
    if (!blocked.ok) {
      expect(blocked.message).toContain("频繁");
    }
  });

  it("blocks after daily budget", () => {
    for (let i = 0; i < limits.daily; i++) {
      // 换访问者绕过每分钟限制
      expect(consumeModelBudget(`day-${i}`).ok).toBe(true);
    }
    const blocked = consumeModelBudget("day-extra");
    expect(blocked.ok).toBe(false);
    if (!blocked.ok) {
      expect(blocked.message).toContain("今天已达上限");
    }
  });
});
