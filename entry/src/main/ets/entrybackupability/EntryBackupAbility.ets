import { Logger } from '../utils/Logger';
import { BackupExtensionAbility, BundleVersion } from '@kit.CoreFileKit';

export default class EntryBackupAbility extends BackupExtensionAbility {
  private logger: Logger = new Logger('EntryBackupAbility');
  async onBackup() {
    this.logger.info('onBackup ok');
    await Promise.resolve();
  }

  async onRestore(bundleVersion: BundleVersion) {
    this.logger.info('onRestore ok');
    await Promise.resolve();
  }
}
