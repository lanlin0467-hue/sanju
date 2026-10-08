import { limits } from "@/lib/config";

type VisitorState = {
  minuteWindowStart: number;
  minuteCount: number;
};

type DayState = {
  dayKey: string;
  count: number;
};

const visitors = new Map<string, VisitorState>();
let dayState: DayState = { dayKey: dayKeyNow(), count: 0 };

function dayKeyNow(): string {
  return new Date().toISOString().slice(0, 10);
}

export type RateLimitResult =
  | { ok: true }
  | { ok: false; message: string; status: number };

/** 仅在真正调用写手之前检查并记账。 */
export function consumeModelBudget(visitorId: string): RateLimitResult {
  const now = Date.now();
  const today = dayKeyNow();
  if (dayState.dayKey !== today) {
    dayState = { dayKey: today, count: 0 };
  }

  if (dayState.count >= limits.daily) {
    return { ok: false, message: "今天已达上限", status: 429 };
  }

  const current = visitors.get(visitorId);
  if (!current || now - current.minuteWindowStart >= 60_000) {
    visitors.set(visitorId, { minuteWindowStart: now, minuteCount: 1 });
  } else if (current.minuteCount >= limits.perMinute) {
    return { ok: false, message: "请求太频繁,请稍后再试", status: 429 };
  } else {
    current.minuteCount += 1;
    visitors.set(visitorId, current);
  }

  dayState.count += 1;
  return { ok: true };
}

/** 测试用:清空内存计数。 */
export function resetRateLimitForTests() {
  visitors.clear();
  dayState = { dayKey: dayKeyNow(), count: 0 };
}
