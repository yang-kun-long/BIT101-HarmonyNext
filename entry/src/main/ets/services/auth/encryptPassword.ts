// entry/src/main/ets/services/auth/encryptPassword.ts
import * as CryptoJSPkg from '../../vendor/crypto-js-4.2.0.js';
import { Logger } from '../../utils/Logger';
const logger = new Logger('EncryptPassword');
function mustGetCryptoJS(): any {
  const cands: any[] = [
    (CryptoJSPkg as any)?.CryptoJS,
    (CryptoJSPkg as any)?.default,
    (CryptoJSPkg as any),
    (globalThis as any)?.CryptoJS,
  ];
  for (const c of cands) {
    if (c?.enc?.Base64 && c?.algo?.AES && c?.mode?.ECB && c?.pad?.Pkcs7) return c;
  }
  // 打印 keys 帮助定位打包问题
  // @ts-ignore
  logger.debug('CryptoJS keys:', Object.keys(CryptoJSPkg || {}));
  throw new Error('CryptoJS not loaded. Check vendor import path.');
}

export function encryptPassword(plain: string, saltBase64: string): string {
  if (!plain || !saltBase64) throw new Error('encryptPassword: plain & saltBase64 required');
  const CryptoJS = mustGetCryptoJS();
  const key = CryptoJS.enc.Base64.parse(saltBase64);
  const encryptor = CryptoJS.algo.AES.createEncryptor(key, { mode: CryptoJS.mode.ECB, padding: CryptoJS.pad.Pkcs7 });
  const ctWA = encryptor.finalize(CryptoJS.enc.Utf8.parse(plain));
  return CryptoJS.enc.Base64.stringify(ctWA);
}

// += 在 encryptPassword.ts 追加
export function md5HexLower(plain: string): string {
  const CryptoJS = mustGetCryptoJS();
  return CryptoJS.MD5(plain).toString(CryptoJS.enc.Hex).toLowerCase();
}

// 可选自测
export function __cryptoSelfTest(): boolean {
  try {
    const out = encryptPassword('ykl12138', 'MDEyMzQ1Njc4OWFiY2RlZg==');
    return out === 'EuLn3+Z6/3lbVnbTYhIwxw==';
  } catch {
    return false;
  }
}
