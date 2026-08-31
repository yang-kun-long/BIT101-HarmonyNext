import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';
import { RcpRequestOptions, RcpResponseData } from '../../core/network/rcpSession';
import * as CryptoJSPkg from '../../vendor/crypto-js-4.2.0.js';
import { encryptPassword, md5HexLower } from '../auth/encryptPassword';
import {
  SmsChallengeInteractionRequiredError,
  SmsChallengeRequest,
  SmsCodeHandler,
} from '../auth/SmsChallengeCoordinator';
import { resolveAbsoluteUrl } from './SchoolServiceResolver';

const SSO_BASE_URL = 'https://sso.bit.edu.cn';
const CAS_BASE_URL = `${SSO_BASE_URL}/cas`;
const URL_CRYPTO_PUBLIC_KEY =
  'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAjVr1zKwohU3xA0afprWLSQvIymaSH/V27MedFc+CecXSnORIFMAp4uEIb4taDq/2X4eMeTI66Mu/rB5GKSFDbExF2Gu4NaO/CNDpf1gHMScUrIFCh4CDqzBnx17kclvezLkIK0T8FVa4cRsINvzjbnA6jUSMaf6Fm1n9wTAtW6QYBjssGOEtCj+c38PTBdFMmJbXp3brt1tEBesz6lb3Fjp76FGvDZ08xtYG8fxYPuiMwKU04eS+mcX/BunwgpU3zwekHYB+PWRIvq0lBry9Wms25sJE5T/RAv5fEuMLbBkfcZK3+7ivSZthTmPpr2Ap/ji70ZZ6u2jvR5VJq+LJHQIDAQAB';
const ALPHANUMERIC = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

export interface SchoolSmsChallengePage {
  execution: string;
  formAction: string;
  userObjectId: string;
  userId: string;
  phone: string;
}

export interface SchoolSmsClient {
  get(url: string, options?: RcpRequestOptions): Promise<RcpResponseData>;
  post(url: string, body: string, options?: RcpRequestOptions): Promise<RcpResponseData>;
}

/** Build the JSON payload used by the second-factor SMS endpoints. */
export function buildSmsSendBody(phone: string): string {
  return JSON.stringify({ phone, businessNo: '0008' });
}

export function buildSmsCheckBody(phone: string, token: string, trustDevice: boolean = false): string {
  return JSON.stringify({ phone, token, delete: false, trustDevice });
}

/** Build the final CAS form submitted after the SMS token is accepted. */
export function buildSmsLoginForm(
  username: string,
  code: string,
  page: SchoolSmsChallengePage,
  trustDevice: boolean = false,
): string {
  const form: Record<string, string> = {
    username,
    password: code,
    type: 'smsLogin',
    _eventId: 'submit',
    geolocation: '',
    execution: page.execution,
    captcha_code: '',
    trustDevice: String(trustDevice).toLowerCase(),
  };
  return Object.entries(form)
    .map(([key, value]: [string, string]): string => `${encodeURIComponent(key)}=${encodeURIComponent(value)}`)
    .join('&');
}

export class SchoolSmsVerificationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'SchoolSmsVerificationError';
  }
}

export class SchoolPasswordLoginError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'SchoolPasswordLoginError';
  }
}

interface EncryptedUrlCryptoBody {
  body: string;
  encryptedKey: string;
  aesKey: Uint8Array;
}

interface SchoolPhoneData {
  tel: string;
  maskTel: string;
}

function decodeHtmlText(value: string): string {
  return value
    .replace(/&amp;/g, '&')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .trim();
}

function extractAttribute(tag: string, name: string): string {
  const pattern = new RegExp(`${name}=["']([^"']*)["']`, 'i');
  const match = tag.match(pattern);
  return match && match[1] ? decodeHtmlText(match[1]) : '';
}

