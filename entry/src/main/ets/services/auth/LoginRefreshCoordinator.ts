import { AuthFlowError } from './AuthFailure';

export interface SavedCredentials { username: string; password: string; }
export interface CredentialStore {
  save(credentials: SavedCredentials): Promise<void>;
  get(): Promise<SavedCredentials | null>;
  clear(): Promise<void>;
}
export type RefreshResult = 'SUCCESS' | 'FAILED' | 'INTERACTION_REQUIRED' | 'BUSY';
export interface RefreshLogin { login(credentials: SavedCredentials): Promise<void>; }

/** One refresh at a time. Callers must never clear sessions merely because it is busy. */
export class LoginRefreshCoordinator {
  private busy: boolean = false;
  constructor(private credentials: CredentialStore, private auth: RefreshLogin) {}
  async refresh(): Promise<RefreshResult> {
    if (this.busy) return 'BUSY';
    this.busy = true;
    try {
      const saved = await this.credentials.get();
      if (!saved) return 'INTERACTION_REQUIRED';
      try {
        await this.auth.login(saved);
        return 'SUCCESS';
      } catch (error) {
        // Only an explicit credential rejection can destroy the saved secret.
        if (error instanceof AuthFlowError) {
          if (error.kind === 'invalid_credentials') await this.credentials.clear();
          if (error.kind === 'sms_required' || error.kind === 'interaction_required' || error.kind === 'captcha_required') return 'INTERACTION_REQUIRED';
        }
        return 'FAILED';
      } finally { saved.password = ''; }
    } catch (_) { return 'FAILED'; }
    finally { this.busy = false; }
  }
}

/** Retry only a confirmed authentication rejection, at most once. */
export async function retryAfterLoginRefresh<T>(operation: () => Promise<T>,
  isAuthenticationFailure: (error: Error) => boolean, coordinator: LoginRefreshCoordinator): Promise<T> {
  try { return await operation(); }
  catch (error) {
    if (!(error instanceof Error) || !isAuthenticationFailure(error)) throw error;
    const result = await coordinator.refresh();
    if (result !== 'SUCCESS') throw error;
    return await operation();
  }
}
