import abilityTest from './Ability.test';
import messageTest from '../../../test/Message.test';
import followListTest from '../../../test/FollowList.test';
import userProfileTest from '../../../test/UserProfile.test';
import loginCoordinatorTest from '../../../test/LoginCoordinator.test';
import smsChallengeCoordinatorTest from '../../../test/SmsChallengeCoordinator.test';
import webSessionModelTest from '../../../test/WebSessionModel.test';
import webNavigationTest from '../../../test/WebNavigation.test';
import galleryFilterTest from '../../../test/GalleryFilter.test';
import galleryCommentsTest from '../../../test/GalleryComments.test';
import gallerySettingsTest from '../../../test/GallerySettings.test';
import versionModelsTest from '../../../test/VersionModels.test';
import logExportTest from '../../../test/LogExport.test';
import pageSettingsTest from '../../../test/PageSettings.test';
import themeSettingsTest from '../../../test/ThemeSettings.test';

export default function testsuite() {
  abilityTest();
  loginCoordinatorTest();
  smsChallengeCoordinatorTest();
  userProfileTest();
  messageTest();
  followListTest();
  galleryFilterTest();
  galleryCommentsTest();
  gallerySettingsTest();
  webSessionModelTest();
  webNavigationTest();
  versionModelsTest();
  logExportTest();
  pageSettingsTest();
  themeSettingsTest();
}
