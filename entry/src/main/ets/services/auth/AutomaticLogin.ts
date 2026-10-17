import { common } from '@kit.AbilityKit';
import { LoginCoordinator } from './LoginCoordinator';
import { LoginRefreshCoordinator, SavedCredentials, RefreshLogin, RefreshResult } from './LoginRefreshCoordinator';
import { createSecureCredentialStore } from '../storage/CredentialStorePlatform';
import { registerAuthRetryHook, AuthRetryHook } from '../../core/network/AuthRetryHook';
import { TokenStore } from '../storage/tokenStore';

class BackgroundLogin implements RefreshLogin {
  private loginCoordinator = new LoginCoordinator(undefined, false);
  async login(credentials: SavedCredentials): Promise<void> {
    await this.loginCoordinator.login({ sid: credentials.username, password: credentials.password });
  }
}
let coordinator: LoginRefreshCoordinator | null = null;
let pending: Promise<RefreshResult> | null = null;
class SavedLoginRetry implements AuthRetryHook {
  async drain(): Promise<void> { if (pending) await pending; }
  async refreshCookie(): Promise<string | null> {
    if (await refreshSavedLogin() !== 'SUCCESS') return null;
    return await new TokenStore().getFakeCookie();
  }
}
export function initializeAutomaticLogin(context: common.Context): void {
  coordinator = new LoginRefreshCoordinator(createSecureCredentialStore(context), new BackgroundLogin());
  registerAuthRetryHook(new SavedLoginRetry());
}
export async function refreshSavedLogin(): Promise<RefreshResult> {
  if (pending) return 'BUSY';
  if (!coordinator) return 'INTERACTION_REQUIRED';
  pending = coordinator.refresh();
  try { return await pending; } finally { pending = null; }
}
