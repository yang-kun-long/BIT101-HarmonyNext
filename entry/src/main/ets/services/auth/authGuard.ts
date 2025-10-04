// entry/src/main/ets/services/auth/authGuard.ts
import { TokenStore } from '../storage/tokenStore'
export async function isAuthedBit101(): Promise<boolean> {
  return new TokenStore().isLoggedInBit101() // 是否有 fake_cookie
}
