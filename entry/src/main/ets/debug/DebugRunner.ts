// entry/src/main/ets/debug/DebugRunner.ts
import { BitSsoLexueCase } from './BitSsoLexueCase';
import { BitSsoSessionCase } from './BitSsoSessionCase';
import { ExampleDebugCase } from './ExampleDebugCase';  // ⬅️ 新增
import { DebugCase } from './DebugCase';
import { LexueCookiePersistCase } from './LexueCookiePersistCase';
import { LexueCalendarSyncCase } from './LexueCalendarSyncCase';
import { LexueCalendarFastPathCase } from './LexueCalendarFastPathCase';


export enum DebugTarget {
  NONE = 'NONE',
  BIT_SSO_LEXUE = 'BIT_SSO_LEXUE',
  BIT_SSO_SESSION = 'BIT_SSO_SESSION',
  EXAMPLE = 'EXAMPLE',  // ⬅️ 新增示范用枚举
  LEXUE_COOKIE_PERSIST = 'LEXUE_COOKIE_PERSIST',
  LEXUE_CALENDAR_SYNC = 'LEXUE_CALENDAR_SYNC',
  LEXUE_CALENDAR_FASTPATH = 'LEXUE_CALENDAR_FASTPATH',
}

/**
 * 当前要跑哪个调试用例
 * - 开发/调试时：改成你想跑的那个
 * - 发布正式包：改成 DebugTarget.NONE（或在 EntryAbility 里关掉调试入口）
 */
const CURRENT_DEBUG_TARGET: DebugTarget = DebugTarget.LEXUE_CALENDAR_FASTPATH;
// 你想测别的就改成 DebugTarget.BIT_SSO_SESSION / BIT_SSO_LEXUE 等

function createCase(target: DebugTarget): DebugCase | null {
  switch (target) {
    case DebugTarget.BIT_SSO_LEXUE:
      return new BitSsoLexueCase();
    case DebugTarget.BIT_SSO_SESSION:
      return new BitSsoSessionCase();
    case DebugTarget.EXAMPLE:
      return new ExampleDebugCase();
    case DebugTarget.LEXUE_COOKIE_PERSIST:
      return new LexueCookiePersistCase();
    case DebugTarget.LEXUE_CALENDAR_SYNC:
      return new LexueCalendarSyncCase();
    case DebugTarget.LEXUE_CALENDAR_FASTPATH:
      return new LexueCalendarFastPathCase();
    case DebugTarget.NONE:
    default:
      return null;
  }
}

export async function runCurrentDebugCase(): Promise<void> {
  const testCase = createCase(CURRENT_DEBUG_TARGET);
  if (!testCase) return;

  // 这里也可以顺便打一行日志，表明跑的是哪个 case
  console.info('[DebugRunner] Running debug case:', testCase.name);
  await testCase.run();
}
