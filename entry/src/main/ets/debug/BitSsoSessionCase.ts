// entry/src/main/ets/debug/BitSsoSessionCase.ts

import BitSsoSession from '../services/lexue/BitSsoSession';
import { DebugCase } from './DebugCase';
import { TEST_USERNAME, TEST_PASSWORD } from './local.secret';

export class BitSsoSessionCase extends DebugCase {
  readonly name = 'BitSsoSession basic login test';

  async run(): Promise<void> {
    const sso = new BitSsoSession({
      debug: true,   // 开启内部调试日志
      useWebvpn: false,
    });

    try {
      this.logInfo('[BitSsoSessionCase] start loginToLexue...');
      await sso.loginToLexue(TEST_USERNAME, TEST_PASSWORD);

      this.logInfo(
        '[BitSsoSessionCase] loginToLexue OK, isFullyLoggedIn =',
        sso.isFullyLoggedIn(),
      );

      // 再用已经带 cookie 的 http client 访问一个典型页面验证一下
      const client = sso.getHttpClient();
      const resp = await client.get('https://lexue.bit.edu.cn/my/', {
        autoRedirect: true,
        collectTimeInfo: false,
      });

      this.logInfo(
        '[BitSsoSessionCase] GET /my/ status =',
        resp.statusCode,
        'effectiveUrl =',
        resp.effectiveUrl,
      );

      // 打一点页面内容预览（避免全量打印）
      const preview = (resp.bodyText || '').slice(0, 300).replace(/\s+/g, ' ');
      this.logInfo('[BitSsoSessionCase] body preview =', preview);

      if (resp.statusCode !== 200) {
        throw new Error(
          `[BitSsoSessionCase] 访问乐学 /my/ 非 200，HTTP ${resp.statusCode}`,
        );
      }

      this.logInfo('[BitSsoSessionCase] BitSsoSessionCase 完成，没有发现明显错误');
    } catch (e) {
      this.logError('[BitSsoSessionCase] error =', e);
    }
  }
}
