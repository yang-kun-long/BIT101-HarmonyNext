import { describe, it, expect } from '@ohos/hypium';
import {
  normalizeScheduleDisplaySettings,
  parsePeriodTimesText,
  periodTimesToText,
  visibleWeekdayNumbers,
} from '../main/ets/services/schoolSchedule/ScheduleSettingsModels';
import {
  COURSE_SCHEDULE_APP_CURRENT_TERM,
  COURSE_SCHEDULE_APP_FIRST_DAY_ISO,
  COURSE_SCHEDULE_APP_SHOW_BORDER,
  COURSE_SCHEDULE_APP_SHOW_CURRENT_TIME,
  COURSE_SCHEDULE_APP_SHOW_DIVIDER,
  COURSE_SCHEDULE_APP_SHOW_EXAM_INFO,
  COURSE_SCHEDULE_APP_SHOW_HIGHLIGHT_TODAY,
  COURSE_SCHEDULE_APP_SHOW_SATURDAY,
  COURSE_SCHEDULE_APP_SHOW_SUNDAY,
} from '../main/ets/services/storage/CourseScheduleSettingsStore';
import type { ScheduleDisplaySettings } from '../main/ets/services/schoolSchedule/ScheduleSettingsModels';
import type { PeriodTime } from '../main/ets/services/jw/periodTimes';

export default function courseScheduleSettingsTest() {
  describe('Course schedule settings', () => {
    it('parses Android-style timetable text', 0, () => {
      const periodTimes: PeriodTime[] = parsePeriodTimesText('08:00,08:45\n08:50,09:35');

      expect(periodTimes.length).assertEqual(2);
      expect(periodTimes[0].start).assertEqual('08:00');
      expect(periodTimes[0].end).assertEqual('08:45');
      expect(periodTimesToText(periodTimes)).assertEqual('08:00,08:45\n08:50,09:35');
    });

    it('also accepts old hyphen timetable text from the HarmonyOS placeholder page', 0, () => {
      const periodTimes: PeriodTime[] = parsePeriodTimesText('08:00-08:45\n08:50-09:35');

      expect(periodTimes.length).assertEqual(2);
      expect(periodTimes[1].start).assertEqual('08:50');
      expect(periodTimes[1].end).assertEqual('09:35');
    });

    it('rejects overlapping or malformed timetable text', 0, () => {
      expect(parsePeriodTimesText('08:45,08:00').length).assertEqual(0);
      expect(parsePeriodTimesText('08:00,08:45\n08:30,09:10').length).assertEqual(0);
      expect(parsePeriodTimesText('bad').length).assertEqual(0);
    });

    it('normalizes partial persisted data to Android-compatible defaults', 0, () => {
      const normalized: ScheduleDisplaySettings = normalizeScheduleDisplaySettings({
        showSaturday: false,
        showSunday: false,
        showBorder: true,
        showHighlightToday: false,
        showDivider: false,
        showCurrentTime: false,
        showExamInfo: false,
        periodTimes: [],
      });

      expect(normalized.currentTerm).assertEqual('');
      expect(normalized.firstDayISO).assertEqual('');
      expect(normalized.showSaturday).assertFalse();
      expect(normalized.showBorder).assertTrue();
      expect(normalized.periodTimes.length).assertEqual(13);
      expect(normalized.periodTimes[0].start).assertEqual('08:00');
    });

    it('exports stable AppStorage keys for schedule settings', 0, () => {
      expect(COURSE_SCHEDULE_APP_CURRENT_TERM).assertEqual('course_schedule_current_term');
      expect(COURSE_SCHEDULE_APP_FIRST_DAY_ISO).assertEqual('course_schedule_first_day_iso');
      expect(COURSE_SCHEDULE_APP_SHOW_SATURDAY).assertEqual('course_schedule_show_saturday');
      expect(COURSE_SCHEDULE_APP_SHOW_SUNDAY).assertEqual('course_schedule_show_sunday');
      expect(COURSE_SCHEDULE_APP_SHOW_BORDER).assertEqual('course_schedule_show_border');
      expect(COURSE_SCHEDULE_APP_SHOW_HIGHLIGHT_TODAY).assertEqual('course_schedule_show_highlight_today');
      expect(COURSE_SCHEDULE_APP_SHOW_DIVIDER).assertEqual('course_schedule_show_divider');
      expect(COURSE_SCHEDULE_APP_SHOW_CURRENT_TIME).assertEqual('course_schedule_show_current_time');
      expect(COURSE_SCHEDULE_APP_SHOW_EXAM_INFO).assertEqual('course_schedule_show_exam_info');
    });

    it('derives visible weekdays from weekend settings', 0, () => {
      expect(visibleWeekdayNumbers(true, true).join(',')).assertEqual('1,2,3,4,5,6,7');
      expect(visibleWeekdayNumbers(false, true).join(',')).assertEqual('1,2,3,4,5,7');
      expect(visibleWeekdayNumbers(true, false).join(',')).assertEqual('1,2,3,4,5,6');
      expect(visibleWeekdayNumbers(false, false).join(',')).assertEqual('1,2,3,4,5');
    });
  });
}
