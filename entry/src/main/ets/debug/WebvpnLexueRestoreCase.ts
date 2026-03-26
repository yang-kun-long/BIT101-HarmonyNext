import { DebugCase } from './DebugCase';
import { TEST_PASSWORD, TEST_USERNAME } from './local.secret';
import BitSsoSession from '../services/lexue/BitSsoSession';
import { LexueCookieStore } from '../services/storage/LexueCookieStore';
import { extractLexueSesskey, isRestoredLexueExportUsable } from '../services/lexue/BitSsoSessionState';

const WEBVPN_LEXUE_BASE =
  'https://webvpn.bit.edu.cn/https/77726476706e69737468656265737421fcf25989227e6a596a468ca88d1b203b';
const WEBVPN_EXPORT_URL = `${WEBVPN_LEXUE_BASE}/calendar/export.php`;

export class WebvpnLexueRestoreCase extends DebugCase {
  readonly name = 'WebVPN Lexue restore';

  async run(): Promise<void> {
    this.logInfo('=== WebvpnLexueRestoreCase START ===');

    if (!TEST_USERNAME || !TEST_PASSWORD) {
      this.logInfo('Missing TEST_USERNAME / TEST_PASSWORD in local.secret.ts');
      this.logInfo('=== WebvpnLexueRestoreCase ABORT ===');
      return;
    }

    const cookieStore = new LexueCookieStore('webvpn');
    await cookieStore.clearCookieDump();
    this.logInfo('step 1: cleared persisted webvpn lexue cookies');

    const session1 = new BitSsoSession({
      useWebvpn: true,
      debug: true,
      webvpnLexueBase: WEBVPN_LEXUE_BASE,
    });
    await session1.loginToLexue(TEST_USERNAME, TEST_PASSWORD);
    this.logInfo('step 2: loginToLexue done, isFullyLoggedIn =', session1.isFullyLoggedIn());

    const persistedDump = await cookieStore.loadCookieDump();
    this.logInfo(
      'step 3: persisted cookie names =',
      persistedDump ? persistedDump.map((c) => c.name) : [],
    );

    const session2 = new BitSsoSession({
      useWebvpn: true,
      debug: true,
      webvpnLexueBase: WEBVPN_LEXUE_BASE,
    });
    await session2.restoreFromStorage();
    this.logInfo('step 4: restoreFromStorage done, isFullyLoggedIn =', session2.isFullyLoggedIn());

    const exportResp = await session2.getHttpClient().get(WEBVPN_EXPORT_URL, {
      autoRedirect: true,
      collectTimeInfo: false,
      headers: {
        Referer: 'https://webvpn.bit.edu.cn/',
      },
    });
    const exportUsable = isRestoredLexueExportUsable(
      exportResp.statusCode,
      String(exportResp.effectiveUrl ?? ''),
      exportResp.bodyText ?? '',
    );
    const sesskey = extractLexueSesskey(exportResp.bodyText ?? '');
    this.logInfo('step 5: restore export verify =', {
      statusCode: exportResp.statusCode,
      effectiveUrl: String(exportResp.effectiveUrl ?? ''),
      exportUsable,
      sesskey,
    });

    this.logInfo('=== WebvpnLexueRestoreCase END ===');
  }
}
