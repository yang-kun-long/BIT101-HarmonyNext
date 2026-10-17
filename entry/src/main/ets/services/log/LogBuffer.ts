export type DiagnosticLevel = 'DEBUG' | 'INFO' | 'WARN' | 'ERROR' | 'FATAL';

const REDACTED = '[内容含敏感字段，已省略]';

/** Omit whole credential-bearing messages, including nested JSON and multiline headers. */
export function redactLogMessage(message: string): string {
  if (message.length > 16384) return '[超长日志已省略]';
  if (/student.?id|mobile|pwd/i.test(message)) return REDACTED;
  if (/cookie|token|authorization|password|passwd|secret|credential|captcha|sesskey|execution|用户名|学号|手机号|密码|验证码|(?:\bsid\b|\busername\b|\bphone\b)|(?:sms.?code)/i.test(message)) {
    return REDACTED;
  }
  return message
    .replace(/https?:\/\/[^\s<>"']+/gi, '[链接已省略]')
    .replace(/\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b/g, '[凭据已省略]')
    .replace(/\d{6,}/g, '[号码已省略]')
    .replace(/\r?\n/g, ' | ');
}

/** Stores only redacted entries; bounded by both count and UTF-16 characters. */
export class LogBuffer {
  private entries: string[] = [];
  private size: number = 0;
  private readonly maxEntries: number;
  private readonly maxCharacters: number;

  constructor(maxEntries: number = 300, maxCharacters: number = 98304) {
    if (!Number.isInteger(maxEntries) || maxEntries < 1 || !Number.isInteger(maxCharacters) || maxCharacters < 128) {
      throw new Error('Invalid log buffer capacity');
    }
    this.maxEntries = maxEntries;
    this.maxCharacters = maxCharacters;
  }

  append(level: DiagnosticLevel, moduleName: string, message: string, now: number = Date.now()): string {
    const safeMessage = redactLogMessage(message);
    const safeModule = /^[A-Za-z][A-Za-z0-9_]{0,63}$/.test(moduleName) ? moduleName : 'UnknownModule';
    const line = (new Date(now).toISOString() + ' ' + level + ' [' + safeModule + '] ' + safeMessage)
      .slice(0, Math.min(4096, this.maxCharacters));
    this.entries.push(line);
    this.size += line.length;
    while (this.entries.length > this.maxEntries || this.size > this.maxCharacters) {
      this.size -= this.entries.shift()!.length;
    }
    return safeMessage;
  }

  snapshot(): string[] {
    return this.entries.slice();
  }
}

export const applicationLogBuffer: LogBuffer = new LogBuffer();
