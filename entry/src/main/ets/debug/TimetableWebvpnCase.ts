import { DebugCase } from './DebugCase';
import { TEST_PASSWORD, TEST_USERNAME } from './local.secret';
import BitSsoSession from '../services/lexue/BitSsoSession';
import { TokenStore } from '../services/storage/tokenStore';
import { TimetableRepository } from '../services/jw/timetableRepository';

const WEBVPN_LEXUE_BASE =
  'https://webvpn.bit.edu.cn/https/77726476706e69737468656265737421fcf25989227e6a596a468ca88d1b203b';
const WEBVPN_PORTAL_URL = 'https://webvpn.bit.edu.cn/';

export class TimetableWebvpnCase extends DebugCase {
  readonly name = 'Timetable via WebVPN cookie';

  async run(): Promise<void> {
    this.logInfo('=== TimetableWebvpnCase START ===');

    const sso = new BitSsoSession({
      useWebvpn: true,
      debug: true,
      webvpnLexueBase: WEBVPN_LEXUE_BASE,
    });
    const tokenStore = new TokenStore();

    try {
      await sso.restoreFromStorage();
      this.logInfo('after restoreFromStorage, isFullyLoggedIn =', sso.isFullyLoggedIn());

      if (!sso.isFullyLoggedIn()) {
        this.logInfo('未完全登录，调用 loginToLexue()...');
        await sso.loginToLexue(TEST_USERNAME, TEST_PASSWORD);
        this.logInfo('loginToLexue() 完成, isFullyLoggedIn =', sso.isFullyLoggedIn());
      }

      const webvpnCookie = sso.getCookieHeaderFor(WEBVPN_PORTAL_URL) ?? '';
      this.logInfo('webvpnCookie exists =', webvpnCookie.length > 0);
      if (!webvpnCookie) {
        throw new Error('未从 BitSsoSession 提取到 WebVPN cookie');
      }

      await tokenStore.saveWebvpnCookie(webvpnCookie);
      this.logInfo('已将 WebVPN cookie 写入 TokenStore');

      const repo = new TimetableRepository('https://bit101.flwfdd.xyz', true);
      const link = await repo.getScheduleLink();
      this.logInfo('schedule link result =', link);
    } catch (e) {
      this.logError('TimetableWebvpnCase failed =', e);
    }

    this.logInfo('=== TimetableWebvpnCase END ===');
  }
}
