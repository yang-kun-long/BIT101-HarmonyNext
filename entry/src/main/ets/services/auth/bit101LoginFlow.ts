import { VerifyResult } from './authRepository';

export interface Bit101LoginFlowParams {
  sid: string;
  password: string;
  captcha?: string;
}

export interface Bit101LoginFlowAuth {
  loginBit101(params: Bit101LoginFlowParams): Promise<string>;
  loginViaWebVpnVerify(params: Bit101LoginFlowParams): Promise<VerifyResult>;
}

export interface Bit101LoginFlowResult {
  fakeCookie: string;
  webvpn: VerifyResult;
  ok: boolean;
}

export async function loginBit101AndVerifyWebvpn(
  auth: Bit101LoginFlowAuth,
  params: Bit101LoginFlowParams,
): Promise<Bit101LoginFlowResult> {
  const normalized: Bit101LoginFlowParams = {
    sid: params.sid.trim(),
    password: params.password,
    captcha: params.captcha,
  };

  const fakeCookie = await auth.loginBit101(normalized);
  const webvpn = await auth.loginViaWebVpnVerify(normalized);

  return {
    fakeCookie,
    webvpn,
    ok: fakeCookie.length > 0 && webvpn.ok,
  };
}
