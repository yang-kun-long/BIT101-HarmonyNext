// 引用基础类（注意路径，假设类定义在同级目录的 RcpSession.ts 或 rcpSession.ts 中）
// 如果你的文件名是小写 rcpSession.ts，请保持 import { RcpSession } from './rcpSession';
import { RcpSession, RcpRequestOptions, RcpResponseData } from './rcpSession';
import { TokenStore } from '../../services/storage/tokenStore';

// 生产环境地址
export const RCP_BASE_URL = 'https://bit101.flwfdd.xyz';

const tokenStore = new TokenStore();

/**
 * 继承 RcpSession，专门用于 BIT101 业务
 * 作用：自动拦截请求，注入 fake-cookie
 */
class Bit101Client extends RcpSession {

  async fetch(
    method: 'GET' | 'POST' | 'PUT' | 'DELETE' | 'HEAD' | 'OPTIONS' | 'PATCH',
    url: string,
    options?: RcpRequestOptions & { body?: any }
  ): Promise<RcpResponseData> {

    // 1. 获取 Cookie
    const fakeCookie = await tokenStore.getFakeCookie();

    // 2. 准备 Headers
    const headers = options?.headers || {};

    // 3. 注入 (仅当有值时)
    if (fakeCookie) {
      headers['fake-cookie'] = fakeCookie;
    }

    // 4. 调用父类
    return super.fetch(method, url, { ...options, headers });
  }
}

// 导出这个专用的实例
export const bit101Session = new Bit101Client({
  baseUrl: RCP_BASE_URL,
  debug: true, // 开发时开启
  timeoutMs: 10000,
  defaultHeaders: {
    'Accept': 'application/json',
    'User-Agent': 'BIT101 HarmonyOS/1.0'
  }
});