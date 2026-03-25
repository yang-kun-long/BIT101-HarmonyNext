import ohosUrl from '@ohos.url';
import { encodeVpnHost } from './WebvpnCodec';
import { Logger } from '../../utils/Logger';

const WEBVPN_BASE = 'https://webvpn.bit.edu.cn';
const logger = new Logger('WebvpnJumpBuilder');

export function buildWebvpnJumpUrl(service: string, ticket: string): string {
  if (!service || !ticket) {
    throw new Error('service and ticket are required');
  }

  const svc = new ohosUrl.URL(service);
  const encodedHost = encodeVpnHost(svc.hostname);
  const protocol = svc.protocol.replace(':', '');
  const query = svc.search ? `${svc.search}&ticket=${ticket}` : `?ticket=${ticket}`;
  const jumpUrl = `${WEBVPN_BASE}/${protocol}/${encodedHost}${svc.pathname}${query}`;
  logger.debug('buildWebvpnJumpUrl service =', service, 'jumpUrl =', jumpUrl);
  return jumpUrl;
}
