import { describe, it, expect } from '@ohos/hypium';
import {
  DebugCaseRunResult,
  formatDebugRunnerSummary,
  formatDebugRunnerResult,
} from '../main/ets/debug/DebugRunnerCore';
import { DebugTarget } from '../main/ets/debug/DebugRunner';

export default function debugRunnerContractTest() {
  describe('Debug runner integration contract', () => {
    it('exposes ALL target for full debug sweeps', 0, () => {
      expect(DebugTarget.ALL).assertEqual('ALL');
    });

    it('exposes free classroom target for JW API smoke tests', 0, () => {
      expect(DebugTarget.FREE_CLASSROOM).assertEqual('FREE_CLASSROOM');
    });

    it('exposes Lexue bootstrap target for WebVPN target bootstrap verification', 0, () => {
      expect(DebugTarget.LEXUE_BOOTSTRAP).assertEqual('LEXUE_BOOTSTRAP');
    });

    it('formats summary lines with passed and failed counts', 0, () => {
      const results: DebugCaseRunResult[] = [
        {
          target: 'EXAMPLE',
          name: 'Example debug case',
          passed: true,
          durationMs: 5,
          errorMessage: '',
        },
        {
          target: 'SCHOOL_NETWORK_PROBE',
          name: 'School network probe',
          passed: false,
          durationMs: 7,
          errorMessage: 'connect timeout',
        },
      ];

      const summary = formatDebugRunnerSummary('ALL', results);

      expect(summary).assertEqual('[DebugRunner] SUMMARY target=ALL total=2 passed=1 failed=1 duration=12ms');
    });

    it('formats result lines for log parsing', 0, () => {
      const result: DebugCaseRunResult = {
        target: 'EXAMPLE',
        name: 'Example debug case',
        passed: true,
        durationMs: 5,
        errorMessage: '',
      };

      expect(formatDebugRunnerResult(result)).assertEqual('[DebugRunner] RESULT PASS EXAMPLE "Example debug case" duration=5ms');
    });
  });
}
