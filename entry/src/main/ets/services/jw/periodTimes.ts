//src/main/ets/services/jw/periodTimes.ts
// 上课时间配置（默认值 + 导出函数）
export interface PeriodTime { start: string; end: string }

// 默认 13 节（按你之前的时间：可随时改）
const DEFAULT_TIMES: PeriodTime[] = [
  { start: '08:00', end: '08:45' }, // 1
  { start: '08:50', end: '09:35' }, // 2
  { start: '09:55', end: '10:40' }, // 3
  { start: '10:45', end: '11:30' }, // 4
  { start: '11:35', end: '12:20' }, // 5
  { start: '13:20', end: '14:05' }, // 6
  { start: '14:10', end: '14:55' }, // 7
  { start: '15:15', end: '16:00' }, // 8
  { start: '16:05', end: '16:50' }, // 9
  { start: '16:55', end: '17:40' }, // 10
  { start: '18:30', end: '19:15' }, // 11
  { start: '19:20', end: '20:05' }, // 12
  { start: '20:10', end: '20:55' }, // 13
];

let cachedTimes: PeriodTime[] | null = null;

// 读取（如未加载过或本地无文件，用默认）
export function getDefaultPeriodTimes(): PeriodTime[] {
  // 返回拷贝，避免外部破坏内部数组
  return DEFAULT_TIMES.map(x => ({ ...x }));
}

// 供外部直接拿一份当前配置（调用者不要修改返回数组/对象）
export function getPeriodTimesInMemory(): PeriodTime[] {
  return cachedTimes ? cachedTimes : getDefaultPeriodTimes();
}

// 内部使用：设置内存缓存（由 Store 负责持久化）
export function __setPeriodTimesInMemory(list: PeriodTime[]) {
  cachedTimes = list && list.length === 13 ? list.map(x => ({ ...x })) : getDefaultPeriodTimes();
}
