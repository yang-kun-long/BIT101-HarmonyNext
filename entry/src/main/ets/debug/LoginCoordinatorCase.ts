import { DebugCase } from './DebugCase';
import { loadDebugCredentials } from './DebugCredentials';
import { LoginCoordinator, LoginCoordinatorResult } from '../services/auth/LoginCoordinator';
import {
  globalSmsChallengeCoordinator,
  PendingSmsChallenge,
} from '../services/auth/SmsChallengeCoordinator';

export class LoginCoordinatorCase extends DebugCase {
  readonly name = 'Login coordinator full flow';

  async run(): Promise<void> {
    const { TEST_USERNAME, TEST_PASSWORD } = loadDebugCredentials();
    this.logInfo('=== LoginCoordinatorCase START ===');

    if (!TEST_USERNAME || !TEST_PASSWORD) {
      this.fail('Missing TEST_USERNAME / TEST_PASSWORD in debug-credentials.json');
    }

    const unsubscribe = globalSmsChallengeCoordinator.subscribe(
      (pending: PendingSmsChallenge | null): void => {
        if (pending) {
          this.logInfo(
            'waiting for SMS verification',
            'purpose =',
            pending.purpose,
            'maskedPhone =',
            pending.maskedPhone,
          );
        }
      },
    );
    let result: LoginCoordinatorResult;
    try {
      const coordinator = new LoginCoordinator();
      result = await coordinator.login({
        sid: TEST_USERNAME,
        password: TEST_PASSWORD,
      });
    } finally {
      unsubscribe();
    }

    this.logInfo(
      'result ok =',
      result.ok,
      'bit101Ok =',
      result.bit101Ok,
      'schoolOk =',
      result.schoolOk,
      'mode =',
      result.mode,
      'syncedCalendarCount =',
      result.syncedCalendarCount,
      'bit101WebvpnOk =',
      result.bit101.webvpn.ok,
      'bit101WebvpnStatus =',
      result.bit101.webvpn.status,
    );

    this.assertTrue(result.bit101Ok, 'BIT101 login should succeed');
    this.assertTrue(result.schoolOk, 'school login should succeed');
    this.assertTrue(result.ok, 'coordinator login should succeed');

    this.logInfo('=== LoginCoordinatorCase END ===');
  }
}
