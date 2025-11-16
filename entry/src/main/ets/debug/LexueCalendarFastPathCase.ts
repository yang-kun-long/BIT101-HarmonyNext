// entry/src/main/ets/debug/LexueCalendarFastPathCase.ts

import { DebugCase } from './DebugCase';
import BitSsoSession from '../services/lexue/BitSsoSession';
import LexueCalendarClient from '../services/lexue/LexueCalendarClient';
import { LexueCalendarStore } from '../services/storage/LexueCalendarStore';
// ⚠️ 按你 local.secret.ts 的实际导出改名字
import { TEST_USERNAME, TEST_PASSWORD } from './local.secret';

/**
 * LexueCalendarFastPathCase
 * -------------------------
 * 用来验证：
 *  1) 第一次调用 exportCalendar 时，会生成订阅 URL，并写入缓存
 *  2) 第二次调用 exportCalendar 时，会优先走 FastPath 使用缓存订阅 URL
 *
 * 日志会打印：
 *  - 运行前缓存的订阅 URL
 *  - 第一次调用返回的 subscribeUrl + ICS 长度
 *  - 写入缓存后的订阅 URL
 *  - 第二次调用返回的 subscribeUrl + ICS 长度
 *  - 运行后缓存的订阅 URL
 *
 * 配合 LexueCalendarClient 内部的 debug 日志（FastPath 开头的那几行），
 * 可以确认快速路径是否生效。
 */
export class LexueCalendarFastPathCase extends DebugCase {
  readonly name = 'Lexue 日历订阅URL缓存 / 快速路径 测试';

  async run(): Promise<void> {
    this.logInfo('=== LexueCalendarFastPathCase START ===');

    // ---------- step 0: 检查调试账号 ----------
    if (!TEST_USERNAME || !TEST_PASSWORD) {
      this.logInfo('[step 0] 未配置 TEST_USERNAME / TEST_PASSWORD');
      this.logInfo('请在 entry/src/main/ets/debug/local.secret.ts 中配置调试账号后再运行。');
      this.logInfo('=== LexueCalendarFastPathCase ABORT ===');
      return;
    }

    const baseUrl = 'https://lexue.bit.edu.cn';
    this.logInfo('[step 0] 使用调试账号:', {
      username: TEST_USERNAME,
      password_len: String(TEST_PASSWORD.length),
      baseUrl,
    });

    const store = new LexueCalendarStore();

    // ---------- step 1: 查看 & 清理现有 URL 缓存 ----------
    const cachedBefore = await store.getCachedSubscribeUrl(TEST_USERNAME, baseUrl);
    this.logInfo('[step 1] 运行前缓存中的订阅 URL =', cachedBefore ?? null);

    // 可选：为了验证完整流程，从干净状态开始，先清掉所有日历缓存
    await store.clear();
    this.logInfo('[step 1] 已调用 LexueCalendarStore.clear()，清空 ICS/事件/URL 缓存');

    const cachedAfterClear = await store.getCachedSubscribeUrl(TEST_USERNAME, baseUrl);
    this.logInfo('[step 1] clear() 后缓存中的订阅 URL =', cachedAfterClear ?? null);

    // ---------- step 2: 创建 SSO 会话并恢复登录态 ----------
    const sso = new BitSsoSession({ debug: true });

    this.logInfo('[step 2] 调用 sso.restoreFromStorage() 尝试从持久化 cookie 恢复');
    await sso.restoreFromStorage();
    this.logInfo('[step 2] 恢复后 isFullyLoggedIn =', sso.isFullyLoggedIn());

    if (!sso.isFullyLoggedIn()) {
      this.logInfo('[step 2] 当前未完全登录，开始通过账号密码登录乐学');
      await sso.loginToLexue(TEST_USERNAME, TEST_PASSWORD);
      this.logInfo(
        '[step 2] loginToLexue 完成，isFullyLoggedIn =',
        sso.isFullyLoggedIn(),
      );
    } else {
      this.logInfo('[step 2] 已从 cookie 恢复登录态，跳过账号密码登录');
    }

    // ---------- step 3: 第一次 exportCalendar（预期：完整流程，写入缓存） ----------
    const client = new LexueCalendarClient(sso, {
      debug: true,
      username: TEST_USERNAME, // 用于 URL 缓存 key
    });

    this.logInfo(
      '[step 3] 第一次调用 exportCalendar()，预期会走完整流程并写入订阅 URL 缓存',
    );
    let subUrl1: string;
    let icsLen1: number;

    try {
      const result1 = await client.exportCalendar({
        what: 'all',
        time: 'recentupcoming',
      });
      subUrl1 = result1.subscribeUrl;
      icsLen1 = result1.icsText.length;
      this.logInfo('[step 3] 第一次 exportCalendar() 返回的订阅 URL =', subUrl1);
      this.logInfo('[step 3] 第一次 ICS 文本长度 =', icsLen1);
    } catch (e) {
      this.logInfo('[step 3] 第一次 exportCalendar() 发生错误:', String(e));
      this.logInfo('=== LexueCalendarFastPathCase ABORT ===');
      return;
    }

    const cachedAfterFirst = await store.getCachedSubscribeUrl(TEST_USERNAME, baseUrl);
    this.logInfo('[step 3] 第一次调用后缓存中的订阅 URL =', cachedAfterFirst ?? null);

    // ---------- step 4: 第二次 exportCalendar（预期：FastPath） ----------
    this.logInfo(
      '[step 4] 第二次调用 exportCalendar()，预期优先使用缓存订阅 URL（FastPath）',
    );
    let subUrl2: string;
    let icsLen2: number;

    try {
      const result2 = await client.exportCalendar({
        what: 'all',
        time: 'recentupcoming',
      });
      subUrl2 = result2.subscribeUrl;
      icsLen2 = result2.icsText.length;
      this.logInfo('[step 4] 第二次 exportCalendar() 返回的订阅 URL =', subUrl2);
      this.logInfo('[step 4] 第二次 ICS 文本长度 =', icsLen2);
    } catch (e) {
      this.logInfo('[step 4] 第二次 exportCalendar() 发生错误:', String(e));
      this.logInfo('=== LexueCalendarFastPathCase ABORT ===');
      return;
    }

    const cachedAfterSecond = await store.getCachedSubscribeUrl(TEST_USERNAME, baseUrl);
    this.logInfo('[step 4] 第二次调用后缓存中的订阅 URL =', cachedAfterSecond ?? null);

    // ---------- step 5: 简单一致性检查 ----------
    this.logInfo('[step 5] 简单一致性检查:');
    this.logInfo('  - 两次 subscribeUrl 是否相同 =', subUrl1 === subUrl2);
    this.logInfo('  - 缓存中的 URL 是否等于第二次返回的 URL =', cachedAfterSecond === subUrl2);

    this.logInfo('=== LexueCalendarFastPathCase END ===');
  }
}
