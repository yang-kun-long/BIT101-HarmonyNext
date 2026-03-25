import { DebugCase } from './DebugCase';
import { TEST_PASSWORD, TEST_USERNAME } from './local.secret';
import { SchoolAuthService } from '../services/school/SchoolAuthService';

const WEBVPN_LEXUE_BASE =
  'https://webvpn.bit.edu.cn/https/77726476706e69737468656265737421fcf25989227e6a596a468ca88d1b203b';

export class SchoolLexueWebvpnCase extends DebugCase {
  readonly name = 'School Lexue via WebVPN';

  async run(): Promise<void> {
    this.logInfo('=== SchoolLexueWebvpnCase START ===');

    if (!TEST_USERNAME || !TEST_PASSWORD) {
      this.logInfo('Missing TEST_USERNAME / TEST_PASSWORD in local.secret.ts');
      this.logInfo('=== SchoolLexueWebvpnCase ABORT ===');
      return;
    }

    const auth = new SchoolAuthService({ debug: true });

    try {
      const portalResult = await auth.loginWebvpnPortal(TEST_USERNAME, TEST_PASSWORD);
      this.logInfo('portal result =', portalResult);

      const lexueResult = await auth.loginWebvpnTarget(
        `${WEBVPN_LEXUE_BASE}/calendar/export.php`,
        'lexue',
        TEST_USERNAME,
        TEST_PASSWORD,
      );
      this.logInfo('lexue result =', lexueResult);
      this.logInfo('cookie names =', auth.getCookieDump().map((c) => c.name));
    } catch (e) {
      this.logError('SchoolLexueWebvpnCase failed =', e);
    }

    this.logInfo('=== SchoolLexueWebvpnCase END ===');
  }
}
