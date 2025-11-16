// entry/src/main/ets/debug/BitSsoLexueCase.ts
import BitSsoSession from '../services/lexue/BitSsoSession';
import LexueCalendarClient from '../services/lexue/LexueCalendarClient';
import { DebugCase } from './DebugCase';
import { TEST_USERNAME, TEST_PASSWORD } from './local.secret';

export class BitSsoLexueCase extends DebugCase {
  readonly name = 'BitSso + Lexue calendar test';

  async run(): Promise<void> {
    const sso = new BitSsoSession({ debug: true });

    try {
      this.logInfo('[BitSsoLexueCase] start login...');
      await sso.loginToLexue(TEST_USERNAME, TEST_PASSWORD);
      this.logInfo(
        '[BitSsoLexueCase] loginToLexue OK, isFullyLoggedIn =',
        sso.isFullyLoggedIn(),
      );

      const calClient = new LexueCalendarClient(sso, { debug: true });

      const result = await calClient.exportCalendar({
        what: 'all',
        time: 'recentupcoming',
      });

      this.logInfo('[BitSsoLexueCase] calendar subscribeUrl =', result.subscribeUrl);
      this.logInfo('[BitSsoLexueCase] ICS length =', result.icsText.length);
      this.logInfo(
        '[BitSsoLexueCase] ICS preview =',
        result.icsText.replace(/\r?\n/g, '\\n').slice(0, 200),
      );
    } catch (e) {
      this.logError('[BitSsoLexueCase] error =', e);
    }
  }
}
