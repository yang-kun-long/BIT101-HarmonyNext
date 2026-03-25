import localUnitTest from './LocalUnit.test';
import schoolCasClientTest from './SchoolCasClient.test';
import schoolServiceResolverTest from './SchoolServiceResolver.test';
import webvpnCodecTest from './WebvpnCodec.test';

export default function testsuite() {
  localUnitTest();
  schoolCasClientTest();
  schoolServiceResolverTest();
  webvpnCodecTest();
}
