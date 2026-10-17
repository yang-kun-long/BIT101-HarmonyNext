import { common } from '@kit.AbilityKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { uniformTypeDescriptor } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import { systemShare } from '@kit.ShareKit';
import { LogExportTarget } from './LogExportService';
import { guardAsyncStorage } from '../storage/storageGuard';

export class LogShareTarget implements LogExportTarget {
  private readonly context: common.UIAbilityContext;
  private controller: systemShare.ShareController | null = null;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  async write(text: string): Promise<string> {
    // A single redacted cache file is replaced on the next export; no raw log is persisted.
    const path = this.context.cacheDir + '/bit101-diagnostics.txt';
    await guardAsyncStorage('LogShareTarget.write', async () => {
      const file = await fileIo.open(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC | fileIo.OpenMode.WRITE_ONLY);
      try {
        const bytes = new util.TextEncoder().encodeInto(text);
        const written = await fileIo.write(file.fd, bytes.buffer);
        if (written !== bytes.byteLength) throw new Error('Incomplete diagnostic log write');
      } finally {
        await fileIo.close(file.fd);
      }
    });
    return fileUri.getUriFromPath(path);
  }

  async share(uri: string): Promise<void> {
    const data = new systemShare.SharedData({
      utd: uniformTypeDescriptor.UniformDataType.PLAIN_TEXT,
      uri,
      title: 'BIT101 诊断日志',
    });
    this.controller = new systemShare.ShareController(data);
    const controller = this.controller;
    await guardAsyncStorage('LogShareTarget.share', async () => {
      await controller.show(this.context, { selectionMode: systemShare.SelectionMode.SINGLE });
    });
  }
}
