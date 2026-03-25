import { Logger } from '../../utils/Logger';

const WEBVPN_BASE = 'https://webvpn.bit.edu.cn';
const logger = new Logger('SchoolServiceResolver');

function readServiceFromUrl(rawUrl: string): string {
  if (!rawUrl) return '';
  const match = rawUrl.match(/[?&]service=([^&#]+)/i);
  return match && match[1] ? decodeURIComponent(match[1]) : '';
}

export function resolveAbsoluteUrl(currentUrl: string, location: string): string {
  if (!location) return '';
  if (/^https?:\/\//i.test(location)) {
    return location;
  }
  if (location.startsWith('/')) {
    const originMatch = currentUrl.match(/^(https?:\/\/[^/]+)/i);
    return originMatch ? `${originMatch[1]}${location}` : location;
  }
  const lastSlash = currentUrl.lastIndexOf('/');
  if (lastSlash >= 0) {
    return `${currentUrl.slice(0, lastSlash + 1)}${location}`;
  }
  return location;
}

export function resolveServiceFromRedirect(currentUrl: string, location: string): string {
  const nextUrl = resolveAbsoluteUrl(currentUrl, location);
  const service = readServiceFromUrl(nextUrl);
  logger.debug('resolveServiceFromRedirect currentUrl =', currentUrl, 'nextUrl =', nextUrl, 'service =', service);
  return service;
}

export function extractPortalServiceFromLocation(location: string): string {
  const absolute = location.startsWith('http') ? location : `${WEBVPN_BASE}${location}`;
  const service = readServiceFromUrl(absolute);
  logger.debug('extractPortalServiceFromLocation absolute =', absolute, 'service =', service);
  return service;
}
