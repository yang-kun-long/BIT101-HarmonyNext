// entry/src/main/ets/debug/LexueCalendarSyncCase.ts

import { DebugCase } from './DebugCase';
import BitSsoSession from '../services/lexue/BitSsoSession';
import LexueCalendarClient from '../services/lexue/LexueCalendarClient';
import { parseLexueIcs, LexueCalendarEvent } from '../services/lexue/LexueCalendarParser';
import { LexueCalendarStore } from '../services/storage/LexueCalendarStore';
import { TEST_USERNAME, TEST_PASSWORD } from './local.secret';
import { createBitSsoSessionAuto, BitSsoLoginMode } from '../services/lexue/BitSsoAuto';
/**
 * 开关：当前调试用例是走校内直连，还是走 WebVPN
 * - false: 直连 https://lexue.bit.edu.cn
 * - true : 通过 WebVPN 访问乐学
 */
const USE_WEBVPN = true;

/**
 * WebVPN 下乐学的 BASE，对齐 Python lexue_calendar.py 里的 BASE
 *   BASE = "https://webvpn.bit.edu.cn/https/7772...fcf25989..."
 *
 * 注意：不要在末尾加 /moodle/，保持和 Python 完全一致即可。
 */
const WEBVPN_LEXUE_BASE =
  'https://webvpn.bit.edu.cn/https/77726476706e69737468656265737421fcf25989227e6a596a468ca88d1b203b';

/**
 * LexueCalendarSyncCase
 * ----------------------
 * 用来验证整条链路：
 *  1) 使用 BitSsoSession 登录乐学（支持从 cookie 持久化恢复）
 *  2) 使用 LexueCalendarClient 导出 ICS
 *  3) 使用 parseLexueIcs 解析为事件数组
 *  4) 使用 LexueCalendarStore 持久化 ICS + 解析后的事件
 *  5) 再从 LexueCalendarStore 读回来，确认数据一致
 */
export class LexueCalendarSyncCase extends DebugCase {
  readonly name = 'Lexue 日历导出 + 解析 + 持久化 测试';

