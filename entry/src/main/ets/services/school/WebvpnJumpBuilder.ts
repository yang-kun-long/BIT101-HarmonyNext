import { encodeVpnHost } from './WebvpnCodec';
import { Logger } from '../../utils/Logger';

const WEBVPN_BASE = 'https://webvpn.bit.edu.cn';
const logger = new Logger('WebvpnJumpBuilder');

interface ParsedAbsoluteUrl {
  protocol: string;
  hostname: string;
  pathname: string;
  search: string;
}

function parseAbsoluteUrl(url: string): ParsedAbsoluteUrl {
  const match = url.match(/^(https?):\/\/([^\/?#]+)([^?#]*)(\?[^#]*)?$/i);
  if (!match) {
    throw new Error(`invalid absolute url: ${url}`);
  }

  return {
    protocol: match[1],
    hostname: match[2],
    pathname: match[3] || '/',
    search: match[4] || '',
  };
}

export function buildWebvpnJumpUrl(service: string, ticket: string): string {
  if (!service || !ticket) {
    throw new Error('service and ticket are required');
  }

  const svc = parseAbsoluteUrl(service);
  const encodedHost = encodeVpnHost(svc.hostname);
  const query = svc.search ? `${svc.search}&ticket=${ticket}` : `?ticket=${ticket}`;
  const jumpUrl = `${WEBVPN_BASE}/${svc.protocol}/${encodedHost}${svc.pathname}${query}`;
  logger.debug('buildWebvpnJumpUrl service =', service, 'jumpUrl =', jumpUrl);
  return jumpUrl;
}
