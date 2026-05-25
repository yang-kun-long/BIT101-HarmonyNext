import RcpSession, { RcpResponseData } from '../../core/network/rcpSession';
import SimpleCookieJar, { CookieDump } from '../../core/network/cookieJar';
import { Logger } from '../../utils/Logger';
import { LexueCookieStore } from '../storage/LexueCookieStore';
import { SchoolCookieStore } from '../storage/SchoolCookieStore';
import type { SchoolLoginMode } from '../school/SchoolAuthTypes';
import type { PeriodTime } from './periodTimes';

const logger = new Logger('FreeClassroom');

export const JXZXEHALLAPP_WEBVPN_BASE =
  'https://webvpn.bit.edu.cn/https/77726476706e69737468656265737421faef5b842238695c720999bcd6572a216b231105adc27d';
export const JXZXEHALLAPP_INNER_BASE = 'https://jxzxehallapp.bit.edu.cn';

const USER_AGENT =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36';

export interface CampusInfo {
  displayName: string;
  code: string;
}

export interface BuildingInfo {
  buildingName: string;
  buildingIndex: string;
  campusName: string;
  campusCode: string;
}

export interface ClassroomInfo {
  classroomName: string;
  busyTimeStr: string | null;
}

export interface PeriodRange {
  start: number;
  end: number;
}

export interface FreeClassroomQuery {
  termCode: string;
  buildingId: string;
  date: string;
  periods: number[];
}

export interface ClassroomQueryParams {
  XQDM: string;
  JXLDM: string;
  RQ: string;
  XNXQDM: string;
  XNDM: string;
}

export interface FreeClassroomRow {
  classroomName: string;
  busyPeriods: number[];
  freePeriods: number[];
  freePeriodsText: string;
}

export interface ClassroomBusyStatus {
  isFreeNow: boolean;
  statusText: string;
  detailText: string;
  sortKey: number;
}

interface CampusApiRow {
  MC?: string;
  DM?: string;
}

interface CampusApiResponse {
  datas?: {
    ggzdpx?: {
      rows?: CampusApiRow[];
    };
  };
}

interface BuildingApiRow {
  JXLMC?: string;
  JXLDM?: string;
  XXXQDM_DISPLAY?: string;
  XXXQDM?: string;
}

interface BuildingApiResponse {
  datas?: {
    cxjxl?: {
      rows?: BuildingApiRow[];
    };
  };
}

interface ClassroomApiRow {
  JASMC?: string;
  ZYJC?: string | null;
}

interface ClassroomApiResponse {
  datas?: {
    cxkxjasqk?: {
      rows?: ClassroomApiRow[];
    };
  };
}

export interface FreeClassroomRepositoryOptions {
  baseUrl?: string;
  mode?: SchoolLoginMode;
  debug?: boolean;
  cookieDump?: CookieDump;
  timeoutMs?: number;
}

function clampPeriod(n: number): number {
  if (n < 1) return 1;
  if (n > 13) return 13;
  return n;
}

function uniqueSorted(values: number[]): number[] {
  const seen: Record<string, boolean> = {};
  const out: number[] = [];
  for (let i = 0; i < values.length; i++) {
    const n = values[i];
    const key = String(n);
    if (seen[key]) continue;
    seen[key] = true;
    out.push(n);
  }
  out.sort((a: number, b: number) => a - b);
  return out;
}

function parseClockMinutes(text: string): number {
  const parts = text.split(':');
  if (parts.length < 2) return 0;
  const hour = Number(parts[0]);
  const minute = Number(parts[1]);
  if (!Number.isFinite(hour) || !Number.isFinite(minute)) return 0;
  return Math.max(0, Math.min(1439, Math.floor(hour) * 60 + Math.floor(minute)));
}

function formatClockMinutes(minutes: number): string {
  const safe = Math.max(0, Math.min(1439, Math.floor(minutes)));
  const hour = Math.floor(safe / 60);
  const minute = safe % 60;
  return `${hour < 10 ? '0' : ''}${hour}:${minute < 10 ? '0' : ''}${minute}`;
}

