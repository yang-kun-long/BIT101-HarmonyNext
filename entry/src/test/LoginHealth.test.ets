import { describe, it, expect } from '@ohos/hypium';
import {
  buildLoginHealthSummary,
  doOperationRequiresLogin,
  LoginDomainHealth,
  LoginHealthRequirement,
  LoginHealthSummary,
  shouldClearLoginDomain,
} from '../main/ets/services/auth/LoginHealthService';
import {
  AccountDisplayModel,
  AccountLoginActionItem,
  buildAccountLoginActionItem,
  buildAccountDisplayModel,
  buildAccountDisplayModelFromCurrentUser,
  hasAccountDisplayProfile,
  resolveAccountDisplaySid,
} from '../main/ets/services/auth/AccountDisplayModel';
import { ApiError } from '../main/ets/core/network/httpClient';
import {
  classifyAuthFailure,
} from '../main/ets/services/auth/AuthFailure';
import {
  SmsChallengeCancelledError,
  SmsChallengeInteractionRequiredError,
  SmsChallengeTimeoutError,
} from '../main/ets/services/auth/SmsChallengeCoordinator';

export default function loginHealthTest() {
  describe('Login health service', () => {
    it('restores explicit school expiry then retries the operation once', 0, async () => {
      let calls = 0; let checks = 0; let refreshes = 0;
      const result = await doOperationRequiresLogin<string>(async () => {
        calls++; if (calls === 1) throw new Error('expired'); return 'ok';
      }, async () => {
        checks++; return buildLoginHealthSummary(
          { ok: true, status: 'valid', message: '' },
          { ok: checks > 1, status: checks > 1 ? 'valid' : 'invalid', message: '' });
      }, 'core', async () => { refreshes++; return 'SUCCESS'; });
      expect(result).assertEqual('ok'); expect(calls).assertEqual(2); expect(refreshes).assertEqual(1);
    });
    it('never refreshes unknown network state or clears it on BUSY', 0, async () => {
      let refreshes = 0; let calls = 0;
      try { await doOperationRequiresLogin<string>(async () => { calls++; throw new Error('offline'); },
        async () => buildLoginHealthSummary({ ok: true, status: 'valid', message: '' },
          { ok: false, status: 'unknown', message: '' }), 'core',
        async () => { refreshes++; return 'BUSY'; }); } catch (_) {}
      expect(calls).assertEqual(1); expect(refreshes).assertEqual(0);
    });

    it('classifies authentication failures for UI and retry policy', 0, () => {
      expect(classifyAuthFailure(new ApiError('unauthorized', 401))).assertEqual('invalid_credentials');
      expect(classifyAuthFailure(new ApiError('too many requests', 429))).assertEqual('rate_limited');
      expect(classifyAuthFailure(new ApiError('server failed', 503))).assertEqual('server_transient');
      expect(classifyAuthFailure(new Error('请输入短信动态码'))).assertEqual('sms_required');
      expect(classifyAuthFailure(new Error('需要图片验证码'))).assertEqual('captcha_required');
      expect(classifyAuthFailure(new Error('2300007 connection failed'))).assertEqual('network_transient');
      expect(classifyAuthFailure(new SmsChallengeInteractionRequiredError())).assertEqual('interaction_required');
      expect(classifyAuthFailure(new SmsChallengeCancelledError())).assertEqual('interaction_cancelled');
      expect(classifyAuthFailure(new SmsChallengeTimeoutError())).assertEqual('interaction_timeout');
      const smsRejected = new Error('验证码错误或已失效');
      smsRejected.name = 'SchoolSmsVerificationError';
      expect(classifyAuthFailure(smsRejected)).assertEqual('sms_required');
    });

    it('reports transient core health failures as unknown without claiming logout', 0, () => {
      const summary: LoginHealthSummary = buildLoginHealthSummary(
        { ok: false, status: 'unknown', message: 'BIT101 状态暂时无法确认' },
        { ok: true, status: 'valid', message: '学校登录态有效' },
      );

      expect(summary.ok).assertFalse();
      expect(summary.statusText).assertEqual('状态未知');
      expect(summary.toastText).assertEqual('网络异常，登录状态未改变');
      expect(shouldClearLoginDomain(summary.bit101)).assertFalse();
      expect(shouldClearLoginDomain({
        ok: false,
        status: 'invalid',
        message: 'BIT101 登录态不可用',
      })).assertTrue();
    });

    it('reports success only when BIT101 and school sessions are both available', 0, () => {
      const bit101: LoginDomainHealth = {
        ok: true,
        message: 'BIT101 登录态有效',
      };
      const school: LoginDomainHealth = {
        ok: true,
        message: '学校登录态有效',
      };

      const jxzx: LoginDomainHealth = {
        ok: true,
        message: '教务应用登录态有效',
      };

      const summary: LoginHealthSummary = buildLoginHealthSummary(bit101, school, jxzx);

      expect(summary.ok).assertTrue();
      expect(summary.statusText).assertEqual('已登录');
      expect(summary.toastText).assertEqual('登录状态检查成功');
    });

    it('reports failure when BIT101 session is invalid even if school session is available', 0, () => {
      const bit101: LoginDomainHealth = {
        ok: false,
        message: 'BIT101 登录态不可用',
      };
      const school: LoginDomainHealth = {
        ok: true,
        message: '学校登录态有效',
      };

      const summary: LoginHealthSummary = buildLoginHealthSummary(bit101, school);

      expect(summary.ok).assertFalse();
      expect(summary.statusText).assertEqual('未登录');
      expect(summary.toastText).assertEqual('登录状态检查失败');
      expect(summary.detail).assertEqual('BIT101 登录态不可用');
    });

    it('reports failure when school session is invalid even if BIT101 session is available', 0, () => {
      const bit101: LoginDomainHealth = {
        ok: true,
        message: 'BIT101 登录态有效',
      };
      const school: LoginDomainHealth = {
        ok: false,
        message: '学校登录态不可用',
      };

      const summary: LoginHealthSummary = buildLoginHealthSummary(bit101, school);

      expect(summary.ok).assertFalse();
      expect(summary.statusText).assertEqual('未登录');
      expect(summary.toastText).assertEqual('登录状态检查失败');
      expect(summary.detail).assertEqual('学校登录态不可用');
    });

    it('reports partial failure when BIT101 and Lexue are available but JXZX is invalid', 0, () => {
      const bit101: LoginDomainHealth = {
        ok: true,
        message: 'BIT101 登录态有效',
      };
      const school: LoginDomainHealth = {
        ok: true,
        message: '乐学登录态有效',
      };
      const jxzx: LoginDomainHealth = {
        ok: false,
        message: '教务应用登录态不可用',
      };

      const summary: LoginHealthSummary = buildLoginHealthSummary(bit101, school, jxzx);

      expect(summary.ok).assertFalse();
      expect(summary.statusText).assertEqual('部分异常');
      expect(summary.toastText).assertEqual('部分登录态异常，请重新登录后再试考试/空教室');
      expect(summary.detail).assertEqual('教务应用登录态不可用');
    });

    it('checks login and retries once when a login-required operation fails', 0, async () => {
      let operationCalls: number = 0;
      let checkCalls: number = 0;
      const successSummary: LoginHealthSummary = buildLoginHealthSummary(
        { ok: true, message: 'BIT101 登录态有效' },
        { ok: true, message: '学校登录态有效' },
      );

      const result: string = await doOperationRequiresLogin<string>(
        async (): Promise<string> => {
          operationCalls += 1;
          if (operationCalls === 1) {
            throw new Error('network rejected stale session');
          }
          return 'retried result';
        },
        async (): Promise<LoginHealthSummary> => {
          checkCalls += 1;
          return successSummary;
        },
      );

      expect(result).assertEqual('retried result');
      expect(operationCalls).assertEqual(2);
      expect(checkCalls).assertEqual(1);
    });

    it('throws check login failed when retry is not allowed by health check', 0, async () => {
      let operationCalls: number = 0;
      const failedSummary: LoginHealthSummary = buildLoginHealthSummary(
        { ok: false, message: 'BIT101 登录态不可用' },
        { ok: true, message: '学校登录态有效' },
      );
      let errorMessage: string = '';

      try {
        await doOperationRequiresLogin<string>(
          async (): Promise<string> => {
            operationCalls += 1;
            throw new Error('first failure');
          },
          async (): Promise<LoginHealthSummary> => failedSummary,
        );
      } catch (error) {
        errorMessage = error instanceof Error ? error.message : String(error);
      }

      expect(operationCalls).assertEqual(1);
      expect(errorMessage).assertEqual('check login failed');
    });

    it('retries core operations when only JXZX is unavailable', 0, async () => {
      let operationCalls: number = 0;
      const partialSummary: LoginHealthSummary = buildLoginHealthSummary(
        { ok: true, message: 'BIT101 登录态有效' },
        { ok: true, message: '学校登录态有效' },
        { ok: false, message: '教务应用登录态不可用' },
      );
      const requirement: LoginHealthRequirement = 'core';

      const result: string = await doOperationRequiresLogin<string>(
        async (): Promise<string> => {
          operationCalls += 1;
          if (operationCalls === 1) {
            throw new Error('lexue transient failure');
          }
          return 'core result';
        },
        async (): Promise<LoginHealthSummary> => partialSummary,
        requirement,
      );

      expect(result).assertEqual('core result');
      expect(operationCalls).assertEqual(2);
    });

    it('does not retry JXZX operations when JXZX is unavailable', 0, async () => {
      let operationCalls: number = 0;
      const partialSummary: LoginHealthSummary = buildLoginHealthSummary(
        { ok: true, message: 'BIT101 登录态有效' },
        { ok: true, message: '学校登录态有效' },
        { ok: false, message: '教务应用登录态不可用' },
      );
      let errorMessage: string = '';

      try {
        await doOperationRequiresLogin<string>(
          async (): Promise<string> => {
            operationCalls += 1;
            throw new Error('jxzx rejected stale session');
          },
          async (): Promise<LoginHealthSummary> => partialSummary,
          'jxzx',
        );
      } catch (error) {
        errorMessage = error instanceof Error ? error.message : String(error);
      }

      expect(operationCalls).assertEqual(1);
      expect(errorMessage).assertEqual('教务应用登录态不可用，请重新登录后再试');
    });

    it('does not invent a mock sid when account storage has no sid', 0, () => {
      const sid: string = resolveAccountDisplaySid('', null);

      expect(sid).assertEqual('');
    });

    it('uses current username before user info sid on account page', 0, () => {
      const sid: string = resolveAccountDisplaySid(' 3220240001 ', { sid: '1120202222' });

      expect(sid).assertEqual('3220240001');
    });

    it('uses persisted username before user info sid on account page', 0, () => {
      const sid: string = resolveAccountDisplaySid('', { sid: '1120202222' }, ' 3220240001 ');

      expect(sid).assertEqual('3220240001');
    });

    it('restores account page profile fields from stored user info', 0, () => {
      const model: AccountDisplayModel = buildAccountDisplayModel('3220240001', {
        sid: '1120202222',
        id: 13482,
        nickname: 'BIT101-732f57d6',
        avatar: { url: 'https://example.com/avatar.png' },
        motto: '行胜于言',
      });

      expect(model.sid).assertEqual('3220240001');
      expect(model.user.id).assertEqual('13482');
      expect(model.user.nickname).assertEqual('BIT101-732f57d6');
      expect(model.user.avatar).assertEqual('https://example.com/avatar.png');
      expect(model.motto).assertEqual('行胜于言');
    });

    it('supports string avatar from stored user info', 0, () => {
      const model: AccountDisplayModel = buildAccountDisplayModel('', {
        id: '42',
        nickname: 'Alice',
        avatar: '/avatar.png',
      });

      expect(model.user.avatar).assertEqual('/avatar.png');
    });

    it('detects missing account display profile', 0, () => {
      const model: AccountDisplayModel = buildAccountDisplayModel('3220240001', null);

      expect(hasAccountDisplayProfile(model)).assertFalse();
    });

    it('maps current BIT101 user response to account display model', 0, () => {
      const model: AccountDisplayModel = buildAccountDisplayModelFromCurrentUser('3220240001', {
        user: {
          id: 13482,
          create_time: '2025-03-09',
          nickname: 'BIT101-732f57d6',
          avatar: {
            mid: '',
            url: 'https://example.com/current.png',
            low_url: '',
          },
          motto: 'Moon',
          identity: {
            id: 1,
            color: '#000000',
            text: '普通用户',
          },
        },
        following_num: 0,
        follower_num: 0,
        following: false,
        follower: false,
        own: true,
      });

      expect(model.sid).assertEqual('3220240001');
      expect(model.user.id).assertEqual('13482');
      expect(model.user.nickname).assertEqual('BIT101-732f57d6');
      expect(model.user.avatar).assertEqual('https://example.com/current.png');
      expect(model.motto).assertEqual('Moon');
    });

    it('shows relogin action when account status is partial', 0, () => {
      const item: AccountLoginActionItem = buildAccountLoginActionItem(true, '部分异常');

      expect(item.kind).assertEqual('relogin');
      expect(item.title).assertEqual('重新登录');
      expect(item.subTitle).assertEqual('重新建立教务应用登录态，用于考试和空教室');
    });

    it('keeps logout action when account status is fully logged in', 0, () => {
      const item: AccountLoginActionItem = buildAccountLoginActionItem(true, '已登录');

      expect(item.kind).assertEqual('logout');
      expect(item.title).assertEqual('退出登录');
    });
  });
}
