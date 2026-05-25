import { DebugCase } from './DebugCase';
import { TEST_PASSWORD, TEST_USERNAME } from './local.secret';
import { AuthRepository } from '../services/auth/authRepository';
import { loginBit101AndVerifyWebvpn } from '../services/auth/bit101LoginFlow';
import { TimetableRepository } from '../services/jw/timetableRepository';
import { getDefaultPeriodTimes } from '../services/jw/periodTimes';
import { CourseScheduleRepository } from '../services/schoolSchedule/CourseScheduleRepository';
import { ScheduleLocalStore } from '../services/schoolSchedule/ScheduleLocalStore';
import type { CourseScheduleItem } from '../services/schoolSchedule/ScheduleModels';

function appFilesDir(): string {
  return AppStorage.get<string>('filesDir') ?? '';
}

export class CourseScheduleSyncCase extends DebugCase {
  readonly name = 'Course schedule sync smoke';

  async run(): Promise<void> {
    this.logInfo('=== CourseScheduleSyncCase START ===');

    if (!TEST_USERNAME || !TEST_PASSWORD) {
      this.fail('Missing TEST_USERNAME / TEST_PASSWORD in local.secret.ts');
    }

    const filesDir = appFilesDir();
    if (filesDir.length === 0) {
      this.fail('Missing filesDir in AppStorage');
    }

    const localStore = new ScheduleLocalStore({ filesDir });
    const previousCourses = localStore.loadCourses();

    try {
      this.logInfo('run BIT101 login + webvpn verify, username =', TEST_USERNAME);
      await loginBit101AndVerifyWebvpn(new AuthRepository(), {
        sid: TEST_USERNAME,
        password: TEST_PASSWORD,
      });

      const repo = new CourseScheduleRepository({
        localStore,
        timetableRepository: new TimetableRepository('https://bit101.flwfdd.xyz', true),
      });
      const courses: CourseScheduleItem[] = await repo.refreshCourses(
        'debug-term',
        '2026-02-23',
        getDefaultPeriodTimes(),
      );

      this.logInfo('refreshed course count =', courses.length);
      this.assertTrue(courses.length > 0, 'course sync should return at least one course');
      const persistedCourses = localStore.loadCourses();
      this.logInfo('persisted valid course count =', persistedCourses.length);
      this.assertTrue(persistedCourses.length > 0, 'course sync should persist valid local courses');
      this.logInfo('course sample =', courses[0].name, courses[0].classroom, courses[0].weeks);
      this.logInfo('exam sync is not asserted because CourseScheduleRepository.refreshExams is not implemented yet');
    } finally {
      localStore.saveCourses(previousCourses);
      this.logInfo('previous local courses restored');
    }

    this.logInfo('=== CourseScheduleSyncCase END ===');
  }
}
