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
import { Logger } from '../utils/Logger';

const logger = new Logger('DebugRunner');

export enum DebugTarget {
  NONE = 'NONE',
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
  SCHOOL_NETWORK_PROBE = 'SCHOOL_NETWORK_PROBE'
}

/**
 * 当前要跑哪个调试用例
 * - 开发/调试时：改成你想跑的那个
 * - 发布正式包：改成 DebugTarget.NONE（或在 EntryAbility 里关掉调试入口）
 * - 自动探活回归：优先跑 DebugTarget.SCHOOL_NETWORK_PROBE
 */
const CURRENT_DEBUG_TARGET: DebugTarget = DebugTarget.SCHOOL_NETWORK_PROBE;
// 你想测别的就改成 DebugTarget.BIT_SSO_SESSION / BIT_SSO_LEXUE 等

function createCase(target: DebugTarget): DebugCase | null {
  switch (target) {
    case DebugTarget.BIT_SSO_LEXUE:
      return new BitSsoLexueCase();
    case DebugTarget.BIT_SSO_SESSION:
      return new BitSsoSessionCase();
    case DebugTarget.EXAMPLE:
      return new ExampleDebugCase();
    case DebugTarget.LEXUE_COOKIE_PERSIST:
      return new LexueCookiePersistCase();
    case DebugTarget.LEXUE_CALENDAR_SYNC:
      return new LexueCalendarSyncCase();
    case DebugTarget.LEXUE_CALENDAR_FASTPATH:
      return new LexueCalendarFastPathCase();
    case DebugTarget.BIT_SSO_LEXUE_WEBVPN:
      return new BitSsoLexueWebvpnCase();
    case DebugTarget.MAP:
      return new MapDebugCase();
    case DebugTarget.GALLERY_SERVICE:
      return new GalleryServiceCase();
    case DebugTarget.SCHOOL_WEBVPN_PORTAL:
      return new SchoolWebvpnPortalCase();
    case DebugTarget.SCHOOL_LEXUE_WEBVPN:
      return new SchoolLexueWebvpnCase();
    case DebugTarget.TIMETABLE_WEBVPN:
      return new TimetableWebvpnCase();
    case DebugTarget.WEBVPN_LEXUE_RESTORE:
      return new WebvpnLexueRestoreCase();
    case DebugTarget.SCHOOL_NETWORK_PROBE:
      return new SchoolNetworkProbeCase();
    case DebugTarget.NONE:
    default:
      return null;
  }
}

export async function runCurrentDebugCase(): Promise<void> {
  const testCase = createCase(CURRENT_DEBUG_TARGET);
  if (!testCase) return;

  logger.info('Running debug case:', testCase.name);
  await testCase.run();
}
