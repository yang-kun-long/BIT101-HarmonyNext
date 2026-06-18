import { DebugCase } from './DebugCase';
import { TEST_PASSWORD, TEST_USERNAME } from './local.secret';
import { AuthRepository } from '../services/auth/authRepository';
import { loginBit101AndVerifyWebvpn } from '../services/auth/bit101LoginFlow';
import { getDefaultPeriodTimes } from '../services/jw/periodTimes';
import { ExamScheduleRepository } from '../services/jw/examScheduleRepository';
import { CourseTermRepository } from '../services/jw/courseTermRepository';
import { CourseScheduleApiRepository } from '../services/jw/courseScheduleApiRepository';
import { prepareFreeClassroomSessionAuto } from '../services/jw/freeClassroomSession';
import { CourseScheduleRepository } from '../services/schoolSchedule/CourseScheduleRepository';
import { ScheduleLocalStore } from '../services/schoolSchedule/ScheduleLocalStore';
import type { SchoolLoginMode } from '../services/school/SchoolAuthTypes';
import type { CourseScheduleItem, ExamScheduleItem } from '../services/schoolSchedule/ScheduleModels';

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
    const previousExams = localStore.loadExams();

    try {
      this.logInfo('run BIT101 login + webvpn verify, username =', TEST_USERNAME);
      await loginBit101AndVerifyWebvpn(new AuthRepository(), {
        sid: TEST_USERNAME,
        password: TEST_PASSWORD,
      });

      this.logInfo('prepare JXZX exam session auto, username =', TEST_USERNAME);
      const mode: SchoolLoginMode = await prepareFreeClassroomSessionAuto(TEST_USERNAME, TEST_PASSWORD, true);
      this.logInfo('selected school mode =', mode);

      const termRepo = new CourseTermRepository({
        mode,
        debug: true,
      });
      const currentTerm = await termRepo.getCurrentTerm();
      const terms = await termRepo.getTermList();
      const firstDay = await termRepo.getFirstDay(currentTerm);
      this.logInfo('current term from JXZX =', currentTerm, 'firstDay =', firstDay, 'term list count =', terms.length);
      this.assertTrue(currentTerm.length > 0, 'current term should be fetched from JXZX');
      this.assertTrue(terms.indexOf(currentTerm) >= 0, 'term list should include current term');
      this.assertTrue(firstDay.length > 0, 'first day should be fetched from JXZX');

      const repo = new CourseScheduleRepository({
        localStore,
        courseSource: new CourseScheduleApiRepository({
          mode,
          debug: true,
        }),
      });
      const courses: CourseScheduleItem[] = await repo.refreshCourses(
        currentTerm,
        firstDay,
        getDefaultPeriodTimes(),
      );

      this.logInfo('refreshed native course count =', courses.length);
      this.assertTrue(courses.length > 0, 'native course sync should return at least one course');
      const persistedCourses = localStore.loadCourses();
      this.logInfo('persisted valid course count =', persistedCourses.length);
      this.assertTrue(persistedCourses.length > 0, 'native course sync should persist valid local courses');
      this.logInfo('course sample =', courses[0].name, courses[0].classroom, courses[0].weeks);

      const examRepo = new CourseScheduleRepository({
        localStore,
        examSource: new ExamScheduleRepository({
          mode,
          debug: true,
        }),
      });
      const exams: ExamScheduleItem[] = await examRepo.refreshExams(currentTerm);
      this.logInfo('refreshed exam count =', exams.length);
      const persistedExams = localStore.loadExams();
      this.assertTrue(persistedExams.length === exams.length, 'exam sync should persist returned exams');
      if (exams.length > 0) {
        this.logInfo('exam sample =', exams[0].name, exams[0].classroom, exams[0].dateISO, exams[0].beginTime, exams[0].endTime);
      }
    } finally {
      localStore.saveCourses(previousCourses);
      localStore.saveExams(previousExams);
      this.logInfo('previous local courses restored');
      this.logInfo('previous local exams restored');
    }

    this.logInfo('=== CourseScheduleSyncCase END ===');
  }
}
