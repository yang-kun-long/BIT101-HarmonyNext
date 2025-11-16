// entry/src/main/ets/debug/BitSsoLexueWebvpnCase.ts

import { DebugCase } from './DebugCase';
import { TEST_USERNAME, TEST_PASSWORD } from './local.secret';
import BitSsoSession from '../services/lexue/BitSsoSession';

export class BitSsoLexueWebvpnCase extends DebugCase {
  readonly name = 'Bit SSO + Lexue (via WebVPN)';

  async run(): Promise<void> {
    this.logInfo('=== BitSsoLexueWebvpnCase START ===');

    const username = TEST_USERNAME;
    const password = TEST_PASSWORD;

    // TODO: 这里换成你自己抓到的「乐学在 WebVPN 下的入口」
    const webvpnLexueBase =
      'https://webvpn.bit.edu.cn/https/77726476706e69737468656265737421fcf25989227e6a596a468ca88d1b203b'

    const sso = new BitSsoSession({
      useWebvpn: true,
      debug: true,
      webvpnLexueBase,
    });

    // 尝试从持久化存储恢复 cookie（沿用你现有逻辑）
    await sso.restoreFromStorage();
    this.logInfo('after restoreFromStorage, isFullyLoggedIn =', sso.isFullyLoggedIn());

    if (!sso.isFullyLoggedIn()) {
      this.logInfo('未完全登录，调用 loginToLexue()...');
      await sso.loginToLexue(username, password);
      this.logInfo('loginToLexue() 完成, isFullyLoggedIn =', sso.isFullyLoggedIn());
    } else {
      this.logInfo('已从持久化 cookie 恢复登录态，跳过重新登录');
    }

    const client = sso.getHttpClient();
    const resp = await client.get(`${webvpnLexueBase}/`, {
      autoRedirect: true,
      collectTimeInfo: false,
    });

    this.logInfo(
      'Lexue via WebVPN 最终响应:',
      'HTTP', resp.statusCode,
      'effectiveUrl =', resp.effectiveUrl,
    );

    this.logInfo('=== BitSsoLexueWebvpnCase END ===');
  }
}

export default BitSsoLexueWebvpnCase;
