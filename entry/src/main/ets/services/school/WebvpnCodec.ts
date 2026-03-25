import * as CryptoJSPkg from '../../vendor/crypto-js-4.2.0.js';
import { Logger } from '../../utils/Logger';

const VPN_KEY = 'wrdvpnisthebest!';
const VPN_IV = 'wrdvpnisthebest!';
const logger = new Logger('WebvpnCodec');

function mustGetCryptoJS(): any {
  const cands: any[] = [
    (CryptoJSPkg as any)?.CryptoJS,
    (CryptoJSPkg as any)?.default,
    (CryptoJSPkg as any),
    (globalThis as any)?.CryptoJS,
  ];

  for (let i = 0; i < cands.length; i++) {
    const c = cands[i];
    if (c?.AES?.encrypt && c?.enc?.Utf8 && c?.mode?.CBC && c?.pad?.NoPadding) {
      return c;
    }
  }
  throw new Error('CryptoJS not loaded for WebVPN host encoding');
}

function xorBlocks(left: number[], right: number[]): number[] {
  const out: number[] = [];
  for (let i = 0; i < 16; i++) {
    out.push((left[i] ?? 0) ^ (right[i] ?? 0));
  }
  return out;
}

function bytesToHex(bytes: number[]): string {
  return bytes.map((b) => b.toString(16).padStart(2, '0')).join('');
}

function asciiBytes(text: string): number[] {
  const bytes: number[] = [];
  for (let i = 0; i < text.length; i++) {
    bytes.push(text.charCodeAt(i) & 0xff);
  }
  return bytes;
}

function toWordArray(bytes: number[], CryptoJS: any): any {
  return CryptoJS.enc.Hex.parse(bytesToHex(bytes));
}

function encryptBlock(block: number[], CryptoJS: any): number[] {
  const key = CryptoJS.enc.Utf8.parse(VPN_KEY);
  const encryptor = CryptoJS.algo.AES.createEncryptor(key, {
    mode: CryptoJS.mode.ECB,
    padding: CryptoJS.pad.NoPadding,
  });
  const encrypted = encryptor.finalize(toWordArray(block, CryptoJS));
  const hex = encrypted.toString(CryptoJS.enc.Hex);
  const out: number[] = [];
  for (let i = 0; i < hex.length && out.length < 16; i += 2) {
    out.push(parseInt(hex.slice(i, i + 2), 16));
  }
  return out;
}

export function encodeVpnHost(host: string): string {
  if (!host) {
    throw new Error('host is required');
  }

  const CryptoJS = mustGetCryptoJS();
  const textLen = host.length;
  const padLen = (16 - (textLen % 16)) % 16;
  const plain = asciiBytes(host + '0'.repeat(padLen));
  const iv = asciiBytes(VPN_IV);

  let feedback = iv;
  const cipherBytes: number[] = [];

  for (let i = 0; i < plain.length; i += 16) {
    const block = plain.slice(i, i + 16);
    const keystream = encryptBlock(feedback, CryptoJS);
    const cipherBlock = xorBlocks(block, keystream);
    cipherBytes.push(...cipherBlock);
    feedback = cipherBlock;
  }
  const result = bytesToHex(iv) + bytesToHex(cipherBytes).slice(0, textLen * 2);
  logger.debug('encodeVpnHost host =', host, 'encoded =', result);
  return result;
}
