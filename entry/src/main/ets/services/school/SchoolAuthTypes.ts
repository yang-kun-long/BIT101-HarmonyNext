export type SchoolLoginMode = 'inner' | 'webvpn';

export interface SchoolServiceTarget {
  name: string;
  service: string;
  requiresWebvpnEncoding?: boolean;
}

export interface SchoolTicketGrant {
  tgtUrl: string;
  service: string;
  st: string;
}

export interface SchoolLoginResult {
  mode: SchoolLoginMode;
  portalLoggedIn: boolean;
  targetLoggedIn: boolean;
  targetName?: string;
  effectiveUrl?: string;
}

export interface SchoolBootstrapResult {
  targetName: string;
  success: boolean;
  effectiveUrl?: string;
  details?: string;
}
