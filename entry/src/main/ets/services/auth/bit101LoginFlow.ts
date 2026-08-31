import { VerifyResult } from './authRepository';

export interface Bit101LoginFlowParams {
  sid: string;
  password: string;
  captcha?: string;
}

export interface Bit101LoginFlowAuth {
  loginBit101(params: Bit101LoginFlowParams): Promise<string>;
  loginViaWebVpnVerify(params: Bit101LoginFlowParams): Promise<VerifyResult>;
  loginBit101Staged(params: Bit101LoginFlowParams): Promise<string>;
  loginViaWebVpnVerifyStaged(params: Bit101LoginFlowParams): Promise<VerifyResult>;
}

export interface Bit101LoginFlowResult {
  fakeCookie: string;
  webvpn: VerifyResult;
  ok: boolean;
}

export async function loginBit101AndVerifyWebvpn(
  auth: Bit101LoginFlowAuth,
  params: Bit101LoginFlowParams,
  persist: boolean = true,
): Promise<Bit101LoginFlowResult> {
  const normalized: Bit101LoginFlowParams = {
    sid: params.sid.trim(),
    password: params.password,
    captcha: params.captcha,
  };

  const fakeCookie = persist
    ? await auth.loginBit101(normalized)
    : await auth.loginBit101Staged(normalized);
  const webvpn = persist
    ? await auth.loginViaWebVpnVerify(normalized)
    : await auth.loginViaWebVpnVerifyStaged(normalized);

  return {
    fakeCookie,
    webvpn,
    ok: fakeCookie.length > 0 && webvpn.ok,
  };
}
