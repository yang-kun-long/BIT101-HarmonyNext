import type { CookieDump } from '../../core/network/cookieJar';
import type { SchoolLoginMode } from './SchoolAuthTypes';

export interface SchoolSessionState {
  mode: SchoolLoginMode;
  cookies: CookieDump;
  portalService?: string;
  targetService?: string;
  effectiveUrl?: string;
}
