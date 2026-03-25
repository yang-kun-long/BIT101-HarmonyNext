import http from '@ohos.net.http';
import { SchoolStError, SchoolTgtError } from './SchoolAuthErrors';
import { Logger } from '../../utils/Logger';

const CAS_TICKET_URL = 'https://sso.bit.edu.cn/cas/v1/tickets';
const DEFAULT_UA =
  'Mozilla/5.0 (HarmonyOS; ArkTS) AppleWebKit/537.36 (KHTML, like Gecko) Mobile Safari/537.36';
const logger = new Logger('SchoolCasClient');

function findHeader(headers: Record<string, Object> | undefined, wanted: string): string {
  if (!headers) return '';
  const keys = Object.keys(headers);
  for (let i = 0; i < keys.length; i++) {
    const key = keys[i];
    if (key.toLowerCase() !== wanted.toLowerCase()) continue;
    const value = headers[key];
    return typeof value === 'string' ? value : '';
  }
  return '';
}

export function parseTgtLocationFromHtml(html: string): string {
  if (!html) return '';
  const match = html.match(/action="([^"]+)"/i);
  return match && match[1] ? match[1].trim() : '';
}

export function parseTgtUrl(status: number, headers?: Record<string, Object>, bodyText: string = ''): string {
  if (status !== 201) {
    throw new SchoolTgtError(`Unexpected TGT status: ${status}`);
  }

  const fromHeader = findHeader(headers, 'location').trim();
  if (fromHeader) return fromHeader;

  const fromHtml = parseTgtLocationFromHtml(bodyText);
  if (fromHtml) return fromHtml;

  throw new SchoolTgtError('Cannot parse TGT URL from response');
}

export function parseSt(bodyText: string): string {
  const st = bodyText.trim();
  if (!st) {
    throw new SchoolStError('Empty ST response');
  }
  return st;
}

export class SchoolCasClient {
  private readonly userAgent: string;

  constructor(userAgent: string = DEFAULT_UA) {
    this.userAgent = userAgent;
  }

  async getTgt(username: string, password: string, timeoutMs: number = 15000): Promise<string> {
    if (!username || !password) {
      throw new SchoolTgtError('username and password are required');
    }

    const client = http.createHttp();
    try {
      const body =
        `username=${encodeURIComponent(username)}&password=${encodeURIComponent(password)}`;
      const res = await client.request(CAS_TICKET_URL, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': this.userAgent,
        },
        extraData: body,
        connectTimeout: timeoutMs,
        readTimeout: timeoutMs,
      });
      logger.debug('getTgt status =', res.responseCode);
      return parseTgtUrl(res.responseCode, res.header as Record<string, Object>, String(res.result ?? ''));
    } finally {
      client.destroy();
    }
  }

  async getSt(tgtUrl: string, service: string, timeoutMs: number = 15000): Promise<string> {
    if (!tgtUrl || !service) {
      throw new SchoolStError('tgtUrl and service are required');
    }

    const client = http.createHttp();
    try {
      const body = `service=${encodeURIComponent(service)}`;
      const res = await client.request(tgtUrl, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': this.userAgent,
        },
        extraData: body,
        connectTimeout: timeoutMs,
        readTimeout: timeoutMs,
      });

      if (res.responseCode < 200 || res.responseCode >= 300) {
        throw new SchoolStError(`Unexpected ST status: ${res.responseCode}`);
      }
      logger.debug('getSt status =', res.responseCode, 'service =', service);
      return parseSt(String(res.result ?? ''));
    } finally {
      client.destroy();
    }
  }
}
