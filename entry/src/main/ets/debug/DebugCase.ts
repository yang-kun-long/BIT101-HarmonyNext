import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;

export abstract class DebugCase {
  abstract readonly name: string;
  abstract run(): Promise<void>;

  protected logInfo(...args: unknown[]): void {
    hilog.info(DOMAIN, 'DebugCase', '%{public}s', args.map(a => typeof a === 'object' ? JSON.stringify(a) : String(a)).join(' '));
  }

  // ✅ 新增这个方法
  protected logWarn(...args: unknown[]): void {
    hilog.warn(DOMAIN, 'DebugCase', '%{public}s', args.map(a => typeof a === 'object' ? JSON.stringify(a) : String(a)).join(' '));
  }

  protected logError(...args: unknown[]): void {
    hilog.error(DOMAIN, 'DebugCase', '%{public}s', args.map(a => typeof a === 'object' ? JSON.stringify(a) : String(a)).join(' '));
  }
}