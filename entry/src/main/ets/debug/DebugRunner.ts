// entry/src/main/ets/debug/DebugRunner.ts
import { BitSsoLexueCase } from './BitSsoLexueCase';
import { BitSsoSessionCase } from './BitSsoSessionCase';
import { ExampleDebugCase } from './ExampleDebugCase';  // ⬅️ 新增
import { DebugCase } from './DebugCase';
import { LexueCookiePersistCase } from './LexueCookiePersistCase';
import { LexueCalendarSyncCase } from './LexueCalendarSyncCase';
import { LexueCalendarFastPathCase } from './LexueCalendarFastPathCase';
import BitSsoLexueWebvpnCase from './BitSsoLexueWebvpnCase';
import { MapDebugCase } from './MapDebugCase';
import { GalleryServiceCase } from './GalleryServiceCase'
import { SchoolWebvpnPortalCase } from './SchoolWebvpnPortalCase';
import { SchoolLexueWebvpnCase } from './SchoolLexueWebvpnCase';
import { TimetableWebvpnCase } from './TimetableWebvpnCase';
import { WebvpnLexueRestoreCase } from './WebvpnLexueRestoreCase';
import { SchoolNetworkProbeCase } from './SchoolNetworkProbeCase';
import { LexueDdlExtractionCase } from './LexueDdlExtractionCase';
import { FreeClassroomCase } from './FreeClassroomCase';
import { CourseScheduleSettingsCase } from './CourseScheduleSettingsCase';
import { CourseScheduleSyncCase } from './CourseScheduleSyncCase';
import { LoginHealthCase } from './LoginHealthCase';
import { DebugLog } from './DebugLog';
import {
  DebugCaseRunResult,
  errorToMessage,
  formatDebugRunnerFail,
  formatDebugRunnerPass,
  formatDebugRunnerResult,
  formatDebugRunnerResultError,
  formatDebugRunnerSummary,
} from './DebugRunnerCore';

const logger = new DebugLog('DebugRunner');

export enum DebugTarget {
  NONE = 'NONE',
  ALL = 'ALL',
  BIT_SSO_LEXUE = 'BIT_SSO_LEXUE',
  BIT_SSO_SESSION = 'BIT_SSO_SESSION',
  EXAMPLE = 'EXAMPLE',  // ⬅️ 新增示范用枚举
  LEXUE_COOKIE_PERSIST = 'LEXUE_COOKIE_PERSIST',
  LEXUE_CALENDAR_SYNC = 'LEXUE_CALENDAR_SYNC',
  LEXUE_CALENDAR_FASTPATH = 'LEXUE_CALENDAR_FASTPATH',
  BIT_SSO_LEXUE_WEBVPN = 'BIT_SSO_LEXUE_WEBVPN',
  MAP = 'MAP',
  GALLERY_SERVICE = 'GALLERY_SERVICE',
  SCHOOL_WEBVPN_PORTAL = 'SCHOOL_WEBVPN_PORTAL',
  SCHOOL_LEXUE_WEBVPN = 'SCHOOL_LEXUE_WEBVPN',
  TIMETABLE_WEBVPN = 'TIMETABLE_WEBVPN',
  WEBVPN_LEXUE_RESTORE = 'WEBVPN_LEXUE_RESTORE',
  SCHOOL_NETWORK_PROBE = 'SCHOOL_NETWORK_PROBE',
  LEXUE_DDL_EXTRACTION = 'LEXUE_DDL_EXTRACTION',
  FREE_CLASSROOM = 'FREE_CLASSROOM',
  COURSE_SCHEDULE_SETTINGS = 'COURSE_SCHEDULE_SETTINGS',
  COURSE_SCHEDULE_SYNC = 'COURSE_SCHEDULE_SYNC',
  LOGIN_HEALTH = 'LOGIN_HEALTH'
}

interface DebugCaseEntry {
  target: DebugTarget;
  create: () => DebugCase;
}

