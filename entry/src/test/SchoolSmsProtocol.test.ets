import { describe, it, expect } from '@ohos/hypium';
import {
  buildSmsCheckBody,
  buildSmsLoginForm,
  buildSmsSendBody,
  isSmsCodeStillValidResponse,
  loginSchoolSsoPassword,
  parseSmsChallengePage,
  SchoolSmsClient,
  SchoolSmsChallengePage,
} from '../main/ets/services/school/SchoolSmsProtocol';
import { RcpRequestOptions, RcpResponseData } from '../main/ets/core/network/rcpSession';
import { SmsChallengeInteractionRequiredError } from '../main/ets/services/auth/SmsChallengeCoordinator';

class FakeSchoolSmsClient implements SchoolSmsClient {
  readonly calls: string[] = [];
  private readonly responses: RcpResponseData[];

  constructor(responses: RcpResponseData[]) {
    this.responses = responses;
  }

  async get(url: string, options?: RcpRequestOptions): Promise<RcpResponseData> {
    this.calls.push(`GET:${url}:${String(options?.autoRedirect)}`);
    return this.responses.shift() as RcpResponseData;
  }

  async post(url: string, body: string, options?: RcpRequestOptions): Promise<RcpResponseData> {
    this.calls.push(`POST:${url}:${body}:${String(options?.autoRedirect)}`);
    return this.responses.shift() as RcpResponseData;
  }
}

async function captureError(action: () => Promise<void>): Promise<Error | null> {
  try {
    await action();
  } catch (error) {
    return error instanceof Error ? error : new Error(String(error));
  }
  return null;
}

