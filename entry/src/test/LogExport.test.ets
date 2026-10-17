import { describe, it, expect } from '@ohos/hypium';
import { LogBuffer, redactLogMessage } from '../main/ets/services/log/LogBuffer';
import { LogExportService, LogExportTarget } from '../main/ets/services/log/LogExportService';
import { Logger } from '../main/ets/utils/Logger';
import { applicationLogBuffer } from '../main/ets/services/log/LogBuffer';

class MemoryLogTarget implements LogExportTarget {
  text: string = '';
  writes: number = 0;
  shares: number = 0;
  failWrite: boolean = false;
  failShare: boolean = false;

  async write(text: string): Promise<string> {
    this.writes++;
    if (this.failWrite) throw new Error('disk full');
    this.text = text;
    return 'file://diagnostics.txt';
  }

  async share(uri: string): Promise<void> {
    if (uri !== 'file://diagnostics.txt') throw new Error('unexpected uri');
    this.shares++;
    if (this.failShare) throw new Error('share unavailable');
  }
}

export default function logExportTest() {
  describe('Diagnostic log export', () => {
    it('omits complete messages containing credentials including JSON and multiline headers', 0, () => {
      const messages: string[] = [
        'Cookie: session=abc; Other=value',
        '{"nested":{"fake_cookie":"private-value"}}',
        'Authorization: Bearer private-value\nmore private content',
        'password=private-value',
        'username=student-id',
        'sid=1122334455',
        'phone=13812345678',
        'studentId=abc-private-value',
        'pwd=private-value',
        '学号: 1122334455 密码: private-value',
        'https://example.invalid/?access_token=private-value',
      ];
      messages.forEach((message: string) => {
        expect(redactLogMessage(message)).assertEqual('[内容含敏感字段，已省略]');
      });
    });

    it('removes URLs, long numbers and control-line injection before buffering', 0, () => {
      const result = redactLogMessage('failed https://example.invalid/?x=private-value at 13812345678\nnext');
      expect(result).assertEqual('failed [链接已省略] at [号码已省略] | next');
      expect(redactLogMessage('x'.repeat(16385))).assertEqual('[超长日志已省略]');
    });

    it('bounds count and size and returns a detached redacted snapshot', 0, () => {
      const buffer = new LogBuffer(2, 128);
      buffer.append('ERROR', 'Test', 'first', 0);
      buffer.append('ERROR', 'Test', 'second', 1);
      buffer.append('ERROR', 'Test', 'last', 2);
      const snapshot = buffer.snapshot();
      expect(snapshot.length).assertEqual(2);
      expect(snapshot[0].includes('second')).assertTrue();
      snapshot.pop();
      expect(buffer.snapshot().length).assertEqual(2);
      buffer.append('ERROR', 'Test', 'x'.repeat(200), 3);
      expect(buffer.snapshot().join('').length <= 128).assertTrue();
    });

    it('captures release errors through Logger without enabling verbose logs', 0, () => {
      Logger.configure(false);
      const logger = new Logger('AboutPage');
      const before = applicationLogBuffer.snapshot().length;
      logger.info('should remain disabled');
      expect(applicationLogBuffer.snapshot().length).assertEqual(before);
      logger.error('password=private-value');
      const entries = applicationLogBuffer.snapshot();
      expect(entries[entries.length - 1].includes('[内容含敏感字段，已省略]')).assertTrue();
      expect(entries[entries.length - 1].includes('private-value')).assertFalse();
    });

    it('writes a scoped UTF-8 text snapshot before opening system share', 0, async () => {
      const target = new MemoryLogTarget();
      const buffer = new LogBuffer();
      buffer.append('ERROR', 'Test', 'load failed', 0);
      buffer.append('ERROR', 'Test', 'token=private-value', 1);
      await new LogExportService(target, buffer).exportAndShare('1.0.0');
      expect(target.writes).assertEqual(1);
      expect(target.shares).assertEqual(1);
      expect(target.text.includes('本次运行')).assertTrue();
      expect(target.text.includes('load failed')).assertTrue();
      expect(target.text.includes('private-value')).assertFalse();
    });

    it('reports empty logs truthfully', 0, async () => {
      const target = new MemoryLogTarget();
      await new LogExportService(target, new LogBuffer()).exportAndShare('1.0.0');
      expect(target.text.includes('暂无可导出的日志')).assertTrue();
    });

    it('never shares a failed write and allows a later retry', 0, async () => {
      const target = new MemoryLogTarget();
      const service = new LogExportService(target, new LogBuffer());
      target.failWrite = true;
      let failed = false;
      try { await service.exportAndShare('1.0.0'); } catch (_) { failed = true; }
      expect(failed).assertTrue();
      expect(target.shares).assertEqual(0);
      target.failWrite = false;
      await service.exportAndShare('1.0.0');
      expect(target.shares).assertEqual(1);
    });

    it('propagates share failure and coalesces overlapping exports', 0, async () => {
      const target = new MemoryLogTarget();
      const service = new LogExportService(target, new LogBuffer());
      target.failShare = true;
      let failed = false;
      try { await service.exportAndShare('1.0.0'); } catch (_) { failed = true; }
      expect(failed).assertTrue();
      target.failShare = false;
      await Promise.all([service.exportAndShare('1.0.0'), service.exportAndShare('1.0.0')]);
      expect(target.writes).assertEqual(2);
      expect(target.shares).assertEqual(2);
    });
  });
}