function formatDurationSeconds(seconds: number): string {
  const safe = Math.max(0, Math.floor(seconds));
  if (safe < 60) {
    return '< 1 分钟';
  }
  if (safe < 60 * 60) {
    return `${Math.floor(safe / 60)} 分钟`;
  }
  const hours = Math.floor(safe / 3600);
  const minutes = Math.floor(safe / 60) % 60;
  return `${hours} 小时${minutes === 0 ? '' : ` ${minutes} 分钟`}`;
}

function parseJson<T>(text: string, label: string): T {
  try {
    return JSON.parse(text) as T;
  } catch (e) {
    throw new Error(`${label} response is not JSON: ${String(e)}`);
  }
}

function toFormUrlEncoded(fields: Record<string, string>): string {
  const keys = Object.keys(fields);
  const parts: string[] = [];
  for (let i = 0; i < keys.length; i++) {
    const key = keys[i];
    parts.push(encodeURIComponent(key) + '=' + encodeURIComponent(fields[key]));
  }
  return parts.join('&');
}

function assertOk(resp: RcpResponseData, label: string): void {
  if (resp.statusCode < 200 || resp.statusCode >= 300) {
    const preview = (resp.bodyText || '').replace(/\s+/g, ' ').slice(0, 180);
    throw new Error(`${label} HTTP ${resp.statusCode}: ${preview}`);
  }
}

function mapCampusRows(rows: CampusApiRow[]): CampusInfo[] {
  const out: CampusInfo[] = [];
  for (let i = 0; i < rows.length; i++) {
    const row = rows[i];
    const code = row.DM || '';
    const displayName = row.MC || '';
    if (!code && !displayName) continue;
    out.push({ code, displayName });
  }
  return out;
}

function mapBuildingRows(rows: BuildingApiRow[]): BuildingInfo[] {
  const out: BuildingInfo[] = [];
  for (let i = 0; i < rows.length; i++) {
    const row = rows[i];
    const buildingIndex = row.JXLDM || '';
    const buildingName = row.JXLMC || '';
    if (!buildingIndex && !buildingName) continue;
    out.push({
      buildingName,
      buildingIndex,
      campusName: row.XXXQDM_DISPLAY || '',
      campusCode: row.XXXQDM || '',
    });
  }
  return out;
}

function mapClassroomRows(rows: ClassroomApiRow[]): ClassroomInfo[] {
  const out: ClassroomInfo[] = [];
  for (let i = 0; i < rows.length; i++) {
    const row = rows[i];
    const classroomName = row.JASMC || '';
    if (!classroomName) continue;
    out.push({
      classroomName,
      busyTimeStr: row.ZYJC === undefined ? null : row.ZYJC,
    });
  }
  return out;
}

export function guessCurrentSchoolTermCode(now: Date = new Date()): string {
  const year = now.getFullYear();
  const month = now.getMonth() + 1;
  if (month >= 9) {
    return `${year}-${year + 1}-1`;
  }
  if (month <= 1) {
    return `${year - 1}-${year}-1`;
  }
  return `${year - 1}-${year}-2`;
}

export function buildClassroomQueryParams(query: FreeClassroomQuery): ClassroomQueryParams {
  const parts = query.termCode.split('-');
  if (parts.length < 3) {
    throw new Error(`invalid termCode: ${query.termCode}`);
  }
  const termId = parts[parts.length - 1];
  const termYearCode = query.termCode.slice(0, query.termCode.length - termId.length - 1);
  return {
    XQDM: termId,
    JXLDM: query.buildingId,
    RQ: query.date,
    XNXQDM: query.termCode,
    XNDM: termYearCode,
  };
}

export function parseBusyPeriods(busyTimeStr: string | null | undefined): number[] {
  if (!busyTimeStr) return [];
  const raw = busyTimeStr.split(',');
  const parsed: number[] = [];
  for (let i = 0; i < raw.length; i++) {
    const n = Number(raw[i].trim());
    if (!Number.isInteger(n) || n < 1 || n > 13) continue;
    parsed.push(n);
  }
  return uniqueSorted(parsed);
}