function extractElementText(html: string, id: string): string {
  const openPattern = new RegExp(`<[^>]*id=["']${id}["'][^>]*>`, 'i');
  const openMatch = html.match(openPattern);
  if (!openMatch || !openMatch[0]) return '';
  const value = extractAttribute(openMatch[0], 'value');
  if (value) return value;
  const start = (openMatch.index ?? 0) + openMatch[0].length;
  const remainder = html.slice(start);
  const close = remainder.indexOf('</');
  const raw = close >= 0 ? remainder.slice(0, close) : remainder;
  return decodeHtmlText(raw.replace(/<[^>]+>/g, ''));
}

function extractFormAction(html: string): string {
  const challengeForm = html.match(/<form[^>]*id=["']secondSmsLoginForm["'][^>]*>/i);
  if (challengeForm && challengeForm[0]) {
    return extractAttribute(challengeForm[0], 'action');
  }
  const firstForm = html.match(/<form[^>]*>/i);
  return firstForm && firstForm[0] ? extractAttribute(firstForm[0], 'action') : '';
}

function responseUrl(response: RcpResponseData, fallback: string): string {
  const value = String(response.effectiveUrl ?? '').trim();
  return value || fallback;
}

export function parseSmsChallengePage(html: string, responseUrl: string): SchoolSmsChallengePage | null {
  const hasMarker = /secondSmsLoginForm|second-auth-tip|cas-gateway/i.test(html);
  if (!hasMarker) return null;

  const execution = extractElementText(html, 'login-page-flowkey');
  const userObjectId = extractElementText(html, 'user-object-id');
  if (!execution || !userObjectId) return null;

  return {
    execution,
    formAction: resolveAbsoluteUrl(responseUrl, extractFormAction(html) || 'login'),
    userObjectId,
    userId: extractElementText(html, 'second-auth-user-id'),
    phone: extractElementText(html, 'phone-number'),
  };
}

function mustGetCryptoJS(): any {
  const candidates: any[] = [
    (CryptoJSPkg as any)?.CryptoJS,
    (CryptoJSPkg as any)?.default,
    CryptoJSPkg as any,
    (globalThis as any)?.CryptoJS,
  ];
  for (const candidate of candidates) {
    if (candidate?.algo?.AES && candidate?.enc?.Base64 && candidate?.mode?.ECB && candidate?.pad?.Pkcs7) {
      return candidate;
    }
  }
  throw new SchoolSmsVerificationError('AES provider is unavailable');
}

function bytesToHex(bytes: Uint8Array): string {
  let hex = '';
  for (let i = 0; i < bytes.length; i++) {
    hex += bytes[i].toString(16).padStart(2, '0');
  }
  return hex;
}

function asciiBytes(value: string): Uint8Array {
  const bytes = new Uint8Array(value.length);
  for (let i = 0; i < value.length; i++) {
    bytes[i] = value.charCodeAt(i);
  }
  return bytes;
}

function encryptAesEcbBase64(plaintext: string, keyBytes: Uint8Array): string {
  const cryptoJS = mustGetCryptoJS();
  const key = cryptoJS.enc.Hex.parse(bytesToHex(keyBytes));
  const encrypted = cryptoJS.algo.AES.createEncryptor(key, {
    mode: cryptoJS.mode.ECB,
    padding: cryptoJS.pad.Pkcs7,
  }).finalize(cryptoJS.enc.Utf8.parse(plaintext));
  return cryptoJS.enc.Base64.stringify(encrypted);
}

function decryptAesEcbBase64(ciphertext: string, keyBytes: Uint8Array): string {
  const cryptoJS = mustGetCryptoJS();
  const key = cryptoJS.enc.Hex.parse(bytesToHex(keyBytes));
  const encrypted = cryptoJS.enc.Base64.parse(ciphertext);
  return cryptoJS.algo.AES.createDecryptor(key, {
    mode: cryptoJS.mode.ECB,
    padding: cryptoJS.pad.Pkcs7,
  }).finalize(encrypted).toString(cryptoJS.enc.Utf8);
}

async function encryptUrlCryptoBody(value: string): Promise<EncryptedUrlCryptoBody> {
  try {
    const base64 = new util.Base64Helper();
    const aesKey = cryptoFramework.createRandom().generateRandomSync(16).data;
    const keyBase64 = base64.encodeToStringSync(aesKey);
    const publicKeyBlob: cryptoFramework.DataBlob = {
      data: base64.decodeSync(URL_CRYPTO_PUBLIC_KEY),
    };
    const keyGenerator = cryptoFramework.createAsyKeyGenerator('RSA2048');
    const keyPair = await keyGenerator.convertKey(publicKeyBlob, null);
    const cipher = cryptoFramework.createCipher('RSA2048|PKCS1');
    await cipher.init(cryptoFramework.CryptoMode.ENCRYPT_MODE, keyPair.pubKey, null);
    const keyPlaintext: cryptoFramework.DataBlob = { data: asciiBytes(keyBase64) };
    const encryptedKey = await cipher.doFinal(keyPlaintext);
    return {
      body: encryptAesEcbBase64(value, aesKey),
      encryptedKey: base64.encodeToStringSync(encryptedKey.data),
      aesKey,
    };
  } catch (error) {
    if (error instanceof SchoolSmsVerificationError) throw error;
    throw new SchoolSmsVerificationError('Unable to encrypt the school SMS request');
  }
}

function parseRecord(value: string): Record<string, Object> | null {
  try {
    const parsed = JSON.parse(value) as Object;
    if (typeof parsed === 'object' && parsed !== null && !Array.isArray(parsed)) {
      return parsed as Record<string, Object>;
    }
  } catch {
    return null;
  }
  return null;
}

function decryptResponse(value: string, aesKey: Uint8Array): Record<string, Object> | null {
  let current = value.trim();
  for (let round = 0; round < 4; round++) {
    const parsed = parseRecord(current);
    if (parsed) return parsed;
    try {
      const unwrapped = JSON.parse(current) as Object;
      if (typeof unwrapped === 'string' && unwrapped !== current) {
        current = unwrapped;
        continue;
      }
    } catch {
      // The endpoint normally returns raw Base64 rather than JSON.
    }
    try {
      current = decryptAesEcbBase64(current, aesKey);
    } catch {
      return null;
    }
  }
  return parseRecord(current);
}

function readString(record: Record<string, Object> | null, key: string): string {
  if (!record) return '';
  const value = record[key];
  return value === undefined || value === null ? '' : String(value);
}

function responseCode(record: Record<string, Object> | null): number {
  const raw = readString(record, 'code');
  const code = Number(raw);
  return Number.isFinite(code) ? code : 0;
}

function responseMessage(record: Record<string, Object> | null): string {
  const direct = readString(record, 'message') || readString(record, 'msg') ||
    readString(record, 'errorMessage');
  if (direct) return direct;
  const dataValue = record?.['data'];
  const data = typeof dataValue === 'object' && dataValue !== null
    ? dataValue as Record<string, Object>
    : null;
  return readString(data, 'message') || readString(data, 'msg') || readString(data, 'errorMessage');
}

export function isSmsCodeStillValidResponse(record: Record<string, Object> | null): boolean {
  const message = responseMessage(record);
  return message.includes('验证码') && message.includes('有效期内') && message.includes('重复发送');
}

function protectedHeaders(referer: string): Record<string, string> {
  let random: Uint8Array;
  try {
    random = cryptoFramework.createRandom().generateRandomSync(32).data;
  } catch {
    throw new SchoolSmsVerificationError('Unable to initialize the school SMS request');
  }
  let csrfKey = '';
  for (let i = 0; i < random.length; i++) {
    csrfKey += ALPHANUMERIC[random[i] % ALPHANUMERIC.length];
  }
  const encoded = new util.Base64Helper().encodeToStringSync(asciiBytes(csrfKey));
  const midpoint = Math.floor(encoded.length / 2);
  const mixed = encoded.slice(0, midpoint) + encoded + encoded.slice(midpoint);
  return {
    'Content-Type': 'application/json',
    'Origin': SSO_BASE_URL,
    'Referer': referer,
    'Sid-Language': 'zh_CN',
    'Csrf-Key': csrfKey,
    'Csrf-Value': md5HexLower(mixed),
  };
}

async function postJson(client: SchoolSmsClient, url: string, body: string, referer: string): Promise<Record<string, Object>> {
  const response = await client.post(url, body, {
    headers: protectedHeaders(referer),
    autoRedirect: false,
    collectTimeInfo: false,
  });
  if (response.statusCode >= 400) {
    throw new SchoolSmsVerificationError(`School SMS endpoint failed with HTTP ${response.statusCode}`);
  }
  const parsed = parseRecord(response.bodyText);
  if (!parsed) {
    throw new SchoolSmsVerificationError('School SMS endpoint returned an invalid response');
  }
  return parsed;
}

async function requestPhone(client: SchoolSmsClient, page: SchoolSmsChallengePage): Promise<SchoolPhoneData> {
  const crypto = await encryptUrlCryptoBody(JSON.stringify({ userId: page.userObjectId }));
  const headers = protectedHeaders(`${CAS_BASE_URL}/`);
  headers['hasCrypto'] = 'true';
  headers['privateKey'] = crypto.encryptedKey;
  const response = await client.post(`${CAS_BASE_URL}/api/protected/sms/getPhoneNumberByUserId`, crypto.body, {
    headers,
    autoRedirect: false,
    collectTimeInfo: false,
  });
  if (response.statusCode >= 400 || !response.bodyText.trim()) {
    throw new SchoolSmsVerificationError('Unable to retrieve the bound phone for SMS verification');
  }
  const decrypted = decryptResponse(response.bodyText, crypto.aesKey);
  const dataValue = decrypted?.['data'];
  const data = typeof dataValue === 'object' && dataValue !== null
    ? dataValue as Record<string, Object>
    : null;
  const tel = readString(data, 'tel') || page.phone;
  if (!tel) {
    throw new SchoolSmsVerificationError('School SMS response omitted the bound phone identifier');
  }
  return {
    tel,
    maskTel: readString(data, 'maskTel') || '绑定手机',
  };
}

export async function completeSchoolSmsChallenge(
  client: SchoolSmsClient,
  username: string,
  page: SchoolSmsChallengePage,
  smsCodeHandler?: SmsCodeHandler,
  trustDevice: boolean = false,
): Promise<RcpResponseData> {
  if (!smsCodeHandler) {
    throw new SmsChallengeInteractionRequiredError();
  }
  const phone = await requestPhone(client, page);
  const sent = await postJson(
    client,
    `${CAS_BASE_URL}/api/protected/sms/publicNoToken/sendSmsCode`,
    buildSmsSendBody(phone.tel),
    `${CAS_BASE_URL}/`,
  );
  if (responseCode(sent) !== 200 && !isSmsCodeStillValidResponse(sent)) {
    throw new SchoolSmsVerificationError(responseMessage(sent) || 'Unable to send the school SMS code');
  }

  const request: SmsChallengeRequest = {
    phone: '',
    maskedPhone: phone.maskTel,
    purpose: 'password_second_factor',
  };
  const code = (await smsCodeHandler(request)).trim();
  if (!code) {
    throw new SchoolSmsVerificationError('The school SMS code is empty');
  }

  const checked = await postJson(
    client,
    `${CAS_BASE_URL}/api/protected/sms/checkToken`,
    buildSmsCheckBody(phone.tel, code, trustDevice),
    `${CAS_BASE_URL}/`,
  );
  if (responseCode(checked) !== 200) {
    throw new SchoolSmsVerificationError(responseMessage(checked) || 'The school SMS code was rejected');
  }

  const body = buildSmsLoginForm(username, code, page, trustDevice);
  return await client.post(page.formAction, body, {
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      'Origin': SSO_BASE_URL,
      'Referer': `${CAS_BASE_URL}/`,
    },
    autoRedirect: false,
    collectTimeInfo: false,
  });
}

function toFormUrlEncoded(form: Record<string, string>): string {
  const parts: string[] = [];
  for (const [key, value] of Object.entries(form)) {
    parts.push(`${encodeURIComponent(key)}=${encodeURIComponent(value)}`);
  }
  return parts.join('&');
}

export async function loginSchoolSsoPassword(
  client: SchoolSmsClient,
  username: string,
  password: string,
  service?: string,
  smsCodeHandler?: SmsCodeHandler,
): Promise<RcpResponseData> {
  const loginUrl = service
    ? `${CAS_BASE_URL}/login?service=${encodeURIComponent(service)}`
    : `${CAS_BASE_URL}/login`;
  const loginPage = await client.get(loginUrl, {
    autoRedirect: false,
    collectTimeInfo: false,
  });
  if (loginPage.statusCode !== 200) {
    throw new SchoolPasswordLoginError(`统一身份认证请求失败（HTTP ${loginPage.statusCode}）`);
  }

  const execution = extractElementText(loginPage.bodyText, 'login-page-flowkey');
  const cryptoKey = extractElementText(loginPage.bodyText, 'login-croypto');
  if (!execution || !cryptoKey) {
    throw new SchoolPasswordLoginError('统一身份认证登录页缺少必要参数');
  }
  const pageUrl = responseUrl(loginPage, loginUrl);
  const formAction = resolveAbsoluteUrl(pageUrl, extractFormAction(loginPage.bodyText) || 'login');
  const form: Record<string, string> = {
    username,
    password: encryptPassword(password, cryptoKey),
    execution,
    captcha_payload: '',
    croypto: cryptoKey,
    captcha_code: '',
    type: 'UsernamePassword',
    _eventId: 'submit',
    geolocation: '',
  };
  let response = await client.post(formAction, toFormUrlEncoded(form), {
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      'Origin': SSO_BASE_URL,
      'Referer': pageUrl,
    },
    autoRedirect: false,
    collectTimeInfo: false,
  });

  const smsPage = parseSmsChallengePage(
    response.bodyText,
    responseUrl(response, formAction),
  );
  if (smsPage) {
    response = await completeSchoolSmsChallenge(
      client,
      username,
      smsPage,
      smsCodeHandler,
      false,
    );
  }

  if (response.statusCode >= 400) {
    const body = response.bodyText ?? '';
    const looksLikeLoginMarkup = /login-page-flowkey|normalLoginForm|smsLoginForm|secondSmsLoginForm|cas-gateway/i.test(body);
    const requiresCaptcha = /captcha|验证码/i.test(body);
    if (looksLikeLoginMarkup && requiresCaptcha && response.statusCode <= 403) {
      throw new SchoolPasswordLoginError('需要验证码');
    }
    if (looksLikeLoginMarkup && response.statusCode <= 403) {
      throw new SchoolPasswordLoginError('账号或密码错误');
    }
    throw new SchoolPasswordLoginError(`统一身份认证请求失败（HTTP ${response.statusCode}）`);
  }
  if (parseSmsChallengePage(response.bodyText, responseUrl(response, formAction))) {
    throw new SchoolSmsVerificationError('短信验证码错误或已失效');
  }
  if (response.statusCode === 200 && (
    response.bodyText.includes('normalLoginForm') ||
    response.bodyText.includes('login-page-flowkey') ||
    response.bodyText.includes('统一身份认证')
  )) {
    throw new SchoolPasswordLoginError('账号或密码错误');
  }
  return response;
}
