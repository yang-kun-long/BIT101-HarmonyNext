// File: entry/src/main/ets/services/Bit101Auth.ts
// HarmonyOS NEXT (ArkTS) — BIT101 login (minimal & stable)
import { Logger } from '../utils/Logger';
import http from '@ohos.net.http';

// 显式导入 UMD 模块；兼容 default / CryptoJS / 直接顶层导出 / 全局挂载
import * as CryptoJSPkg from '../vendor/crypto-js-4.2.0.js';
const logger = new Logger('Bit101Auth');
// ---------- helpers ----------
function mustGetCryptoJS(): any {
  // 依次尝试：
  // 1) 模块对象下的 CryptoJS
  // 2) 模块对象的 default
  // 3) 模块对象本身（你的日志表明成员是直接顶层导出的）
  // 4) UMD 副作用挂到 globalThis.CryptoJS
  // 任一满足且具备 enc.Base64 / algo.AES / mode.ECB / pad.Pkcs7 即可
  const candidates: any[] = [
    // @ts-ignore
    (CryptoJSPkg as any)?.CryptoJS,
    // @ts-ignore
    (CryptoJSPkg as any)?.default,
    // @ts-ignore
    (CryptoJSPkg as any),
    // @ts-ignore
    (globalThis as any)?.CryptoJS,
  ];

  for (const c of candidates) {
    if (!c) continue;
    try {
      if (c.enc?.Base64 && c.algo?.AES && c.mode?.ECB && c.pad?.Pkcs7) {
        return c;
      }
    } catch (_) { /* ignore */ }
  }

  // 打印模块键值帮助定位
  // @ts-ignore
  logger.debug('CryptoJS module keys:', Object.keys(CryptoJSPkg || {}));
  throw new Error('CryptoJS not loaded. Check vendor path and import (../vendor/crypto-js-4.2.0.js)');
}

function redact(str: string, keepStart: number, keepEnd: number): string {
  if (!str) return '';
  const s = String(str);
  if (s.length <= keepStart + keepEnd) return '*'.repeat(s.length);
  return s.slice(0, keepStart) + '***' + s.slice(-keepEnd);
}



// ---------- types ----------
export interface InitVerifyResp {
  captcha?: string; // "" allowed
  cookie: string;   // REQUIRED
  salt: string;     // REQUIRED
  execution: string;// REQUIRED
}

export interface VerifyPayload {
  sid: string;
  salt: string;
  password: string;   // encrypted (Base64)
  execution: string;
  cookie: string;     // REQUIRED
  captcha: string;    // "" allowed
}

export interface VerifyResult {
  ok: boolean;
  code: number;
  body: Record<string, unknown> | string;
  setCookie?: string;
}

// ---------- crypto ----------
export function encryptPassword(password: string, saltBase64: string): string {
  if (!password || !saltBase64) throw new Error('encryptPassword: password and saltBase64 are required');
  const CryptoJS = mustGetCryptoJS();
  const key = CryptoJS.enc.Base64.parse(saltBase64);
  const encryptor = CryptoJS.algo.AES.createEncryptor(key, { mode: CryptoJS.mode.ECB, padding: CryptoJS.pad.Pkcs7 });
  const ctWA = encryptor.finalize(CryptoJS.enc.Utf8.parse(password));
  return CryptoJS.enc.Base64.stringify(ctWA);
}

// ---------- client ----------
export class Bit101Client {
  private baseUrl: string;
  private readonly JSON_HEADERS: Record<string, string>;

  constructor(baseUrl: string = 'https://bit101.flwfdd.xyz') {
    this.baseUrl = baseUrl.replace(/\/$/, '');
    this.JSON_HEADERS = {
      'Content-Type': 'application/json;charset=UTF-8',
      'Accept': 'application/json, text/plain, */*',
      'Accept-Language': 'zh-CN,zh;q=0.9',
      'User-Agent': 'Mozilla/5.0 (HarmonyOS; ArkTS) AppleWebKit/537.36 (KHTML, like Gecko) Mobile Safari/537.36',
      'Origin': this.baseUrl,
      'Referer': this.baseUrl + '/',
    };
  }