const DEBUG_CASES: DebugCaseEntry[] = [
  { target: DebugTarget.BIT_SSO_LEXUE, create: () => new BitSsoLexueCase() },
  { target: DebugTarget.BIT_SSO_SESSION, create: () => new BitSsoSessionCase() },
  { target: DebugTarget.EXAMPLE, create: () => new ExampleDebugCase() },
  { target: DebugTarget.LEXUE_COOKIE_PERSIST, create: () => new LexueCookiePersistCase() },
  { target: DebugTarget.LEXUE_CALENDAR_SYNC, create: () => new LexueCalendarSyncCase() },
  { target: DebugTarget.LEXUE_CALENDAR_FASTPATH, create: () => new LexueCalendarFastPathCase() },
  { target: DebugTarget.BIT_SSO_LEXUE_WEBVPN, create: () => new BitSsoLexueWebvpnCase() },
  { target: DebugTarget.MAP, create: () => new MapDebugCase() },
  { target: DebugTarget.GALLERY_SERVICE, create: () => new GalleryServiceCase() },
  { target: DebugTarget.SCHOOL_WEBVPN_PORTAL, create: () => new SchoolWebvpnPortalCase() },
  { target: DebugTarget.SCHOOL_LEXUE_WEBVPN, create: () => new SchoolLexueWebvpnCase() },
  { target: DebugTarget.TIMETABLE_WEBVPN, create: () => new TimetableWebvpnCase() },
  { target: DebugTarget.WEBVPN_LEXUE_RESTORE, create: () => new WebvpnLexueRestoreCase() },
  { target: DebugTarget.SCHOOL_NETWORK_PROBE, create: () => new SchoolNetworkProbeCase() },
  { target: DebugTarget.LEXUE_DDL_EXTRACTION, create: () => new LexueDdlExtractionCase() },
  { target: DebugTarget.FREE_CLASSROOM, create: () => new FreeClassroomCase() },
  { target: DebugTarget.COURSE_SCHEDULE_SETTINGS, create: () => new CourseScheduleSettingsCase() },
  { target: DebugTarget.COURSE_SCHEDULE_SYNC, create: () => new CourseScheduleSyncCase() },
  { target: DebugTarget.LOGIN_HEALTH, create: () => new LoginHealthCase() },
];

/**
 * 当前要跑哪个调试用例
 * - 开发/调试时：改成你想跑的那个
 * - 发布正式包：改成 DebugTarget.NONE（或在 EntryAbility 里关掉调试入口）
 * - 自动探活回归：优先跑 DebugTarget.SCHOOL_NETWORK_PROBE
 */
const CURRENT_DEBUG_TARGET: DebugTarget = DebugTarget.SCHOOL_NETWORK_PROBE;
// 你想测别的就改成 DebugTarget.BIT_SSO_SESSION / BIT_SSO_LEXUE 等

function resolveCases(target: DebugTarget): DebugCaseEntry[] {
  if (target === DebugTarget.ALL) {
    return DEBUG_CASES;
  }

  const entries: DebugCaseEntry[] = [];
  for (const entry of DEBUG_CASES) {
    if (entry.target === target) {
      entries.push(entry);
      break;
    }
  }
  return entries;
}

async function runOneCase(entry: DebugCaseEntry): Promise<DebugCaseRunResult> {
  const testCase = entry.create();
  const startTime = Date.now();
  logger.info(`[DebugRunner] Running debug case: ${testCase.name}`);

  try {
    await testCase.run();
    const durationMs = Date.now() - startTime;
    const result: DebugCaseRunResult = {
      target: entry.target,
      name: testCase.name,
      passed: true,
      durationMs,
      errorMessage: '',
    };
    logger.info(formatDebugRunnerPass(result));
    return result;
  } catch (error) {
    const durationMs = Date.now() - startTime;
    const result: DebugCaseRunResult = {
      target: entry.target,
      name: testCase.name,
      passed: false,
      durationMs,
      errorMessage: errorToMessage(error as Error),
    };
    logger.error(formatDebugRunnerFail(result));
    return result;
  }
}

function logSummary(target: DebugTarget, results: DebugCaseRunResult[]): void {
  logger.info(formatDebugRunnerSummary(target, results));

  for (const result of results) {
    logger.info(formatDebugRunnerResult(result));
    if (!result.passed) {
      logger.error(formatDebugRunnerResultError(result));
    }
  }
}

export async function runDebugCases(target: DebugTarget): Promise<DebugCaseRunResult[]> {
  if (target === DebugTarget.NONE) {
    logger.info('[DebugRunner] No debug case selected.');
    return [];
  }

  const entries = resolveCases(target);
  if (entries.length === 0) {
    logger.error(`[DebugRunner] Unknown debug target: ${target}`);
    return [];
  }

  logger.info(`[DebugRunner] START target=${target} caseCount=${entries.length}`);
  const results: DebugCaseRunResult[] = [];

  for (const entry of entries) {
    const result = await runOneCase(entry);
    results.push(result);
  }

  logSummary(target, results);
  logger.info(`[DebugRunner] END target=${target}`);
  return results;
}

export async function runCurrentDebugCase(): Promise<void> {
  await runDebugCases(CURRENT_DEBUG_TARGET);
}
