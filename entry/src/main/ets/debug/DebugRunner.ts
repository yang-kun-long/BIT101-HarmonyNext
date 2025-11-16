// entry/src/main/ets/debug/DebugRunner.ts
import { BitSsoLexueCase } from './BitSsoLexueCase';
import { BitSsoSessionCase } from './BitSsoSessionCase';
import { DebugCase } from './DebugCase';

export enum DebugTarget {
  NONE = 'NONE',
  BIT_SSO_LEXUE = 'BIT_SSO_LEXUE',
  BIT_SSO_SESSION = 'BIT_SSO_SESSION',  // ⬅️ 新增
}

/**
 * 当前要跑哪个测试：只改这里
 */
const CURRENT_DEBUG_TARGET: DebugTarget = DebugTarget.BIT_SSO_SESSION;
// 想跑乐学日历就改成 DebugTarget.BIT_SSO_LEXUE
// 发布正式包就改成 DebugTarget.NONE（或者直接关掉 IS_DEBUG_MODE）

function createCase(target: DebugTarget): DebugCase | null {
  switch (target) {
    case DebugTarget.BIT_SSO_LEXUE:
      return new BitSsoLexueCase();
    case DebugTarget.BIT_SSO_SESSION:
      return new BitSsoSessionCase();
    case DebugTarget.NONE:
    default:
      return null;
  }
}
export async function runCurrentDebugCase(): Promise<void> {
  const testCase = createCase(CURRENT_DEBUG_TARGET);
  if (!testCase) return;
  await testCase.run();
}
