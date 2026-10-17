import { CredentialStore, SavedCredentials } from './LoginRefreshCoordinator';

/** Remove the previous account before saving a newly authenticated identity. */
export async function applyLoginCredentialChoice(store: CredentialStore, save: boolean, credentials: SavedCredentials): Promise<void> {
  await store.clear();
  if (save) await store.save(credentials);
}
