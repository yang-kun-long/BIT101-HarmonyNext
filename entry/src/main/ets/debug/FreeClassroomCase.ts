import { DebugCase } from './DebugCase';
import { TEST_PASSWORD, TEST_USERNAME } from './local.secret';
import { SchoolAuthService } from '../services/school/SchoolAuthService';
import {
  buildClassroomDayRows,
  BuildingInfo,
  CampusInfo,
  computeClassroomBusyStatus,
  FreeClassroomRepository,
  FreeClassroomRow,
  guessCurrentSchoolTermCode,
  sortFreeClassroomRowsForAndroidDisplay,
} from '../services/jw/freeClassroomRepository';
import { prepareFreeClassroomSessionAuto } from '../services/jw/freeClassroomSession';
import type { SchoolLoginMode } from '../services/school/SchoolAuthTypes';
import { getDefaultPeriodTimes } from '../services/jw/periodTimes';

function pad2(n: number): string {
  return n < 10 ? `0${n}` : String(n);
}

function todayISO(): string {
  const d = new Date();
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`;
}

function nowClockText(): string {
  const d = new Date();
  return `${pad2(d.getHours())}:${pad2(d.getMinutes())}`;
}

export class FreeClassroomCase extends DebugCase {
  readonly name = 'Free classroom JW API smoke';

  async run(): Promise<void> {
    this.logInfo('=== FreeClassroomCase START ===');

    if (!TEST_USERNAME || !TEST_PASSWORD) {
      this.fail('Missing TEST_USERNAME / TEST_PASSWORD in local.secret.ts');
    }

    const termCode = guessCurrentSchoolTermCode();
    const date = todayISO();
    try {
      this.logInfo('prepare free classroom session auto, username =', TEST_USERNAME);
      const mode: SchoolLoginMode = await prepareFreeClassroomSessionAuto(TEST_USERNAME, TEST_PASSWORD, true);
      this.logInfo('selected mode =', mode);

      const repo = new FreeClassroomRepository({
        debug: true,
        mode,
      });
      await repo.restoreWebvpnCookiesFromStorage();

      const campuses: CampusInfo[] = await repo.getCampusInfos();
      this.logInfo('campus count =', campuses.length);
      if (campuses.length === 0) {
        this.fail('No campus returned');
      }
      const campus = campuses[0];
      this.logInfo('campus sample =', campus.displayName, campus.code);

      const buildings: BuildingInfo[] = await repo.getBuildingInfos(campus.code);
      this.logInfo('building count =', buildings.length, 'campus =', campus.displayName);
      if (buildings.length === 0) {
        this.fail(`No building returned for campus ${campus.displayName}`);
      }
      const building = buildings[0];
      this.logInfo('building sample =', building.buildingName, building.buildingIndex);

      this.logInfo('query params date =', date, 'term =', termCode, 'periods = 1-2');
      const rows: FreeClassroomRow[] = await repo.queryFreeClassrooms({
        termCode,
        buildingId: building.buildingIndex,
        date,
        periods: [1, 2],
      }, { start: 1, end: 2 });

      this.logInfo('free classroom count =', rows.length);
      const sampleCount = Math.min(rows.length, 5);
      for (let i = 0; i < sampleCount; i++) {
        const row = rows[i];
        this.logInfo('free classroom sample', i + 1, '=', row.classroomName, 'freePeriods =', row.freePeriodsText);
      }

      await this.verifyHideBusyMixedSample(repo, campuses, termCode, date);
    } catch (e) {
      this.logError('FreeClassroomCase failed =', e);
      throw e;
    }

    this.logInfo('=== FreeClassroomCase END ===');
  }

  private async verifyHideBusyMixedSample(
    repo: FreeClassroomRepository,
    campuses: CampusInfo[],
    termCode: string,
    date: string,
  ): Promise<void> {
    const periodTimes = getDefaultPeriodTimes();
    const clock = nowClockText();
    const threshold = 5;
    this.logInfo('hide-busy sample scan clock =', clock, 'threshold =', threshold);

    const campusLimit = campuses.length;
    for (let campusIndex = 0; campusIndex < campusLimit; campusIndex++) {
      const campus = campuses[campusIndex];
      const buildings = await repo.getBuildingInfos(campus.code);
      const buildingLimit = buildings.length;

      for (let buildingIndex = 0; buildingIndex < buildingLimit; buildingIndex++) {
        const building = buildings[buildingIndex];
        const classrooms = await repo.getClassroomInfos({
          termCode,
          buildingId: building.buildingIndex,
          date,
          periods: [],
        });
        const dayRows: FreeClassroomRow[] = buildClassroomDayRows(classrooms, 13);
        if (dayRows.length === 0) {
          continue;
        }

        const allRows = sortFreeClassroomRowsForAndroidDisplay(
          dayRows,
          periodTimes,
          clock,
          threshold,
          false,
        );
        const freeOnlyRows = sortFreeClassroomRowsForAndroidDisplay(
          dayRows,
          periodTimes,
          clock,
          threshold,
          true,
        );

        if (allRows.length > freeOnlyRows.length && freeOnlyRows.length > 0) {
          this.logInfo(
            'hide-busy mixed sample found campus =',
            campus.displayName,
            'building =',
            building.buildingName,
            'all =',
            allRows.length,
            'freeOnly =',
            freeOnlyRows.length,
            );
            this.logRows('hide-busy before', allRows, periodTimes, clock, threshold, 5);
            this.logRows('hide-busy after', freeOnlyRows, periodTimes, clock, threshold, 5);
            this.logHiddenRows(allRows, freeOnlyRows, periodTimes, clock, threshold, 5);
            return;
          }
      }
    }

    this.logInfo('hide-busy mixed sample not found at actual clock, scanning class-time clocks');
    await this.verifyHideBusyWithClassTimeClock(repo, campuses, termCode, date);
  }

  private async verifyHideBusyWithClassTimeClock(
    repo: FreeClassroomRepository,
    campuses: CampusInfo[],
    termCode: string,
    date: string,
  ): Promise<void> {
    const periodTimes = getDefaultPeriodTimes();
    const clocks = ['08:30', '10:10', '14:30', '19:30'];
    const threshold = 5;

    for (let clockIndex = 0; clockIndex < clocks.length; clockIndex++) {
      const clock = clocks[clockIndex];
      for (let campusIndex = 0; campusIndex < campuses.length; campusIndex++) {
        const campus = campuses[campusIndex];
        const buildings = await repo.getBuildingInfos(campus.code);

        for (let buildingIndex = 0; buildingIndex < buildings.length; buildingIndex++) {
          const building = buildings[buildingIndex];
          const classrooms = await repo.getClassroomInfos({
            termCode,
            buildingId: building.buildingIndex,
            date,
            periods: [],
          });
          const dayRows: FreeClassroomRow[] = buildClassroomDayRows(classrooms, 13);
          if (dayRows.length === 0) {
            continue;
          }

          const allRows = sortFreeClassroomRowsForAndroidDisplay(
            dayRows,
            periodTimes,
            clock,
            threshold,
            false,
          );
          const freeOnlyRows = sortFreeClassroomRowsForAndroidDisplay(
            dayRows,
            periodTimes,
            clock,
            threshold,
            true,
          );

          if (allRows.length > freeOnlyRows.length && freeOnlyRows.length > 0) {
            this.logInfo(
              'hide-busy class-time mixed sample found clock =',
              clock,
              'campus =',
              campus.displayName,
              'building =',
              building.buildingName,
              'all =',
              allRows.length,
              'freeOnly =',
              freeOnlyRows.length,
            );
            this.logRows('hide-busy simulated before', allRows, periodTimes, clock, threshold, 5);
            this.logRows('hide-busy simulated after', freeOnlyRows, periodTimes, clock, threshold, 5);
            this.logHiddenRows(allRows, freeOnlyRows, periodTimes, clock, threshold, 5);
            return;
          }
        }
      }
    }

    this.logInfo('hide-busy mixed sample not found in actual or class-time scans');
  }

  private logRows(
    label: string,
    rows: FreeClassroomRow[],
    periodTimes: ReturnType<typeof getDefaultPeriodTimes>,
    clock: string,
    threshold: number,
    limit: number,
  ): void {
    const count = Math.min(rows.length, limit);
    for (let i = 0; i < count; i++) {
      const row = rows[i];
      const status = computeClassroomBusyStatus(row, periodTimes, clock, threshold);
      this.logInfo(
        label,
        i + 1,
        '=',
        row.classroomName,
        status.statusText,
        status.detailText,
        'isFreeNow =',
        status.isFreeNow,
        'busyPeriods =',
        row.busyPeriods.join(','),
      );
    }
  }

  private logHiddenRows(
    allRows: FreeClassroomRow[],
    freeOnlyRows: FreeClassroomRow[],
    periodTimes: ReturnType<typeof getDefaultPeriodTimes>,
    clock: string,
    threshold: number,
    limit: number,
  ): void {
    const visible: Record<string, boolean> = {};
    for (let i = 0; i < freeOnlyRows.length; i++) {
      visible[freeOnlyRows[i].classroomName] = true;
    }

    let logged = 0;
    for (let i = 0; i < allRows.length && logged < limit; i++) {
      const row = allRows[i];
      if (visible[row.classroomName]) {
        continue;
      }
      const status = computeClassroomBusyStatus(row, periodTimes, clock, threshold);
      this.logInfo(
        'hide-busy hidden',
        logged + 1,
        '=',
        row.classroomName,
        status.statusText,
        status.detailText,
        'isFreeNow =',
        status.isFreeNow,
        'busyPeriods =',
        row.busyPeriods.join(','),
      );
      logged += 1;
    }
  }
}
