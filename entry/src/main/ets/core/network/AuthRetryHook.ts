export interface AuthRetryHook {
  refreshCookie(): Promise<string | null>;
  drain(): Promise<void>;
}
let hook: AuthRetryHook | null = null;
export function registerAuthRetryHook(value: AuthRetryHook): void { hook = value; }
export async function refreshRejectedCookie(): Promise<string | null> {
  return hook ? await hook.refreshCookie() : null;
}
export async function drainAuthenticationRefresh(): Promise<void> { if (hook) await hook.drain(); }
