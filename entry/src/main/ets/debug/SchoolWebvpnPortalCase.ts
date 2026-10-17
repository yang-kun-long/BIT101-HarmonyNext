import { DebugCase } from './DebugCase';
import { loadDebugCredentials } from './DebugCredentials';
import { SchoolAuthService } from '../services/school/SchoolAuthService';

export class SchoolWebvpnPortalCase extends DebugCase {
  readonly name = 'School WebVPN portal login';

  async run(): Promise<void> {
    const { TEST_USERNAME, TEST_PASSWORD } = loadDebugCredentials();
    this.logInfo('=== SchoolWebvpnPortalCase START ===');

    if (!TEST_USERNAME || !TEST_PASSWORD) {
      this.logInfo('Missing TEST_USERNAME / TEST_PASSWORD in debug-credentials.json');
      this.logInfo('=== SchoolWebvpnPortalCase ABORT ===');
      this.fail('Missing TEST_USERNAME / TEST_PASSWORD in debug-credentials.json');
    }

    const auth = new SchoolAuthService({ debug: true });

    try {
      const result = await auth.loginWebvpnPortal(TEST_USERNAME, TEST_PASSWORD);
      this.logInfo('portal login result =', result);
      this.logInfo('cookie names =', auth.getCookieDump().map((c) => c.name));
    } catch (e) {
      this.logError('SchoolWebvpnPortalCase failed =', e);
      throw e;
    }

    this.logInfo('=== SchoolWebvpnPortalCase END ===');
  }
}
