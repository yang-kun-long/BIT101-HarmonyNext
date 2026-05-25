import { describe, it, expect } from '@ohos/hypium';
import {
  buildClassroomDayRows,
  buildClassroomQueryParams,
  buildFreeClassroomRows,
  computeClassroomBusyStatus,
  formatFreePeriods,
  parseBusyPeriods,
  sortFreeClassroomRowsForAndroidDisplay,
} from '../main/ets/services/jw/freeClassroomRepository';
import type {
  ClassroomInfo,
  ClassroomBusyStatus,
  FreeClassroomQuery,
  PeriodRange,
  FreeClassroomRow,
} from '../main/ets/services/jw/freeClassroomRepository';
import type { PeriodTime } from '../main/ets/services/jw/periodTimes';

export default function freeClassroomTest() {
  describe('Free classroom helpers', () => {
    it('builds school query params from term and date', 0, () => {
      const query: FreeClassroomQuery = {
        termCode: '2025-2026-2',
        buildingId: 'LH01',
        date: '2026-05-25',
        periods: [1, 2],
      };

      const params = buildClassroomQueryParams(query);

      expect(params.XQDM).assertEqual('2');
      expect(params.XNXQDM).assertEqual('2025-2026-2');
      expect(params.XNDM).assertEqual('2025-2026');
      expect(params.JXLDM).assertEqual('LH01');
      expect(params.RQ).assertEqual('2026-05-25');
    });

    it('parses nullable busy period strings', 0, () => {
      expect(parseBusyPeriods(null).join(',')).assertEqual('');
      expect(parseBusyPeriods('').join(',')).assertEqual('');
      expect(parseBusyPeriods('3,1,abc,3,13').join(',')).assertEqual('1,3,13');
    });

    it('formats merged free period ranges', 0, () => {
      expect(formatFreePeriods([1, 2, 3, 6, 8, 9])).assertEqual('1~3, 6, 8~9');
      expect(formatFreePeriods([])).assertEqual('无');
    });

    it('filters classrooms free for selected periods', 0, () => {
      const classrooms: ClassroomInfo[] = [
        { classroomName: '101', busyTimeStr: '1,2,3' },
        { classroomName: '102', busyTimeStr: '4,5' },
        { classroomName: '103', busyTimeStr: null },
      ];
      const range: PeriodRange = { start: 1, end: 3 };

      const rows = buildFreeClassroomRows(classrooms, range, 13);

      expect(rows.length).assertEqual(2);
      expect(rows[0].classroomName).assertEqual('102');
      expect(rows[0].freePeriodsText).assertEqual('1~3, 6~13');
      expect(rows[1].classroomName).assertEqual('103');
      expect(rows[1].freePeriodsText).assertEqual('1~13');
    });

    it('builds all classroom rows for Android-style building expansion', 0, () => {
      const classrooms: ClassroomInfo[] = [
        { classroomName: '101', busyTimeStr: '1,2,3' },
        { classroomName: '102', busyTimeStr: '4,5' },
        { classroomName: '103', busyTimeStr: null },
      ];

      const rows: FreeClassroomRow[] = buildClassroomDayRows(classrooms, 13);

      expect(rows.length).assertEqual(3);
      expect(rows[0].classroomName).assertEqual('101');
      expect(rows[0].freePeriodsText).assertEqual('4~13');
      expect(rows[2].classroomName).assertEqual('103');
      expect(rows[2].freePeriodsText).assertEqual('1~13');
    });

    it('computes live classroom status from current timetable', 0, () => {
      const periodTimes: PeriodTime[] = [
        { start: '08:00', end: '08:45' },
        { start: '08:50', end: '09:35' },
        { start: '09:55', end: '10:40' },
      ];

      const freeNow: ClassroomBusyStatus = computeClassroomBusyStatus({
        classroomName: '101',
        busyPeriods: [3],
        freePeriods: [1, 2],
        freePeriodsText: '1~2',
      }, periodTimes, '08:10');
      const busyNow: ClassroomBusyStatus = computeClassroomBusyStatus({
        classroomName: '102',
        busyPeriods: [1, 2],
        freePeriods: [3],
        freePeriodsText: '3',
      }, periodTimes, '08:10');
      const freeAllDay: ClassroomBusyStatus = computeClassroomBusyStatus({
        classroomName: '103',
        busyPeriods: [],
        freePeriods: [1, 2, 3],
        freePeriodsText: '1~3',
      }, periodTimes, '08:10');

      expect(freeNow.isFreeNow).assertTrue();
      expect(freeNow.statusText).assertEqual('还会空闲 1 小时 45 分钟');
      expect(freeNow.detailText).assertEqual('(直到 09:55)');
      expect(busyNow.isFreeNow).assertFalse();
      expect(busyNow.statusText).assertEqual('1 小时 25 分钟 后空闲');
      expect(busyNow.detailText).assertEqual('(09:35)');
      expect(freeAllDay.statusText).assertEqual('空闲到明天');
    });

    it('sorts expanded classroom rows by Android live availability order', 0, () => {
      const periodTimes: PeriodTime[] = [
        { start: '08:00', end: '08:45' },
        { start: '08:50', end: '09:35' },
        { start: '09:55', end: '10:40' },
      ];
      const rows: FreeClassroomRow[] = [
        {
          classroomName: '102',
          busyPeriods: [1, 2],
          freePeriods: [3],
          freePeriodsText: '3',
        },
        {
          classroomName: '101',
          busyPeriods: [3],
          freePeriods: [1, 2],
          freePeriodsText: '1~2',
        },
        {
          classroomName: '103',
          busyPeriods: [],
          freePeriods: [1, 2, 3],
          freePeriodsText: '1~3',
        },
        {
          classroomName: '104',
          busyPeriods: [2],
          freePeriods: [1, 3],
          freePeriodsText: '1, 3',
        },
      ];

      const visible: FreeClassroomRow[] = sortFreeClassroomRowsForAndroidDisplay(
        rows,
        periodTimes,
        '08:10',
        5,
        false,
      );
      const freeOnly: FreeClassroomRow[] = sortFreeClassroomRowsForAndroidDisplay(
        rows,
        periodTimes,
        '08:10',
        5,
        true,
      );

      expect(visible.map((row: FreeClassroomRow) => row.classroomName).join(',')).assertEqual('103,101,104,102');
      expect(freeOnly.map((row: FreeClassroomRow) => row.classroomName).join(',')).assertEqual('103,101,104');
    });
  });
}
