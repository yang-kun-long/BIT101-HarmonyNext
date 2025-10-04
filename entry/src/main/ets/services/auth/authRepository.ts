// entry/src/main/ets/services/auth/authRepository.ts
import { HttpClient, ApiError } from '../../core/network/httpClient';
import { encryptPassword } from './encryptPassword';
import { TokenStore } from '../storage/tokenStore';
import { md5HexLower } from './encryptPassword';

interface Bit101LoginResp { fake_cookie?: string }


export interface InitVerifyResp {
  captcha?: string;   // 可为空串
  cookie: string;     // REQUIRED
  salt: string;       // REQUIRED
  execution: string;  // REQUIRED
}
export interface VerifyPayload {
  sid: string;
  salt: string;
  password: string;   // encrypted Base64
  execution: string;
  cookie: string;
  captcha: string;    // 可为空串
}
export interface VerifyResult {
  ok: boolean;
  status: number;
  body: Record<string, unknown> | string;
  setCookie?: string;
}

export interface AuthRepositoryOptions {
  baseUrl?: string; // 默认生产地址
  userAgent?: string;
}

export class AuthRepository {
  private http: HttpClient;
  private tokenStore: TokenStore;

  constructor(opts?: AuthRepositoryOptions) {
    const baseUrl = (opts?.baseUrl ?? 'https://bit101.flwfdd.xyz').replace(/\/$/, '');
    const headers: Record<string, string> = {
      'Accept-Language': 'zh-CN,zh;q=0.9',
      'User-Agent': opts?.userAgent ?? 'BIT101 HarmonyOS/1.0 (ArkTS)',
      'Origin': baseUrl,
      'Referer': baseUrl + '/',
    };
    this.http = new HttpClient(baseUrl, headers);
    this.tokenStore = new TokenStore();
  }
  // 登录 BIT101 侧（md5 小写）
  async loginBit101(params: { sid: string; password: string }): Promise<string> {
    const sid = params.sid?.trim();
    const pwdMd5 = md5HexLower(params.password || '');
    if (!sid || !pwdMd5) throw new Error('sid & password required');

    const res = await this.http.request<Bit101LoginResp>({
      url: '/user/login',
      method: 'POST',
      json: { sid, password: pwdMd5 }
    });

    // 兼容 {fake_cookie:""} 或 {data:{fake_cookie:""}}
    const body: any = typeof res.data === 'object' ? res.data : JSON.parse(res.text);
    const fake = body?.fake_cookie ?? body?.data?.fake_cookie;
    if (!fake) throw new Error('BIT101 login: fake_cookie missing');
    await this.tokenStore.saveFakeCookie(String(fake));
    return String(fake);
  }


  // Step 1
  async initVerify(sid: string): Promise<InitVerifyResp> {
    if (!sid) throw new Error('sid required');
    const res = await this.http.request<{ salt: string; execution: string; captcha?: string; cookie?: string } | string>({
      url: '/user/webvpn_verify_init',
      method: 'POST',
      json: { sid },
    });

    if (typeof res.data !== 'object' || res.data === null) {
      throw new ApiError('initVerify: invalid json', res.status, res.text);
    }

    const obj: any = res.data;
    const salt = String(obj.salt || '');
    const execution = String(obj.execution || '');
    const captcha = obj.captcha !== undefined && obj.captcha !== null ? String(obj.captcha) : '';
    let cookie = obj.cookie ? String(obj.cookie) : '';

    // 从响应头兜底
    const sc = (res.headers['set-cookie'] || res.headers['Set-Cookie']) as any;
    if (!cookie && sc) cookie = Array.isArray(sc) ? sc.join('; ') : String(sc);

    if (!salt || !execution || !cookie) {
      throw new ApiError('initVerify: missing fields', res.status, res.text);
    }

    return { captcha, cookie, salt, execution };
  }

  // Step 2
  async verify(payload: VerifyPayload): Promise<VerifyResult> {
    const headers: Record<string, string> = { Cookie: payload.cookie };

    const res = await this.http.request<any>({
      url: '/user/webvpn_verify',
      method: 'POST',
      headers,
      json: {
        sid: payload.sid,
        salt: payload.salt,
        password: payload.password,
        execution: payload.execution,
        cookie: payload.cookie,
        captcha: payload.captcha ?? '',
      }
    });

    // 解析 set-cookie
    const sc = (res.headers['set-cookie'] || res.headers['Set-Cookie']) as any;
    let setCookieStr = '';
    if (Array.isArray(sc)) setCookieStr = sc.join('; ');
    else if (sc) setCookieStr = String(sc);

    return {
      ok: res.status >= 200 && res.status < 300,
      status: res.status,
      body: (typeof res.data === 'undefined') ? res.text : (res.data as any),
      setCookie: setCookieStr || undefined
    };
  }

  // 封装的高阶登录：init → encrypt → verify → 保存会话（若后端返回 token）
  async loginViaWebVpnVerify(params: { sid: string; password: string; captcha?: string }): Promise<VerifyResult> {
    const { sid, password } = params;
    if (!sid || !password) throw new Error('sid & password required');

    const init = await this.initVerify(sid);
    const encrypted = encryptPassword(password, init.salt);
    const ret = await this.verify({
      sid,
      salt: init.salt,
      password: encrypted,
      execution: init.execution,
      cookie: init.cookie,
      captcha: params.captcha ?? init.captcha ?? ''
    });

    // ☆ 只有 verify ok 才把 init.cookie 作为生效 cookie 落盘
    if (ret.ok && init.cookie) {
      await this.tokenStore.saveWebvpnCookie(init.cookie);
    }

    // （可选）保存业务 token/user
    try {
      const body = ret.body as any;
      const token = body?.token || body?.data?.token;
      const user = body?.user || body?.data?.user;
      if (token) await this.tokenStore.saveToken(token);
      if (user) await this.tokenStore.saveUserInfo(user);
    } catch {}

    return ret;
  }


  async getAccessToken(): Promise<string | null> {
    return this.tokenStore.getToken();
  }

  async logout(): Promise<void> {
    await this.tokenStore.clear();
  }
  // 一键登录两个系统：先 BIT101，再 WebVPN（或反过来也可以）
  // 返回对象里带上两枚 cookie 以便 UI/调试
  async loginBoth(params: { sid: string; password: string; captcha?: string }):
    Promise<{ bit101FakeCookie: string; webvpnCookie: string; webvpn: VerifyResult }> {

    const fake = await this.loginBit101(params);          // 1) BIT101 fake_cookie
    const webvpn = await this.loginViaWebVpnVerify(params); // 2) WebVPN verify

    // 从 Store 里拿最终写入的 cookie（确保 verify 成功后才有意义）
    const webvpnCookie = (await this.tokenStore.getWebvpnCookie()) || '';

    return { bit101FakeCookie: fake, webvpnCookie, webvpn };
  }
  async getSessionCookies(): Promise<{ fakeCookie: string | null; webvpnCookie: string | null }> {
    return {
      fakeCookie: await this.tokenStore.getFakeCookie(),
      webvpnCookie: await this.tokenStore.getWebvpnCookie()
    };
  }


}
