import { DebugCase } from './DebugCase';
import { getDefaultPeriodTimes } from '../services/jw/periodTimes';
import { CourseScheduleSettingsStore } from '../services/storage/CourseScheduleSettingsStore';
import type { ScheduleDisplaySettings } from '../services/schoolSchedule/ScheduleSettingsModels';

export class CourseScheduleSettingsCase extends DebugCase {
  readonly name = 'Course schedule settings persistence';

  async run(): Promise<void> {
    this.logInfo('=== CourseScheduleSettingsCase START ===');
    const store = new CourseScheduleSettingsStore();
    const previous = await store.load();
    const periodTimes = getDefaultPeriodTimes();
    periodTimes[0] = { start: '07:50', end: '08:35' };
    const next: ScheduleDisplaySettings = {
      currentTerm: 'debug-term',
      firstDayISO: '2026-02-23',
      showSaturday: true,
      showSunday: false,
      showBorder: true,
      showHighlightToday: false,
      showDivider: true,
      showCurrentTime: false,
      showExamInfo: true,
      periodTimes,
    };

    try {
      await store.save(next);
      const loaded = await store.load();
      this.assertEquals(loaded.currentTerm, next.currentTerm, 'currentTerm should persist');
      this.assertEquals(loaded.firstDayISO, next.firstDayISO, 'firstDayISO should persist');
      this.assertTrue(loaded.showSaturday === true, 'showSaturday should persist');
      this.assertTrue(loaded.showSunday === false, 'showSunday should persist');
      this.assertTrue(loaded.showBorder === true, 'showBorder should persist');
      this.assertTrue(loaded.showHighlightToday === false, 'showHighlightToday should persist');
      this.assertTrue(loaded.showDivider === true, 'showDivider should persist');
      this.assertTrue(loaded.showCurrentTime === false, 'showCurrentTime should persist');
      this.assertTrue(loaded.showExamInfo === true, 'showExamInfo should persist');
      this.assertTrue(loaded.periodTimes.length === next.periodTimes.length, 'period times should persist');
      this.assertEquals(loaded.periodTimes[0].start, '07:50', 'first period start should persist');
      this.assertEquals(loaded.periodTimes[0].end, '08:35', 'first period end should persist');
      this.logInfo('settings persistence verified');
    } finally {
      await store.save(previous);
      this.logInfo('previous settings restored');
    }

    this.logInfo('=== CourseScheduleSettingsCase END ===');
  }
}
