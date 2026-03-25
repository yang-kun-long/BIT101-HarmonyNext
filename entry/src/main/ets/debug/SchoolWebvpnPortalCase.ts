import { DebugCase } from './DebugCase';
import { TEST_PASSWORD, TEST_USERNAME } from './local.secret';
import { SchoolAuthService } from '../services/school/SchoolAuthService';

export class SchoolWebvpnPortalCase extends DebugCase {
  readonly name = 'School WebVPN portal login';

  async run(): Promise<void> {
    this.logInfo('=== SchoolWebvpnPortalCase START ===');

    if (!TEST_USERNAME || !TEST_PASSWORD) {
      this.logInfo('Missing TEST_USERNAME / TEST_PASSWORD in local.secret.ts');
      this.logInfo('=== SchoolWebvpnPortalCase ABORT ===');
      return;
    }

    const auth = new SchoolAuthService({ debug: true });

    try {
      const result = await auth.loginWebvpnPortal(TEST_USERNAME, TEST_PASSWORD);
      this.logInfo('portal login result =', result);
      this.logInfo('cookie names =', auth.getCookieDump().map((c) => c.name));
    } catch (e) {
      this.logError('SchoolWebvpnPortalCase failed =', e);
    }

    this.logInfo('=== SchoolWebvpnPortalCase END ===');
  }
}