export function normalizePeriodRange(range: PeriodRange): PeriodRange {
  const start = clampPeriod(Math.floor(range.start));
  const end = clampPeriod(Math.floor(range.end));
  return start <= end ? { start, end } : { start: end, end: start };
}

export function periodsFromRange(range: PeriodRange): number[] {
  const normalized = normalizePeriodRange(range);
  const out: number[] = [];
  for (let i = normalized.start; i <= normalized.end; i++) {
    out.push(i);
  }
  return out;
}

export function formatFreePeriods(periods: number[]): string {
  const sorted = uniqueSorted(periods);
  if (sorted.length === 0) return '无';

  const parts: string[] = [];
  let groupStart = sorted[0];
  let prev = sorted[0];
  for (let i = 1; i <= sorted.length; i++) {
    const current = sorted[i];
    if (i < sorted.length && current === prev + 1) {
      prev = current;
      continue;
    }
    parts.push(groupStart === prev ? String(groupStart) : `${groupStart}~${prev}`);
    groupStart = current;
    prev = current;
  }
  return parts.join(', ');
}

export function buildFreeClassroomRows(
  classrooms: ClassroomInfo[],
  periodRange: PeriodRange,
  periodCount: number = 13,
): FreeClassroomRow[] {
  const selectedPeriods = periodsFromRange(periodRange);
  const allPeriods: number[] = [];
  const safeCount = Math.max(1, Math.min(13, Math.floor(periodCount)));
  for (let i = 1; i <= safeCount; i++) {
    allPeriods.push(i);
  }

  const out: FreeClassroomRow[] = [];
  for (let i = 0; i < classrooms.length; i++) {
    const classroom = classrooms[i];
    const busyPeriods = parseBusyPeriods(classroom.busyTimeStr);
    let hasBusyInSelection = false;
    for (let j = 0; j < selectedPeriods.length; j++) {
      if (busyPeriods.indexOf(selectedPeriods[j]) >= 0) {
        hasBusyInSelection = true;
        break;
      }
    }
    if (hasBusyInSelection) continue;

    const freePeriods: number[] = [];
    for (let j = 0; j < allPeriods.length; j++) {
      if (busyPeriods.indexOf(allPeriods[j]) < 0) {
        freePeriods.push(allPeriods[j]);
      }
    }
    out.push({
      classroomName: classroom.classroomName,
      busyPeriods,
      freePeriods,
      freePeriodsText: formatFreePeriods(freePeriods),
    });
  }

  out.sort((a: FreeClassroomRow, b: FreeClassroomRow) => a.classroomName.localeCompare(b.classroomName));
  return out;
}

export function buildClassroomDayRows(
  classrooms: ClassroomInfo[],
  periodCount: number = 13,
): FreeClassroomRow[] {
  const allPeriods: number[] = [];
  const safeCount = Math.max(1, Math.min(13, Math.floor(periodCount)));
  for (let i = 1; i <= safeCount; i++) {
    allPeriods.push(i);
  }

  const out: FreeClassroomRow[] = [];
  for (let i = 0; i < classrooms.length; i++) {
    const classroom = classrooms[i];
    const busyPeriods = parseBusyPeriods(classroom.busyTimeStr);
    const freePeriods: number[] = [];
    for (let j = 0; j < allPeriods.length; j++) {
      if (busyPeriods.indexOf(allPeriods[j]) < 0) {
        freePeriods.push(allPeriods[j]);
      }
    }
    out.push({
      classroomName: classroom.classroomName,
      busyPeriods,
      freePeriods,
      freePeriodsText: formatFreePeriods(freePeriods),
    });
  }

  out.sort((a: FreeClassroomRow, b: FreeClassroomRow) => a.classroomName.localeCompare(b.classroomName));
  return out;
}

