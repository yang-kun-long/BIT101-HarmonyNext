import { DebugCase } from './DebugCase';
import { loadDebugCredentials } from './DebugCredentials';
import { AuthRepository } from '../services/auth/authRepository';
import { loginBit101AndVerifyWebvpn } from '../services/auth/bit101LoginFlow';
import { TokenStore } from '../services/storage/tokenStore';
import { TimetableRepository } from '../services/jw/timetableRepository';

export class TimetableWebvpnCase extends DebugCase {
  readonly name = 'Timetable via BIT101 WebVPN verify cookie';

  async run(): Promise<void> {
    const { TEST_USERNAME, TEST_PASSWORD } = loadDebugCredentials();
    this.logInfo('=== TimetableWebvpnCase START ===');

    const auth = new AuthRepository();
    const tokenStore = new TokenStore();

    try {
      if (!TEST_USERNAME || !TEST_PASSWORD) {
        this.fail('Missing TEST_USERNAME / TEST_PASSWORD in debug-credentials.json');
      }

      this.logInfo('run BIT101 login + webvpn verify, username =', TEST_USERNAME);
      const login = await loginBit101AndVerifyWebvpn(auth, {
        sid: TEST_USERNAME,
        password: TEST_PASSWORD,
      });
      this.logInfo('bit101 fake cookie exists =', login.fakeCookie.length > 0);
      this.logInfo('webvpn verify ok =', login.webvpn.ok, 'status =', login.webvpn.status);

      const webvpnCookie = await tokenStore.getWebvpnCookie() ?? '';
      this.logInfo('webvpnCookie exists =', webvpnCookie.length > 0);
      if (!webvpnCookie) {
        throw new Error('BIT101 WebVPN verify did not persist webvpn_cookie');
      }

      const repo = new TimetableRepository('https://bit101.flwfdd.xyz', true);
      const link = await repo.getScheduleLink();
      this.logInfo('schedule link result =', link);
    } catch (e) {
      this.logError('TimetableWebvpnCase failed =', e);
      throw e;
    }

    this.logInfo('=== TimetableWebvpnCase END ===');
  }
}
