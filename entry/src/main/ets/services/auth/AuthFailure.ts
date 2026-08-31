import { ApiError } from '../../core/network/httpClient';
import {
  SmsChallengeCancelledError,
  SmsChallengeInteractionRequiredError,
  SmsChallengeTimeoutError,
} from './SmsChallengeCoordinator';

export type AuthFailureKind =
  | 'invalid_credentials'
  | 'sms_required'
  | 'interaction_required'
  | 'interaction_cancelled'
  | 'interaction_timeout'
  | 'captcha_required'
  | 'rate_limited'
  | 'network_transient'
  | 'server_transient';

export class AuthFlowError extends Error {
  readonly kind: AuthFailureKind;

  constructor(kind: AuthFailureKind, message: string, cause?: Error) {
    super(message);
    this.name = 'AuthFlowError';
    this.kind = kind;
    if (cause && cause.stack) {
      this.stack = cause.stack;
    }
  }
}

export function classifyAuthFailure(error: Error): AuthFailureKind {
  if (error instanceof AuthFlowError) {
    return error.kind;
  }
  if (error instanceof SmsChallengeCancelledError) {
    return 'interaction_cancelled';
  }
  if (error instanceof SmsChallengeTimeoutError) {
    return 'interaction_timeout';
  }
  if (error instanceof SmsChallengeInteractionRequiredError) {
    return 'interaction_required';
  }
  if (error.name === 'SchoolSmsVerificationError') {
    return 'sms_required';
  }
  let detail: string = error.message.toLowerCase();
  if (error instanceof ApiError) {
    detail += ' ' + (error.bodyText ?? '').toLowerCase();
    if (error.status === 401 || error.status === 403) {
      return 'invalid_credentials';
    }
    if (error.status === 429) {
      return 'rate_limited';
    }
    if (error.status !== undefined && error.status >= 500) {
      return 'server_transient';
    }
  }

  const text: string = detail;
  if (text.includes('短信') || text.includes('sms') || text.includes('动态码')) {
    return 'sms_required';
  }
  if (text.includes('验证码') || text.includes('captcha')) {
    return 'captcha_required';
  }
  if (
    text.includes('账号') ||
    text.includes('密码') ||
    text.includes('credential') ||
    text.includes('unauthorized') ||
    (error instanceof ApiError && error.status === 400)
  ) {
    return 'invalid_credentials';
  }
  if (
    text.includes('timeout') ||
    text.includes('timed out') ||
    text.includes('dns') ||
    text.includes('network') ||
    text.includes('connection') ||
    text.includes('230000')
  ) {
    return 'network_transient';
  }
  return 'server_transient';
}

export function toAuthFlowError(error: Error): AuthFlowError {
  if (error instanceof AuthFlowError) {
    return error;
  }
  return new AuthFlowError(classifyAuthFailure(error), error.message, error);
}