export default function schoolSmsProtocolTest() {
  describe('School SMS protocol', () => {
    it('parses second-factor fields and resolves a relative action', 0, () => {
      const html = '<form id="secondSmsLoginForm" action="login">' +
        '<span id="login-page-flowkey">second-flow</span>' +
        '<span id="user-object-id">object-id</span>' +
        '<span id="second-auth-user-id">student-id</span>' +
        '<span id="phone-number">opaque-phone</span></form>';

      const page: SchoolSmsChallengePage | null = parseSmsChallengePage(
        html,
        'https://sso.bit.edu.cn/cas/login?service=https%3A%2F%2Flexue.bit.edu.cn',
      );

      expect(page !== null).assertTrue();
      expect(page?.execution).assertEqual('second-flow');
      expect(page?.userObjectId).assertEqual('object-id');
      expect(page?.userId).assertEqual('student-id');
      expect(page?.phone).assertEqual('opaque-phone');
      expect(page?.formAction).assertEqual('https://sso.bit.edu.cn/cas/login');
    });

    it('reads hidden input values and absolute form actions', 0, () => {
      const html = '<form action="https://sso.bit.edu.cn/cas/login" id="secondSmsLoginForm">' +
        '<input value="flow-from-value" id="login-page-flowkey">' +
        '<input id="user-object-id" value="object-from-value"></form>';

      const page = parseSmsChallengePage(html, 'https://sso.bit.edu.cn/cas/login');

      expect(page?.execution).assertEqual('flow-from-value');
      expect(page?.userObjectId).assertEqual('object-from-value');
      expect(page?.formAction).assertEqual('https://sso.bit.edu.cn/cas/login');
    });

    it('does not mistake an ordinary login page for an SMS challenge', 0, () => {
      const html = '<span id="login-page-flowkey">flow</span>' +
        '<span id="user-object-id">object</span>';
      expect(parseSmsChallengePage(html, 'https://sso.bit.edu.cn/cas/login')).assertNull();
    });

    it('requires both execution and user object id', 0, () => {
      expect(parseSmsChallengePage(
        '<form id="secondSmsLoginForm"><span id="login-page-flowkey">flow</span></form>',
        'https://sso.bit.edu.cn/cas/login',
      )).assertNull();
    });

    it('accepts the server response that an existing code is still valid', 0, () => {
      const response = JSON.parse(
        '{"code":400,"message":"验证码在有效期内，请勿重复发送"}',
      ) as Record<string, Object>;
      expect(isSmsCodeStillValidResponse(response)).assertTrue();
      const nested = JSON.parse(
        '{"code":400,"data":{"errorMessage":"验证码在有效期内，请勿重复发送"}}',
      ) as Record<string, Object>;
      expect(isSmsCodeStillValidResponse(nested)).assertTrue();
    });

    it('builds protocol payloads without dropping trust-device semantics', 0, () => {
      expect(buildSmsSendBody('opaque-phone')).assertEqual(
        '{"phone":"opaque-phone","businessNo":"0008"}',
      );
      expect(buildSmsCheckBody('opaque-phone', '123456', true)).assertEqual(
        '{"phone":"opaque-phone","token":"123456","delete":false,"trustDevice":true}',
      );

      const form = buildSmsLoginForm(
        'student&1',
        '12=34',
        {
          execution: 'flow key',
          formAction: 'https://sso.bit.edu.cn/cas/login',
          userObjectId: 'object',
          userId: 'student',
          phone: '',
        },
        true,
      );
      expect(form.includes('type=smsLogin')).assertTrue();
      expect(form.includes('username=student%261')).assertTrue();
      expect(form.includes('password=12%3D34')).assertTrue();
      expect(form.includes('execution=flow%20key')).assertTrue();
      expect(form.includes('trustDevice=true')).assertTrue();
    });

    it('detects a challenge after password submission and never waits without a foreground handler', 0, async () => {
      const loginPage: RcpResponseData = {
        statusCode: 200,
        headers: {},
        bodyText: '<form action="login"><span id="login-page-flowkey">flow</span>' +
          '<span id="login-croypto">MDEyMzQ1Njc4OWFiY2RlZg==</span></form>',
        effectiveUrl: 'https://sso.bit.edu.cn/cas/login',
      };
      const challengePage: RcpResponseData = {
        statusCode: 200,
        headers: {},
        bodyText: '<form id="secondSmsLoginForm" action="login">' +
          '<span id="login-page-flowkey">second</span>' +
          '<span id="user-object-id">object</span></form>',
        effectiveUrl: 'https://sso.bit.edu.cn/cas/login',
      };
      const client = new FakeSchoolSmsClient([loginPage, challengePage]);

      const error = await captureError(async (): Promise<void> => {
        await loginSchoolSsoPassword(client, 'student', 'password');
      });

      expect(error instanceof SmsChallengeInteractionRequiredError).assertTrue();
      expect(client.calls.length).assertEqual(2);
      expect(client.calls[1].includes('type=UsernamePassword')).assertTrue();
      expect(client.calls[1].includes('password=password')).assertFalse();
    });

    it('classifies a CAS login rejection page as invalid credentials', 0, async () => {
      const loginPage: RcpResponseData = {
        statusCode: 200,
        headers: {},
        bodyText: '<form action="login"><span id="login-page-flowkey">flow</span>' +
          '<span id="login-croypto">MDEyMzQ1Njc4OWFiY2RlZg==</span></form>',
        effectiveUrl: 'https://sso.bit.edu.cn/cas/login',
      };
      const rejected: RcpResponseData = {
        statusCode: 401,
        headers: {},
        bodyText: '<form id="normalLoginForm"><span id="login-page-flowkey">flow</span></form>',
        effectiveUrl: 'https://sso.bit.edu.cn/cas/login',
      };
      const client = new FakeSchoolSmsClient([loginPage, rejected]);
      const error = await captureError(async (): Promise<void> => {
        await loginSchoolSsoPassword(client, 'student', 'password');
      });
      expect(error?.message).assertEqual('账号或密码错误');
    });

    it('preserves captcha-required classification for a rejected login page', 0, async () => {
      const loginPage: RcpResponseData = {
        statusCode: 200,
        headers: {},
        bodyText: '<form action="login"><span id="login-page-flowkey">flow</span>' +
          '<span id="login-croypto">MDEyMzQ1Njc4OWFiY2RlZg==</span></form>',
        effectiveUrl: 'https://sso.bit.edu.cn/cas/login',
      };
      const rejected: RcpResponseData = {
        statusCode: 403,
        headers: {},
        bodyText: '<form id="normalLoginForm"><span id="login-page-flowkey">flow</span>' +
          '<div class="captcha">请输入验证码</div></form>',
        effectiveUrl: 'https://sso.bit.edu.cn/cas/login',
      };
      const client = new FakeSchoolSmsClient([loginPage, rejected]);
      const error = await captureError(async (): Promise<void> => {
        await loginSchoolSsoPassword(client, 'student', 'password');
      });
      expect(error?.message).assertEqual('需要验证码');
    });
  });
}
