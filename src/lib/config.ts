/** 以后要调的数字只改这里。这里没有业务逻辑。 */

export const copyLength = {
  min: 16,
  max: 25,
} as const;

/** 压缩后的图片上限,任务清单里的初始值。 */
export const imageMaxBytes = 500 * 1024;

export const limits = {
  /** 同一访问者每分钟最多几次调用写手。 */
  perMinute: 3,
  /** 全站每天最多几次调用写手。 */
  daily: 4,
  /** 三种风格合计还能换几次。 */
  swaps: 3,
} as const;
