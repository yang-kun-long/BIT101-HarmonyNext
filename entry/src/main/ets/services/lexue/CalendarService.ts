// entry/src/main/ets/services/lexue/CalendarService.ts
import { Logger } from '../../utils/Logger';
import BitSsoSession from './BitSsoSession';
import LexueCalendarClient from './LexueCalendarClient';
import { parseLexueIcs, LexueCalendarEvent } from './LexueCalendarParser';
import { LexueCalendarStore } from '../storage/LexueCalendarStore';

const logger = new Logger('CalendarService');
/**
 * 配置接口
 */
interface SyncConfig {
  sso: BitSsoSession;
  username: string;
  webvpnLexueBase: string;
  isWebVpnMode?: boolean; // 如果你能从 sso 对象判断模式最好，否则从外部传入
}

/**
 * 执行一次完整的乐学日历同步：
 * 导出 ICS -> 解析 -> 存入数据库
 * @returns 同步到的事件数量
 */
export async function syncUserCalendar(config: SyncConfig): Promise<number> {
  const { sso, username, webvpnLexueBase } = config;

  // 1. 确定 Base URL
  // 如果没有显式传入 isWebVpnMode，这里假设默认逻辑（或者你可以根据 sso 的内部状态判断）
  // 在 LoginPage 中我们知道是否启用了 WebVPN，这里为了保险，
  // 简单的逻辑是：如果 sso 是 WebVPN 模式，应当使用 webvpnBase。
  // 这里的判断逻辑取决于你的 BitSsoSession 实现细节，
  // 假设我们在调用方（LoginPage）能确定 URL。

  // *注意*：为了简化，这里建议直接让调用方传入正确的 baseUrl，
  // 或者在这里进行简单的判断。此处演示根据传入的 webvpnLexueBase 存在性来决定逻辑
  // 但通常我们在 LoginPage 里已经知道是用 WebVPN 还是直连了。

  // 暂时逻辑：默认走 webvpnBase (因为 LoginPage 里定义了)，
  // 如果想支持校内直连，需要传入参数控制。
  // 这里我们复用 LoginPage 的逻辑：
  const baseUrl = webvpnLexueBase;

  logger.info('开始同步', '用户:', username, 'BaseUrl:', baseUrl);

  // 2. 初始化 Client
  const client = new LexueCalendarClient(sso, {
    // debug: true, // 建议移除或改为 false，让 Logger 接管日志开关
    baseUrl: baseUrl,
    username: username,
  });

  // 3. 导出 ICS
  // 使用 'recentupcoming' 获取近期事件，或者 'all' 获取所有
  const { icsText } = await client.exportCalendar({
    what: 'all',
    time: 'recentupcoming'
  });

  if (!icsText || icsText.length === 0) {
    logger.warn('导出的 ICS 为空');
    return 0;
  }

  // 4. 解析
  const events: LexueCalendarEvent[] = parseLexueIcs(icsText);
  logger.info('解析成功，发现', events.length, '个事件');

  // 5. 持久化存储
  const store = new LexueCalendarStore();

  // 并行保存原始文件和解析后的事件
  await Promise.all([
    store.saveRawIcs(icsText),
    store.saveEvents(events)
  ]);

  return events.length;
}