export function computeClassroomBusyStatus(
  row: FreeClassroomRow,
  periodTimes: PeriodTime[],
  nowClockText: string,
  freeMinutesThreshold: number = 10,
): ClassroomBusyStatus {
  if (periodTimes.length === 0) {
    return {
      isFreeNow: true,
      statusText: '空闲到明天',
      detailText: '',
      sortKey: 24 * 60 * 60,
    };
  }

  const nowMinutes = parseClockMinutes(nowClockText);
  const thresholdMinutes = Math.max(0, Math.floor(freeMinutesThreshold));
  let activeIndex = -1;
  for (let i = 0; i < periodTimes.length; i++) {
    const start = parseClockMinutes(periodTimes[i].start);
    const end = parseClockMinutes(periodTimes[i].end);
    if (nowMinutes >= start && nowMinutes <= end) {
      activeIndex = i;
      break;
    }
  }

  const busyPeriodSet: Record<string, boolean> = {};
  for (let i = 0; i < row.busyPeriods.length; i++) {
    busyPeriodSet[String(row.busyPeriods[i])] = true;
  }

  if (activeIndex >= 0 && busyPeriodSet[String(activeIndex + 1)]) {
    let freeAtMinutes = parseClockMinutes(periodTimes[activeIndex].end);
    let lastBusyIndex = activeIndex;
    for (let i = 0; i < row.busyPeriods.length; i++) {
      const nextIndex = row.busyPeriods[i] - 1;
      if (nextIndex <= lastBusyIndex || nextIndex >= periodTimes.length) {
        continue;
      }
      const gapMinutes = parseClockMinutes(periodTimes[nextIndex].start) -
        parseClockMinutes(periodTimes[lastBusyIndex].end);
      if (gapMinutes > thresholdMinutes) {
        break;
      }
      lastBusyIndex = nextIndex;
      freeAtMinutes = parseClockMinutes(periodTimes[nextIndex].end);
    }
    const secondsUntilFree = Math.max(0, (freeAtMinutes - nowMinutes) * 60);
    return {
      isFreeNow: false,
      statusText: `${formatDurationSeconds(secondsUntilFree)} 后空闲`,
      detailText: `(${formatClockMinutes(freeAtMinutes)})`,
      sortKey: -freeAtMinutes * 60,
    };
  }

  let nextBusyMinutes = -1;
  for (let i = 0; i < row.busyPeriods.length; i++) {
    const busyIndex = row.busyPeriods[i] - 1;
    if (busyIndex < 0 || busyIndex >= periodTimes.length) {
      continue;
    }
    const startMinutes = parseClockMinutes(periodTimes[busyIndex].start);
    if (startMinutes > nowMinutes) {
      nextBusyMinutes = startMinutes;
      break;
    }
  }

  if (nextBusyMinutes < 0) {
    return {
      isFreeNow: true,
      statusText: '空闲到明天',
      detailText: '',
      sortKey: 24 * 60 * 60,
    };
  }

  const secondsUntilBusy = Math.max(0, (nextBusyMinutes - nowMinutes) * 60);
  return {
    isFreeNow: secondsUntilBusy >= thresholdMinutes * 60,
    statusText: `还会空闲 ${formatDurationSeconds(secondsUntilBusy)}`,
    detailText: `(直到 ${formatClockMinutes(nextBusyMinutes)})`,
    sortKey: nextBusyMinutes * 60,
  };
}

export class FreeClassroomRepository {
  private readonly baseUrl: string;
  private readonly mode: SchoolLoginMode;
  private readonly debug: boolean;
  private readonly jar: SimpleCookieJar;
  private readonly client: RcpSession;

  constructor(options?: FreeClassroomRepositoryOptions) {
    this.mode = options?.mode || 'webvpn';
    const defaultBase = this.mode === 'inner' ? JXZXEHALLAPP_INNER_BASE : JXZXEHALLAPP_WEBVPN_BASE;
    this.baseUrl = (options?.baseUrl || defaultBase).replace(/\/+$/, '');
    this.debug = !!options?.debug;
    this.jar = new SimpleCookieJar();
    if (options?.cookieDump) {
      this.jar.restoreFromDump(options.cookieDump);
    }
    this.client = new RcpSession({
      baseUrl: this.baseUrl,
      debug: this.debug,
      timeoutMs: options?.timeoutMs || 15000,
      defaultHeaders: {
        'User-Agent': USER_AGENT,
        'Accept': 'application/json, text/plain, */*',
      },
      cookieJar: this.jar,
    });
  }

