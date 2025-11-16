// entry/src/main/ets/debug/DebugCase.ts
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;

export abstract class DebugCase {
  abstract readonly name: string;
  abstract run(): Promise<void>;

  protected logInfo(...args: unknown[]): void {
    hilog.info(DOMAIN, 'DebugCase', '%{public}s', JSON.stringify(args));
  }

  protected logError(...args: unknown[]): void {
    hilog.error(DOMAIN, 'DebugCase', '%{public}s', JSON.stringify(args));
  }
}
