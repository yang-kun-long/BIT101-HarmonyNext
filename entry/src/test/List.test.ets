import localUnitTest from './LocalUnit.test';
import bitSsoSessionStateTest from './BitSsoSessionState.test';
import schoolCasClientTest from './SchoolCasClient.test';
import schoolServiceResolverTest from './SchoolServiceResolver.test';
import storageGuardTest from './StorageGuard.test';
import webvpnCodecTest from './WebvpnCodec.test';

export default function testsuite() {
  localUnitTest();
  bitSsoSessionStateTest();
  schoolCasClientTest();
  schoolServiceResolverTest();
  storageGuardTest();
  webvpnCodecTest();
}
