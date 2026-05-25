export interface DebugCaseRunResult {
  target: string;
  name: string;
  passed: boolean;
  durationMs: number;
  errorMessage: string;
}

export function errorToMessage(error: Error | Object | string | number | boolean | null | undefined): string {
  if (error instanceof Error) {
    return `${error.message}\n${error.stack}`;
  }

  if (typeof error === 'object') {
    try {
      return JSON.stringify(error);
    } catch (e) {
      return String(error);
    }
  }

  return String(error);
}

export function formatDebugRunnerPass(result: DebugCaseRunResult): string {
  return `[DebugRunner] PASS ${result.target} "${result.name}" in ${result.durationMs}ms`;
}

export function formatDebugRunnerFail(result: DebugCaseRunResult): string {
  return `[DebugRunner] FAIL ${result.target} "${result.name}" in ${result.durationMs}ms ${result.errorMessage}`;
}

export function formatDebugRunnerSummary(target: string, results: DebugCaseRunResult[]): string {
  let passed = 0;
  let failed = 0;
  let totalDurationMs = 0;

  for (const result of results) {
    totalDurationMs += result.durationMs;
    if (result.passed) {
      passed++;
    } else {
      failed++;
    }
  }

  return `[DebugRunner] SUMMARY target=${target} total=${results.length} passed=${passed} failed=${failed} duration=${totalDurationMs}ms`;
}

export function formatDebugRunnerResult(result: DebugCaseRunResult): string {
  const status = result.passed ? 'PASS' : 'FAIL';
  return `[DebugRunner] RESULT ${status} ${result.target} "${result.name}" duration=${result.durationMs}ms`;
}

export function formatDebugRunnerResultError(result: DebugCaseRunResult): string {
  return `[DebugRunner] RESULT_ERROR ${result.target} ${result.errorMessage}`;
}
