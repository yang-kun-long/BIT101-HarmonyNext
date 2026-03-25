// entry/src/main/ets/debug/BitSsoLexueWebvpnCase.ts

import { DebugCase } from './DebugCase';
import { TEST_USERNAME, TEST_PASSWORD } from './local.secret';
import BitSsoSession from '../services/lexue/BitSsoSession';
import LexueCalendarClient from '../services/lexue/LexueCalendarClient';

export class BitSsoLexueWebvpnCase extends DebugCase {
  readonly name = 'Bit SSO + Lexue (via WebVPN)';

  async run(): Promise<void> {
    this.logInfo('=== BitSsoLexueWebvpnCase START ===');

    const username = TEST_USERNAME;
    const password = TEST_PASSWORD;

    const webvpnLexueBase =
      'https://webvpn.bit.edu.cn/https/77726476706e69737468656265737421fcf25989227e6a596a468ca88d1b203b';

    const sso = new BitSsoSession({
      useWebvpn: true,
      debug: true,
      webvpnLexueBase,
    });

    await sso.restoreFromStorage();
    this.logInfo('after restoreFromStorage, isFullyLoggedIn =', sso.isFullyLoggedIn());

    try {
      if (!sso.isFullyLoggedIn()) {
        this.logInfo('未完全登录，调用 loginToLexue()...');
        await sso.loginToLexue(username, password);
        this.logInfo('loginToLexue() 完成, isFullyLoggedIn =', sso.isFullyLoggedIn());
      } else {
        this.logInfo('已从持久化 cookie 恢复登录态，跳过重新登录');
      }

      const calClient = new LexueCalendarClient(sso, {
        baseUrl: webvpnLexueBase,
        debug: true,
        username,
      });

      const result = await calClient.exportCalendar({
        what: 'all',
        time: 'recentupcoming',
      });

      const icsPreview = result.icsText.replace(/\r?\n/g, '\\n').slice(0, 200);
      this.logInfo(
        'Lexue via WebVPN 导出结果:',
        'subscribeUrl =', result.subscribeUrl,
        'icsLength =', result.icsText.length,
        'icsPreview =', icsPreview,
      );

      if (!result.icsText.trimStart().startsWith('BEGIN:VCALENDAR')) {
        throw new Error('ICS 内容不是有效的 VCALENDAR 文本');
      }
    } catch (e) {
      this.logInfo('BitSsoLexueWebvpnCase 发生异常：', `${e}`);
    }

    this.logInfo('=== BitSsoLexueWebvpnCase END ===');
  }

}

export default BitSsoLexueWebvpnCase;
