/**
 * School SSO SMS challenge bridge.
 *
 * The network layer only needs a suspending callback.  The UI observes this
 * coordinator and completes the one request currently waiting for input.
 */

export type SmsChallengePurpose = 'password_second_factor' | 'phone_primary_login' | string;

export interface SmsChallengeRequest {
  /** Kept for the school protocol; never exposed by PendingSmsChallenge. */
  phone: string;
  maskedPhone: string;
  purpose: SmsChallengePurpose;
}

export interface SmsCodeHandlerOptions {
  allowInteractive?: boolean;
  timeoutMs?: number;
}

export type SmsCodeHandler = (request: SmsChallengeRequest) => Promise<string>;
export type SmsChallengeListener = (pending: PendingSmsChallenge | null) => void;

export class SmsChallengeInteractionRequiredError extends Error {
  constructor() {
    super('SMS verification requires foreground interaction');
    this.name = 'SmsChallengeInteractionRequiredError';
  }
}

export class SmsChallengeBusyError extends Error {
  constructor() {
    super('Another SMS verification request is already pending');
    this.name = 'SmsChallengeBusyError';
  }
}

export class SmsChallengeCancelledError extends Error {
  constructor() {
    super('SMS verification was cancelled');
    this.name = 'SmsChallengeCancelledError';
  }
}

export class SmsChallengeValidationError extends Error {
  constructor() {
    super('SMS verification code is empty');
    this.name = 'SmsChallengeValidationError';
  }
}

export class SmsChallengeTimeoutError extends Error {
  constructor() {
    super('SMS verification timed out');
    this.name = 'SmsChallengeTimeoutError';
  }
}

/** UI-safe view of a request.  The original phone number is intentionally absent. */
export class PendingSmsChallenge {
  readonly id: number;
  readonly maskedPhone: string;
  readonly purpose: SmsChallengePurpose;
  private readonly resolveCode: (code: string) => void;
  private readonly rejectCode: (error: Error) => void;
  private settled: boolean = false;

  constructor(
    id: number,
    request: SmsChallengeRequest,
    resolveCode: (code: string) => void,
    rejectCode: (error: Error) => void,
  ) {
    this.id = id;
    this.maskedPhone = request.maskedPhone;
    this.purpose = request.purpose;
    this.resolveCode = resolveCode;
    this.rejectCode = rejectCode;
  }

  submit(code: string): boolean {
    if (this.settled) return false;
    const normalized = code.trim();
    if (!normalized) {
      throw new SmsChallengeValidationError();
    }
    this.settled = true;
    this.resolveCode(normalized);
    return true;
  }

  cancel(): boolean {
    if (this.settled) return false;
    this.settled = true;
    this.rejectCode(new SmsChallengeCancelledError());
    return true;
  }

  expire(): boolean {
    if (this.settled) return false;
    this.settled = true;
    this.rejectCode(new SmsChallengeTimeoutError());
    return true;
  }
}

interface PendingInternal {
  pending: PendingSmsChallenge;
  promise: Promise<string>;
  timeoutHandle?: number;
}

interface SmsChallengeHostRegistration {
  id: number;
  listener: SmsChallengeListener;
}

export class SmsChallengeCoordinator {
  private nextId: number = 1;
  private current: PendingInternal | null = null;
  private listeners: Array<SmsChallengeListener> = [];
  private nextHostId: number = 1;
  private hosts: Array<SmsChallengeHostRegistration> = [];

  getPending(): PendingSmsChallenge | null {
    return this.current?.pending ?? null;
  }

  subscribe(listener: SmsChallengeListener): () => void {
    this.listeners.push(listener);
    listener(this.getPending());
    return (): void => {
      this.listeners = this.listeners.filter((item: SmsChallengeListener): boolean => item !== listener);
    };
  }

  registerHost(listener: SmsChallengeListener): () => void {
    const previous = this.hosts.length > 0 ? this.hosts[this.hosts.length - 1] : null;
    previous?.listener(null);
    const registration: SmsChallengeHostRegistration = {
      id: this.nextHostId,
      listener,
    };
    this.nextHostId += 1;
    this.hosts.push(registration);
    listener(this.getPending());
    return (): void => this.unregisterHost(registration.id);
  }

  createHandler(options?: SmsCodeHandlerOptions): SmsCodeHandler {
    const allowInteractive = options?.allowInteractive !== false;
    const timeoutMs = options?.timeoutMs ?? 120000;
    return async (request: SmsChallengeRequest): Promise<string> => {
      if (!allowInteractive) {
        throw new SmsChallengeInteractionRequiredError();
      }
      if (this.current !== null) {
        throw new SmsChallengeBusyError();
      }
      return this.waitForCode(request, timeoutMs);
    };
  }

  submit(id: number, code: string): boolean {
    const current = this.current;
    if (!current || current.pending.id !== id) return false;
    try {
      return current.pending.submit(code);
    } catch (error) {
      if (error instanceof SmsChallengeValidationError) return false;
      throw error;
    }
  }

  cancel(id: number): boolean {
    const current = this.current;
    if (!current || current.pending.id !== id) return false;
    return current.pending.cancel();
  }

  private waitForCode(request: SmsChallengeRequest, timeoutMs: number): Promise<string> {
    let resolveCode: (code: string) => void = (): void => {};
    let rejectCode: (error: Error) => void = (): void => {};
    const promise = new Promise<string>((resolve: (code: string) => void, reject: (error: Error) => void) => {
      resolveCode = resolve;
      rejectCode = reject;
    });
    const pending = new PendingSmsChallenge(this.nextId, request, resolveCode, rejectCode);
    this.nextId += 1;
    const internal: PendingInternal = { pending, promise };
    this.current = internal;
    if (timeoutMs > 0) {
      internal.timeoutHandle = setTimeout(() => {
        if (this.current !== internal) return;
        pending.expire();
      }, timeoutMs);
    }
    this.notify();

    const cleanup = (): void => {
      if (internal.timeoutHandle !== undefined) {
        clearTimeout(internal.timeoutHandle);
      }
      if (this.current === internal) {
        this.current = null;
        this.notify();
      }
    };
    promise.then(cleanup, cleanup);
    return promise;
  }

  private notify(): void {
    const pending = this.getPending();
    this.listeners.forEach((listener: SmsChallengeListener): void => listener(pending));
    if (this.hosts.length > 0) {
      this.hosts[this.hosts.length - 1].listener(pending);
    }
  }

  private unregisterHost(id: number): void {
    const top = this.hosts.length > 0 ? this.hosts[this.hosts.length - 1] : null;
    const wasTop = top?.id === id;
    if (wasTop) {
      top?.listener(null);
    }
    this.hosts = this.hosts.filter(
      (registration: SmsChallengeHostRegistration): boolean => registration.id !== id,
    );
    if (wasTop && this.hosts.length > 0) {
      this.hosts[this.hosts.length - 1].listener(this.getPending());
    }
  }
}

export const globalSmsChallengeCoordinator = new SmsChallengeCoordinator();
