export interface WebScrollPosition {
  x: number;
  y: number;
}

export const WEB_HISTORY_MAX_BYTES: number = 512 * 1024;

export function isHttpWebUrl(url: string): boolean {
  if (/[\u0000-\u0020\\]/.test(url)) return false;
  const match = url.match(/^https?:\/\/([a-z0-9](?:[a-z0-9.-]*[a-z0-9])?)(?::(\d{1,5}))?(?:[/?#]|$)/i);
  return !!match && (!match[2] || Number(match[2]) <= 65535);
}

export function canOpenExternalWebUrl(url: string): boolean {
  return isHttpWebUrl(url) || /^(mailto:[^\s]+|tel:\+?[0-9() -]+)$/i.test(url);
}

export function shouldShowWebError(isMainFrame: boolean, status: number = 0): boolean {
  return isMainFrame && (status === 0 || status >= 400);
}

export interface WebBackTarget {
  accessBackward(): boolean;
  backward(): void;
}

export function webBackward(target: WebBackTarget): boolean {
  try {
    if (!target.accessBackward()) return false;
    target.backward();
    return true;
  } catch (_) { return false; }
}

/** Owned by the page, in memory only. Never shared between separate browser pages. */
export class WebNavigationState {
  url: string = '';
  history: Uint8Array | null = null;
  scroll: WebScrollPosition = { x: 0, y: 0 };

  recordUrl(url: string): void {
    if (!isHttpWebUrl(url)) return;
    if (url !== this.url) this.scroll = { x: 0, y: 0 };
    this.url = url;
  }

  recordScroll(x: number, y: number): void {
    this.scroll = { x: Number.isFinite(x) ? Math.max(0, x) : 0, y: Number.isFinite(y) ? Math.max(0, y) : 0 };
  }

  recordHistory(history: Uint8Array): void {
    this.history = history.byteLength > 0 && history.byteLength <= WEB_HISTORY_MAX_BYTES ? history : null;
  }

  clear(): void { this.url = ''; this.history = null; this.scroll = { x: 0, y: 0 }; }
}
