import { DebugCase } from './DebugCase';
import { TEST_PASSWORD, TEST_USERNAME } from './local.secret';
import SimpleCookieJar from '../core/network/cookieJar';
import RcpSession from '../core/network/rcpSession';
import { SchoolAuthService } from '../services/school/SchoolAuthService';
import { extractLexueSesskey, isRestoredLexueExportUsable } from '../services/lexue/BitSsoSessionState';

const WEBVPN_LEXUE_BASE =
  'https://webvpn.bit.edu.cn/https/77726476706e69737468656265737421fcf25989227e6a596a468ca88d1b203b';
const WEBVPN_EXPORT_URL = `${WEBVPN_LEXUE_BASE}/calendar/export.php`;

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
        WEBVPN_EXPORT_URL,
        'lexue',
        TEST_USERNAME,
        TEST_PASSWORD,
      );
      this.logInfo('lexue result =', lexueResult);
      const dump = auth.getCookieDump();
      this.logInfo('cookie names =', dump.map((c) => c.name));

      const jar = new SimpleCookieJar();
      jar.restoreFromDump(dump);
      const client = new RcpSession({
        debug: true,
        timeoutMs: 15000,
        defaultHeaders: {
          'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36',
        },
        cookieJar: jar,
      });
      const exportResp = await client.get(WEBVPN_EXPORT_URL, {
        autoRedirect: true,
        collectTimeInfo: false,
        headers: {
          Referer: 'https://webvpn.bit.edu.cn/',
        },
      });
      const sesskey = extractLexueSesskey(exportResp.bodyText ?? '');
      const hasMoodleSession = dump.some((c) => c.name === 'MoodleSession' && !!c.value);
      const exportUsable = isRestoredLexueExportUsable(
        exportResp.statusCode,
        String(exportResp.effectiveUrl ?? ''),
        exportResp.bodyText ?? '',
      );
      this.logInfo('export verify =', {
        statusCode: exportResp.statusCode,
        effectiveUrl: String(exportResp.effectiveUrl ?? ''),
        exportUsable,
        hasMoodleSession,
        sesskey,
      });
      if (!exportUsable) {
        const preview = (exportResp.bodyText ?? '').replace(/\s+/g, ' ').slice(0, 300);
        this.logInfo('export preview =', preview);
      }
    } catch (e) {
      this.logError('SchoolLexueWebvpnCase failed =', e);
    }

    this.logInfo('=== SchoolLexueWebvpnCase END ===');
  }
}