  // Step 1: /user/webvpn_verify_init
  async initVerify(sid: string, timeoutMs: number = 15000): Promise<InitVerifyResp> {
    if (!sid) throw new Error('sid is required');

    const url = this.baseUrl + '/user/webvpn_verify_init';
    logger.debug('initVerify request', { url, sid: redact(sid, 4, 2), timeoutMs });

    const client = http.createHttp();
    try {
      const res = await client.request(url, {
        method: http.RequestMethod.POST,
        header: this.JSON_HEADERS,
        extraData: JSON.stringify({ sid }),
        connectTimeout: timeoutMs,
        readTimeout: timeoutMs
      });

      const code: number = res.responseCode;
      const text: string = (res.result as string) || '';
      const headers: any = res.header || {};

      logger.debug('initVerify FULL BODY:', text);
      logger.debug('initVerify HEADERS:', headers);

      if (code < 200 || code >= 300) throw new Error('initVerify HTTP ' + code + ': ' + text);

      let data: any;
      try { data = JSON.parse(text); } catch { throw new Error('initVerify: response is not valid JSON'); }

      const salt: string = data && data.salt ? String(data.salt) : '';
      const execution: string = data && data.execution ? String(data.execution) : '';
      const captcha: string = (data && data.captcha !== undefined && data.captcha !== null) ? String(data.captcha) : '';
      let cookieStr: string = data && data.cookie ? String(data.cookie) : '';

      // Fallback to Set-Cookie if body.cookie missing
      const setCookieAny: any = headers['Set-Cookie'] ? headers['Set-Cookie'] : headers['set-cookie'];
      logger.debug('initVerify Set-Cookie:', setCookieAny || '(none)');
      if (!cookieStr && setCookieAny) {
        if (Array.isArray(setCookieAny)) cookieStr = setCookieAny.join('; ');
        else cookieStr = String(setCookieAny);
      }

      if (!salt || !execution || !cookieStr) {
        throw new Error('initVerify: missing required fields (salt/execution/cookie)');
      }

      return { captcha, cookie: cookieStr, salt, execution };
    } finally {
      client.destroy();
    }
  }

  // Step 2: /user/webvpn_verify
  async verify(payload: VerifyPayload, timeoutMs: number = 15000): Promise<VerifyResult> {
    const required: Array<keyof VerifyPayload> = ['sid', 'salt', 'password', 'execution', 'cookie'];
    for (let i = 0; i < required.length; i++) {
      const k = required[i];
      const v: any = (payload as any)[k];
      if (v === undefined || v === null || String(v).length === 0) throw new Error('verify: missing/empty required field ' + String(k));
    }
    if (payload.captcha === undefined || payload.captcha === null) payload.captcha = '';

    const url = this.baseUrl + '/user/webvpn_verify';
    logger.debug('verify request meta', {
      url,
      keys: Object.keys(payload),
      sid: redact(payload.sid, 4, 2),
      saltLen: payload.salt.length,
      pwdLen: payload.password.length,
      exec: redact(payload.execution, 6, 4),
      cookie: redact(payload.cookie, 8, 6),
      captcha: payload.captcha ? redact(payload.captcha, 2, 2) : '(empty)',
      timeoutMs
    });

    const client = http.createHttp();
    try {
      const headers: Record<string, string> = { ...this.JSON_HEADERS, Cookie: payload.cookie };

      const bodyObj: any = {
        sid: payload.sid,
        salt: payload.salt,
        password: payload.password,
        execution: payload.execution,
        cookie: payload.cookie,
        captcha: payload.captcha
      };

      const res = await client.request(url, {
        method: http.RequestMethod.POST,
        header: headers,
        extraData: JSON.stringify(bodyObj),
        connectTimeout: timeoutMs,
        readTimeout: timeoutMs
      });

      const code: number = res.responseCode;
      const raw: string = (res.result as string) || '';
      const respHeaders: any = res.header || {};
      logger.debug('verify FULL BODY:', raw);
      logger.debug('verify HEADERS:', respHeaders);

      let parsed: any = raw;
      try { parsed = JSON.parse(raw); } catch {}

      const scAny: any = respHeaders['Set-Cookie'] ? respHeaders['Set-Cookie'] : respHeaders['set-cookie'];
      let setCookieStr = '';
      if (Array.isArray(scAny)) setCookieStr = scAny.join('; ');
      else if (scAny) setCookieStr = String(scAny);

      return { ok: code >= 200 && code < 300, code, body: parsed, setCookie: setCookieStr || undefined };
    } finally {
      client.destroy();
    }
  }

  // High-level: full flow
  async loginViaWebVpnVerify(params: { sid: string; password: string; captcha?: string }, timeoutMs: number = 15000): Promise<VerifyResult> {
    const sid = params.sid;
    const password = params.password;
    if (!sid || !password) throw new Error('sid and password are required');

    const init = await this.initVerify(sid, timeoutMs);
    const captcha = params.captcha ? params.captcha : (init.captcha ? init.captcha : '');
    const encrypted = encryptPassword(password, init.salt);

    const verifyPayload: VerifyPayload = {
      sid,
      salt: init.salt,
      password: encrypted,
      execution: init.execution,
      cookie: init.cookie,
      captcha
    };

    return this.verify(verifyPayload, timeoutMs);
  }
}

// ---------- optional self test ----------
export function __selfTest(): boolean {
  try {
    const out = encryptPassword('password123', 'MDEyMzQ1Njc4OWFiY2RlZg==');
    const reference = 'hHSUMW7WbI0rQ3UPQpOe0Q==';
    const pass = out === reference;
    logger.debug('__selfTest result:', { pass, out });
    return pass;
  } catch (e) {
    logger.error('__selfTest exception', e);
    return false;
  }
}
