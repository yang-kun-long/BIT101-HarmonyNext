import { describe, it, expect } from '@ohos/hypium';
import { extractPortalServiceFromLocation, resolveAbsoluteUrl, resolveServiceFromRedirect } from '../main/ets/services/school/SchoolServiceResolver';
import { inferSchoolLoginModeFromProbe } from '../main/ets/services/school/SchoolNetworkProbe';

export default function schoolServiceResolverTest() {
  describe('School service resolver', () => {
    it('resolves relative redirect to absolute url', 0, () => {
      const resolved = resolveAbsoluteUrl('https://webvpn.bit.edu.cn/login?cas_login=true', '/cas/login?service=https%3A%2F%2Fexample.com');
      expect(resolved).assertEqual('https://webvpn.bit.edu.cn/cas/login?service=https%3A%2F%2Fexample.com');
    });

    it('extracts service from redirect location', 0, () => {
      const service = resolveServiceFromRedirect(
        'https://webvpn.bit.edu.cn/login?cas_login=true',
        '/cas/login?service=https%3A%2F%2Fwebvpn.bit.edu.cn%2Flogin%3Fcas_login%3Dtrue',
      );
      expect(service).assertEqual('https://webvpn.bit.edu.cn/login?cas_login=true');
    });

    it('extracts portal service from webvpn redirect location', 0, () => {
      const service = extractPortalServiceFromLocation('/cas/login?service=https%3A%2F%2Fwebvpn.bit.edu.cn%2Flogin%3Fcas_login%3Dtrue');
      expect(service).assertEqual('https://webvpn.bit.edu.cn/login?cas_login=true');
    });

    it('treats 302 probe as inner mode', 0, () => {
      const mode = inferSchoolLoginModeFromProbe(302);
      expect(mode).assertEqual('inner');
    });

    it('treats redirect-limit errors as inner mode', 0, () => {
      const mode = inferSchoolLoginModeFromProbe(0, 1007900047, 'Number of redirects hit maximum amount');
      expect(mode).assertEqual('inner');
    });

    it('falls back to webvpn when probe is unreachable', 0, () => {
      const mode = inferSchoolLoginModeFromProbe(0, 0, 'connect timeout');
      expect(mode).assertEqual('webvpn');
    });
  });
}
