import localUnitTest from './LocalUnit.test';
import bitSsoSessionStateTest from './BitSsoSessionState.test';
import schoolCasClientTest from './SchoolCasClient.test';
import schoolServiceResolverTest from './SchoolServiceResolver.test';
import storageGuardTest from './StorageGuard.test';
import webvpnCodecTest from './WebvpnCodec.test';
import debugRunnerContractTest from './DebugRunnerContract.test';
import bit101LoginFlowTest from './Bit101LoginFlow.test';
import freeClassroomTest from './FreeClassroom.test';
import ddlLocalTest from './DdlLocal.test';
import ddlSyncTest from './DdlSync.test';
import courseScheduleSettingsTest from './CourseScheduleSettings.test';
import courseScheduleLocalStoreTest from './CourseScheduleLocalStore.test';
import courseScheduleRepositoryTest from './CourseScheduleRepository.test';
import courseScheduleDetailTest from './CourseScheduleDetail.test';
import courseTermRepositoryTest from './CourseTermRepository.test';
import weekNavigatorModelTest from './WeekNavigatorModel.test';
import ddlListModelTest from './DdlListModel.test';

export default function testsuite() {
  localUnitTest();
  bitSsoSessionStateTest();
  schoolCasClientTest();
  schoolServiceResolverTest();
  storageGuardTest();
  webvpnCodecTest();
  debugRunnerContractTest();
  bit101LoginFlowTest();
  freeClassroomTest();
  ddlLocalTest();
  ddlSyncTest();
  courseScheduleSettingsTest();
  courseScheduleLocalStoreTest();
  courseScheduleRepositoryTest();
  courseScheduleDetailTest();
  courseTermRepositoryTest();
  weekNavigatorModelTest();
  ddlListModelTest();
}
