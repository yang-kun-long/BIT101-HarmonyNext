import { hilog } from '@kit.PerformanceAnalysisKit';

const DEBUG_LOG_DOMAIN: number = 0x0000;
const DEBUG_LOG_ROOT_TAG: string = 'DebugIT';

export class DebugLog {
  private moduleName: string;

  constructor(moduleName: string) {
    this.moduleName = moduleName;
  }

  info(message: string): void {
    hilog.info(DEBUG_LOG_DOMAIN, this.getTag(), '%{public}s', message);
  }

  warn(message: string): void {
    hilog.warn(DEBUG_LOG_DOMAIN, this.getTag(), '%{public}s', message);
  }

  error(message: string): void {
    hilog.error(DEBUG_LOG_DOMAIN, this.getTag(), '%{public}s', message);
  }

  private getTag(): string {
    return `${DEBUG_LOG_ROOT_TAG}_${this.moduleName}`;
  }
}
