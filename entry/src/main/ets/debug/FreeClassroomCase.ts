import { DebugCase } from './DebugCase';
import { TEST_PASSWORD, TEST_USERNAME } from './local.secret';
import { SchoolAuthService } from '../services/school/SchoolAuthService';
import {
  BuildingInfo,
  CampusInfo,
  FreeClassroomRepository,
  FreeClassroomRow,
  guessCurrentSchoolTermCode,
} from '../services/jw/freeClassroomRepository';
import { prepareFreeClassroomSessionAuto } from '../services/jw/freeClassroomSession';
import type { SchoolLoginMode } from '../services/school/SchoolAuthTypes';

function pad2(n: number): string {
  return n < 10 ? `0${n}` : String(n);
}

function todayISO(): string {
  const d = new Date();
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`;
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
    } catch (e) {
      this.logError('FreeClassroomCase failed =', e);
      throw e;
    }

    this.logInfo('=== FreeClassroomCase END ===');
  }
}