  async restoreWebvpnCookiesFromStorage(): Promise<void> {
    const schoolStore = new SchoolCookieStore(this.mode);
    const lexueStore = new LexueCookieStore('webvpn');
    const dump = await schoolStore.loadCookieDump() ?? (this.mode === 'webvpn' ? await lexueStore.loadCookieDump() : null);
    if (dump) {
      this.jar.restoreFromDump(dump);
    }
  }

  getCookieDump(): CookieDump {
    return this.jar.dump();
  }

  private async warmup(): Promise<void> {
    await this.client.get('/jwapp/sys/funauthapp/api/getAppConfig/wdkbby-5959167891382285.do');
    await this.client.get('/jwapp/i18n.do', {
      query: {
        appName: 'wdkbby',
        EMAP_LANG: 'zh',
      },
    });
  }

  async getCampusInfos(): Promise<CampusInfo[]> {
    await this.warmup();
    const resp = await this.client.get('/jwapp/sys/kxjasbyMobile/modules/jxllb/ggzdpx.do', {
      query: {
        dicCode: 48682,
        SFSY: '1',
        order: '+DM',
      },
    });
    assertOk(resp, 'getCampusInfos');
    const parsed = parseJson<CampusApiResponse>(resp.bodyText, 'getCampusInfos');
    const rows = parsed.datas?.ggzdpx?.rows || [];
    if (this.debug) {
      logger.info('campus count =', rows.length);
    }
    return mapCampusRows(rows);
  }

  async getBuildingInfos(campusCode?: string): Promise<BuildingInfo[]> {
    await this.warmup();
    const query: Record<string, string> = {};
    if (campusCode && campusCode.length > 0) {
      query.XXXQDM = campusCode;
    }
    const resp = await this.client.get('/jwapp/sys/kxjasbyMobile/modules/jxllb/cxjxl.do', { query });
    assertOk(resp, 'getBuildingInfos');
    const parsed = parseJson<BuildingApiResponse>(resp.bodyText, 'getBuildingInfos');
    const rows = parsed.datas?.cxjxl?.rows || [];
    if (this.debug) {
      logger.info('building count =', rows.length, 'campusCode =', campusCode || '(all)');
    }
    return mapBuildingRows(rows);
  }

  async getClassroomInfos(query: FreeClassroomQuery): Promise<ClassroomInfo[]> {
    await this.warmup();
    const params = buildClassroomQueryParams(query);
    if (this.debug) {
      logger.info('classroom params =', params);
    }
    const resp = await this.client.post(
      '/jwapp/sys/kxjasbyMobile/kxjasbyController/cxkxjasqk.do',
      toFormUrlEncoded({
        XQDM: params.XQDM,
        JXLDM: params.JXLDM,
        RQ: params.RQ,
        XNXQDM: params.XNXQDM,
        XNDM: params.XNDM,
      }),
      {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
      },
    );
    assertOk(resp, 'getClassroomInfos');
    const parsed = parseJson<ClassroomApiResponse>(resp.bodyText, 'getClassroomInfos');
    const rows = parsed.datas?.cxkxjasqk?.rows || [];
    if (this.debug) {
      logger.info('classroom count =', rows.length, 'buildingId =', query.buildingId);
    }
    return mapClassroomRows(rows);
  }

  async queryFreeClassrooms(
    query: FreeClassroomQuery,
    periodRange: PeriodRange,
  ): Promise<FreeClassroomRow[]> {
    const classrooms = await this.getClassroomInfos(query);
    return buildFreeClassroomRows(classrooms, periodRange, 13);
  }
}
