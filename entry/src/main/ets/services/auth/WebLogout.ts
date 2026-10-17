import webview from '@ohos.web.webview';

type WebLogoutListener = () => Promise<void>;
const listeners: Set<WebLogoutListener> = new Set();
let revision: number = 0;
export function webSessionRevision(): number { return revision; }
export function observeWebLogout(listener: WebLogoutListener): () => void {
  listeners.add(listener); return () => { listeners.delete(listener); };
}
export async function clearWebLoginData(): Promise<void> {
  revision++;
  // First stop all live pages so an old document cannot repopulate web storage.
  const results = await Promise.allSettled(Array.from(listeners).map(listener => listener()));
  webview.WebCookieManager.clearAllCookiesSync();
  webview.WebStorage.deleteAllData();
  if (results.some(result => result.status === 'rejected')) throw new Error('网页会话清理失败，请重试退出登录');
}
