import { describe, it, expect } from '@ohos/hypium';
import {
  PendingSmsChallenge,
  SmsChallengeRequest,
  SmsChallengeBusyError,
  SmsChallengeCancelledError,
  SmsChallengeCoordinator,
  SmsChallengeInteractionRequiredError,
  SmsChallengeTimeoutError,
} from '../main/ets/services/auth/SmsChallengeCoordinator';

const REQUEST: SmsChallengeRequest = {
  phone: '13800000000',
  maskedPhone: '138****0000',
  purpose: 'password_second_factor',
};

async function captureError(action: () => Promise<void>): Promise<Error | null> {
  try {
    await action();
  } catch (error) {
    return error instanceof Error ? error : new Error(String(error));
  }
  return null;
}

export default function smsChallengeCoordinatorTest() {
  describe('SmsChallengeCoordinator', () => {
    it('publishes only UI-safe fields and resolves a trimmed code', 0, async () => {
      const coordinator = new SmsChallengeCoordinator();
      const observed: Array<PendingSmsChallenge | null> = [];
      coordinator.subscribe((pending: PendingSmsChallenge | null): void => {
        observed.push(pending);
      });

      const codePromise = coordinator.createHandler({ timeoutMs: 0 })(REQUEST);
      const pending = coordinator.getPending();

      expect(pending !== null).assertTrue();
      expect(pending?.maskedPhone).assertEqual('138****0000');
      expect(pending?.purpose).assertEqual('password_second_factor');
      expect(Object.keys(pending as PendingSmsChallenge).includes('phone')).assertFalse();
      expect(coordinator.submit(pending?.id ?? 0, ' 123456 ')).assertTrue();
      expect(await codePromise).assertEqual('123456');
      expect(coordinator.getPending()).assertNull();
      expect(observed.length).assertEqual(3);
    });

    it('rejects cancellation and ignores repeated settlement', 0, async () => {
      const coordinator = new SmsChallengeCoordinator();
      const codePromise = coordinator.createHandler({ timeoutMs: 0 })(REQUEST);
      const id = coordinator.getPending()?.id ?? 0;

      expect(coordinator.cancel(id)).assertTrue();
      expect(coordinator.cancel(id)).assertFalse();
      expect(coordinator.submit(id, '123456')).assertFalse();
      const error = await captureError(async (): Promise<void> => {
        await codePromise;
      });
      expect(error instanceof SmsChallengeCancelledError).assertTrue();
    });

    it('keeps the request pending when an empty code is submitted', 0, async () => {
      const coordinator = new SmsChallengeCoordinator();
      const codePromise = coordinator.createHandler({ timeoutMs: 0 })(REQUEST);
      const id = coordinator.getPending()?.id ?? 0;

      expect(coordinator.submit(id, '   ')).assertFalse();
      expect(coordinator.getPending()?.id).assertEqual(id);
      expect(coordinator.submit(id, '654321')).assertTrue();
      expect(await codePromise).assertEqual('654321');
    });

    it('rejects a concurrent request without replacing the first', 0, async () => {
      const coordinator = new SmsChallengeCoordinator();
      const first = coordinator.createHandler({ timeoutMs: 0 })(REQUEST);
      const firstId = coordinator.getPending()?.id ?? 0;

      const secondError = await captureError(async (): Promise<void> => {
        await coordinator.createHandler({ timeoutMs: 0 })(REQUEST);
      });
      expect(secondError instanceof SmsChallengeBusyError).assertTrue();
      expect(coordinator.getPending()?.id).assertEqual(firstId);
      coordinator.submit(firstId, '123456');
      await first;
    });

    it('fails immediately when background work disallows interaction', 0, async () => {
      const coordinator = new SmsChallengeCoordinator();
      const error = await captureError(async (): Promise<void> => {
        await coordinator.createHandler({ allowInteractive: false })(REQUEST);
      });

      expect(error instanceof SmsChallengeInteractionRequiredError).assertTrue();
      expect(coordinator.getPending()).assertNull();
    });

    it('expires a pending request', 0, async () => {
      const coordinator = new SmsChallengeCoordinator();
      const error = await captureError(async (): Promise<void> => {
        await coordinator.createHandler({ timeoutMs: 1 })(REQUEST);
      });

      expect(error instanceof SmsChallengeTimeoutError).assertTrue();
      expect(coordinator.getPending()).assertNull();
    });

    it('routes a pending request only to the topmost registered host', 0, async () => {
      const coordinator = new SmsChallengeCoordinator();
      const firstEvents: string[] = [];
      const secondEvents: string[] = [];
      coordinator.registerHost((pending: PendingSmsChallenge | null): void => {
        firstEvents.push(pending ? `pending:${pending.id}` : 'none');
      });
      const unregisterSecond = coordinator.registerHost((pending: PendingSmsChallenge | null): void => {
        secondEvents.push(pending ? `pending:${pending.id}` : 'none');
      });

      const codePromise = coordinator.createHandler({ timeoutMs: 0 })(REQUEST);
      const id = coordinator.getPending()?.id ?? 0;
      expect(firstEvents.join('|')).assertEqual('none|none');
      expect(secondEvents.join('|')).assertEqual(`none|pending:${id}`);

      unregisterSecond();
      expect(firstEvents.join('|')).assertEqual(`none|none|pending:${id}`);
      coordinator.submit(id, '123456');
      expect(await codePromise).assertEqual('123456');
      expect(firstEvents.join('|')).assertEqual(`none|none|pending:${id}|none`);
    });
  });
}
