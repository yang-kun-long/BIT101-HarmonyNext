import { describe, it, expect } from '@ohos/hypium';
import {
  resolveDdlSyncBaseUrl,
  resolveDdlSyncUsername,
} from '../main/ets/services/deadline/DdlSyncService';

class SsoUsernameFieldStub {
  username: string = 'field-user';
}

class SsoUsernameMethodStub {
  getUsername(): string {
    return 'method-user';
  }
}

class SsoNoUsernameStub {
}

export default function ddlSyncTest() {
  describe('DDL sync service', () => {
    it('prefers current AppStorage username before SSO username', 0, () => {
      const username: string = resolveDdlSyncUsername('current-user', new SsoUsernameFieldStub());

      expect(username).assertEqual('current-user');
    });

    it('uses SSO username field when current username is empty', 0, () => {
      const username: string = resolveDdlSyncUsername('', new SsoUsernameFieldStub());

      expect(username).assertEqual('field-user');
    });

    it('uses SSO getUsername when username field is unavailable', 0, () => {
      const username: string = resolveDdlSyncUsername('', new SsoUsernameMethodStub());

      expect(username).assertEqual('method-user');
    });

    it('falls back to default username when no source is available', 0, () => {
      const username: string = resolveDdlSyncUsername('', new SsoNoUsernameStub());

      expect(username).assertEqual('default');
    });

    it('uses direct Lexue base URL for inner mode', 0, () => {
      const baseUrl: string = resolveDdlSyncBaseUrl('inner');

      expect(baseUrl).assertEqual('https://lexue.bit.edu.cn');
    });

    it('uses WebVPN Lexue base URL for webvpn mode', 0, () => {
      const baseUrl: string = resolveDdlSyncBaseUrl('webvpn');

      expect(baseUrl.startsWith('https://webvpn.bit.edu.cn/https/')).assertTrue();
    });
  });
}
