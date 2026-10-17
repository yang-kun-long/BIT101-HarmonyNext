import { applicationLogBuffer, LogBuffer, redactLogMessage } from './LogBuffer';

export interface LogExportTarget {
  write(text: string): Promise<string>;
  share(uri: string): Promise<void>;
}

export class LogExportService {
  private readonly buffer: LogBuffer;
  private readonly target: LogExportTarget;
  private inFlight: Promise<void> | null = null;

  constructor(target: LogExportTarget, buffer: LogBuffer = applicationLogBuffer) {
    this.target = target;
    this.buffer = buffer;
  }

  exportAndShare(versionName: string): Promise<void> {
    if (this.inFlight !== null) return this.inFlight;
    const operation = this.performExport(versionName);
    this.inFlight = operation;
    return operation.finally(() => {
      if (this.inFlight === operation) this.inFlight = null;
    });
  }

  private async performExport(versionName: string): Promise<void> {
    const entries = this.buffer.snapshot();
    const lines = [
      'BIT101 HarmonyOS 诊断日志',
      '版本: ' + redactLogMessage(versionName),
      '范围: 本次运行中 Logger 记录的最近日志；release 仅包含 error/fatal。',
      '凭据字段、链接及长号码已省略；不包含历史运行或系统日志。',
      '',
    ];
    if (entries.length === 0) lines.push('本次运行暂无可导出的日志。');
    else entries.forEach((entry: string) => lines.push(entry));
    const uri = await this.target.write(lines.join('\n') + '\n');
    await this.target.share(uri);
  }
}
