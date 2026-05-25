// entry/src/main/ets/debug/DebugCase.ts
import { DebugLog } from './DebugLog';

type DebugLogValue = Error | Object | string | number | boolean | null | undefined;

export abstract class DebugCase {
  abstract readonly name: string;

  private logger: DebugLog = new DebugLog('DebugCase');

  abstract run(): Promise<void>;

  protected logDebug(...args: DebugLogValue[]): void {
    this.logger.info(this.formatMessage(args));
  }

  protected logInfo(...args: DebugLogValue[]): void {
    this.logger.info(this.formatMessage(args));
  }

  protected logWarn(...args: DebugLogValue[]): void {
    this.logger.warn(this.formatMessage(args));
  }

  protected logError(...args: DebugLogValue[]): void {
    this.logger.error(this.formatMessage(args));
  }

  protected logFatal(...args: DebugLogValue[]): void {
    this.logger.error(this.formatMessage(args));
  }

  protected fail(message: string): void {
    throw new Error(`[${this.name}] ${message}`);
  }

  protected assertTrue(condition: boolean, message: string): void {
    if (!condition) {
      this.fail(message);
    }
  }

  protected assertEquals(actual: string, expected: string, message: string): void {
    if (actual !== expected) {
      this.fail(`${message}. expected=${expected}, actual=${actual}`);
    }
  }

  private formatMessage(args: DebugLogValue[]): string {
    return `[${this.name}] ${args.map((arg) => this.formatValue(arg)).join(' ')}`;
  }

  private formatValue(value: DebugLogValue): string {
    if (value === null) return 'null';
    if (value === undefined) return 'undefined';
    if (value instanceof Error) return `Error: ${value.message}\nStack: ${value.stack}`;
    if (typeof value === 'object') {
      try {
        return JSON.stringify(value);
      } catch (e) {
        return String(value);
      }
    }
    return String(value);
  }
}