  async run(): Promise<void> {
    this.logInfo('=== LexueCalendarSyncCase START ===');
    this.logInfo('[mode] USE_WEBVPN =', USE_WEBVPN);

    // ---------- step 0: 检查调试账号 ----------
    if (!TEST_USERNAME || !TEST_PASSWORD) {
      this.logInfo('[step 0] 未配置 TEST_USERNAME / TEST_PASSWORD');
      this.logInfo('请在 entry/src/main/ets/debug/local.secret.ts 中配置调试账号后再运行。');
      this.logInfo('=== LexueCalendarSyncCase ABORT ===');
      return;
    }

    this.logInfo('[step 0] 使用调试账号:', {
      username: TEST_USERNAME,
      password_len: String(TEST_PASSWORD.length),
    });

    const calendarStore = new LexueCalendarStore();

    // ---------- step 1: 创建 SSO 会话并尝试从持久化 cookie 恢复 ----------
    const { mode, sso } = await createBitSsoSessionAuto({
      debug: true,
      webvpnLexueBase: WEBVPN_LEXUE_BASE,
    });

    this.logInfo('[step 0] 自动选择的登录模式 =', mode); // 'inner' 或 'webvpn'

    this.logInfo('[step 1] 调用 sso.restoreFromStorage() 尝试从持久化 cookie 恢复');
    await sso.restoreFromStorage();
    this.logInfo(
      '[step 1] 恢复后 isFullyLoggedIn =',
      sso.isFullyLoggedIn(),
    );

    // ---------- step 2: 如果还没完全登录，就走一次账号密码登录 ----------
    if (!sso.isFullyLoggedIn()) {
      this.logInfo('[step 2] 当前未完全登录，开始通过账号密码登录乐学');
      await sso.loginToLexue(TEST_USERNAME, TEST_PASSWORD);
      this.logInfo(
        '[step 2] loginToLexue 完成，isFullyLoggedIn =',
        sso.isFullyLoggedIn(),
      );
    } else {
      this.logInfo('[step 2] 已从持久化 cookie 恢复登录态，跳过账号密码登录');
    }

    // ---------- step 3: 使用 LexueCalendarClient 导出 ICS ----------
    // baseUrl：
    // - 校内直连: https://lexue.bit.edu.cn
    // - WebVPN   : WEBVPN_LEXUE_BASE（对齐 Python 的 BASE）
    const baseUrl = USE_WEBVPN
      ? WEBVPN_LEXUE_BASE
      : 'https://lexue.bit.edu.cn';

    const client = new LexueCalendarClient(sso, {
      debug: true,
      baseUrl,
      username: TEST_USERNAME, // ✅ 让订阅 URL 缓存按 (username, baseUrl) 生效
    });

    this.logInfo('[step 3] 调用 client.exportCalendar(...) 导出 ICS');
    let subscribeUrl: string;
    let icsText: string;

    try {
      const result = await client.exportCalendar({
        what: 'all',
        time: 'recentupcoming', // 或 'all'，根据你需求
      });
      subscribeUrl = result.subscribeUrl;
      icsText = result.icsText;
    } catch (e) {
      this.logInfo('[step 3] exportCalendar 发生错误:', String(e));
      this.logInfo('=== LexueCalendarSyncCase ABORT ===');
      return;
    }

    this.logInfo('[step 3] 订阅 URL =', subscribeUrl);
    this.logInfo('[step 3] ICS 文本长度 =', icsText.length);

    // ---------- step 4: 解析 ICS 为事件数组 ----------
    this.logInfo('[step 4] 开始解析 ICS 文本 -> LexueCalendarEvent[]');

    let events: LexueCalendarEvent[] = [];
    try {
      events = parseLexueIcs(icsText);
    } catch (e) {
      this.logInfo('[step 4] parseLexueIcs 解析失败:', String(e));
      this.logInfo('=== LexueCalendarSyncCase ABORT ===');
      return;
    }

    this.logInfo('[step 4] 解析完成，事件数量 =', events.length);

    if (events.length > 0) {
      const sorted = [...events].sort((a, b) => a.startTime - b.startTime);
      const previewCount = Math.min(sorted.length, 5);
      const preview = sorted.slice(0, previewCount).map((ev) => ({
        uid: ev.uid,
        title: ev.title,
        start: new Date(ev.startTime).toISOString(),
        end: ev.endTime ? new Date(ev.endTime).toISOString() : undefined,
        location: ev.location,
      }));
      this.logInfo('[step 4] 前几条事件预览 =', preview);
    } else {
      this.logInfo('[step 4] 没有解析到任何事件，检查 ICS 是否为空/课程是否为空');
    }

    // ---------- step 5: 持久化 ICS + 事件 ----------
    this.logInfo('[step 5] 开始通过 LexueCalendarStore 持久化 ICS + 事件');
    try {
      await calendarStore.saveRawIcs(icsText);
      await calendarStore.saveEvents(events);
      this.logInfo('[step 5] 持久化完成');
    } catch (e) {
      this.logInfo('[step 5] 持久化过程中发生错误:', String(e));
      this.logInfo('=== LexueCalendarSyncCase ABORT ===');
      return;
    }

    // ---------- step 6: 从 LexueCalendarStore 再读回来，确认一致性 ----------
    this.logInfo('[step 6] 从 LexueCalendarStore 读取持久化数据进行验证');

    const storedIcs = await calendarStore.getRawIcs();
    const storedEvents = await calendarStore.getEvents();
    const lastSyncTs = await calendarStore.getLastSyncTimestamp();

    this.logInfo('[step 6] 读取回来的 ICS 长度 =', storedIcs ? storedIcs.length : null);
    this.logInfo('[step 6] 读取回来的事件数量 =', storedEvents.length);
    this.logInfo(
      '[step 6] 上次同步时间 =',
      lastSyncTs ? new Date(lastSyncTs).toISOString() : null,
    );

    if (storedEvents.length > 0) {
      const previewStored = storedEvents
        .slice(0, Math.min(storedEvents.length, 3))
        .map((ev) => ({
          uid: ev.uid,
          title: ev.title,
          start: new Date(ev.startTime).toISOString(),
        }));
      this.logInfo('[step 6] 读取回来的前几条事件预览 =', previewStored);
    }

    this.logInfo('=== LexueCalendarSyncCase END ===');
  }
}
