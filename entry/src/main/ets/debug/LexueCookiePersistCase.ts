// entry/src/main/ets/debug/LexueCookiePersistCase.ts

import { DebugCase } from './DebugCase';
import BitSsoSession from '../services/lexue/BitSsoSession';
import { LexueCookieStore } from '../services/storage/LexueCookieStore';
// ⚠️ 按你自己的 local.secret.ts 实际导出改名字
import { TEST_PASSWORD, TEST_USERNAME } from './local.secret';

/**
 * LexueCookiePersistCase
 * ----------------------
 * 用来验证：
 * 1. BitSsoSession 登录乐学后，cookie 是否成功持久化到 Preferences
 * 2. 新建一个 BitSsoSession 实例，通过 restoreFromStorage() 能否直接复用登录态
 *
 * 注意：
 * - 这个 case 更偏向 inner / 旧语义验证
 * - 对 WebVPN 乐学恢复，请优先使用 WebvpnLexueRestoreCase
 *
 * 运行步骤（日志中会清晰展示）：
 *  step 0: 检查本地是否配置了调试账号
 *  step 1: 清空已有的 Lexue 持久化 cookie
 *  step 2: 第一次创建会话实例 session1，尝试从持久化恢复（预期是未登录）
 *  step 3: 用账号密码 loginToLexue()，预期 isFullyLoggedIn() === true
 *  step 4: 查看 LexueCookieStore 中是否有持久化的 cookie dump
 *  step 5: 第二次创建会话实例 session2，只调用 restoreFromStorage()
 *          预期 session2.isFullyLoggedIn() === true 且能访问乐学首页 HTTP 200
 */
export class LexueCookiePersistCase extends DebugCase {
  readonly name = 'Lexue cookie 持久化 & 恢复测试';

  async run(): Promise<void> {
    this.logInfo('=== LexueCookiePersistCase START ===');

    // ---------- step 0: 检查调试账号 ----------
    if (!TEST_USERNAME || !TEST_PASSWORD) {
      this.logInfo('[step 0] 未配置 TEST_USERNAME / TEST_PASSWORD');
      this.logInfo('请在 entry/src/main/ets/debug/local.secret.ts 中配置调试账号后再运行。');
      this.logInfo('=== LexueCookiePersistCase ABORT ===');
      return;
    }

    this.logInfo('[step 0] 使用调试账号:', {
      username: TEST_USERNAME,
      password_len: String(TEST_PASSWORD.length),
    });

    const cookieStore = new LexueCookieStore();

    // ---------- step 1: 清空已有持久化 cookie ----------
    await cookieStore.clearCookieDump();
    this.logInfo('[step 1] 已清空 Lexue 持久化 cookie dump');

    // ---------- step 2: 第一次实例，尝试从持久化恢复（预期失败/未登录） ----------
    const session1 = new BitSsoSession({ debug: true });

    await session1.restoreFromStorage();
    this.logInfo(
      '[step 2] session1.restoreFromStorage() 之后 isFullyLoggedIn =',
      session1.isFullyLoggedIn(),
    );

    // ---------- step 3: 真实登录一次 ----------
    this.logInfo('[step 3] 调用 session1.loginToLexue(...) 开始登录');
    await session1.loginToLexue(TEST_USERNAME, TEST_PASSWORD);

    this.logInfo(
      '[step 3] loginToLexue 完成，isFullyLoggedIn =',
      session1.isFullyLoggedIn(),
    );

    // 可选：简单请求一下乐学首页，验证 HTTP 状态
    try {
      const resp = await session1.getHttpClient().get('https://lexue.bit.edu.cn/', {
        autoRedirect: true,
        collectTimeInfo: false,
      });
      this.logInfo('[step 3] 访问乐学首页状态码 =', resp.statusCode);
    } catch (e) {
      this.logInfo('[step 3] 访问乐学首页时发生异常（可以忽略或检查网络）:', String(e));
    }

    // ---------- step 4: 检查持久化结果 ----------
    const dumpAfterLogin = await cookieStore.loadCookieDump();
    this.logInfo(
      '[step 4] 持久化 cookie dump 长度 =',
      dumpAfterLogin ? dumpAfterLogin.length : 0,
    );
    if (dumpAfterLogin && dumpAfterLogin.length > 0) {
      this.logInfo(
        '[step 4] 持久化 cookie 名称列表 =',
        dumpAfterLogin.map((c: any) => c.name),
      );
    } else {
      this.logInfo(
        '[step 4] 持久化 cookie 为空，这不符合预期，请检查 ensureLexueSession 中 saveCookieDump 调用。',
      );
    }

    // ---------- step 5: 新建第二个实例，仅从持久化恢复 ----------
    const session2 = new BitSsoSession({ debug: true });

    await session2.restoreFromStorage();
    this.logInfo(
      '[step 5] session2.restoreFromStorage() 之后 isFullyLoggedIn =',
      session2.isFullyLoggedIn(),
    );

    try {
      const resp2 = await session2.getHttpClient().get('https://lexue.bit.edu.cn/', {
        autoRedirect: true,
        collectTimeInfo: false,
      });
      this.logInfo('[step 5] session2 访问乐学首页状态码 =', resp2.statusCode);
    } catch (e) {
      this.logInfo(
        '[step 5] session2 访问乐学首页异常（如果 isFullyLoggedIn 为 false，说明持久化恢复失败）:',
        String(e),
      );
    }

    this.logInfo('=== LexueCookiePersistCase END ===');
  }
}
