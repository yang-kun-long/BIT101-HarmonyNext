import { describe, it, expect } from '@ohos/hypium';
import type { CookieDump } from '../main/ets/core/network/cookieJar';
import {
  extractLexueSesskey,
  inferRestoredBitSsoState,
  isBitSsoSessionReady,
  isRestoredLexueExportUsable,
} from '../main/ets/services/lexue/BitSsoSessionState';

function cookie(name: string, value: string, domain: string): CookieDump {
  return [
    {
      name,
      value,
      domain,
      path: '/',
      secure: false,
      httpOnly: false,
    },
  ];
}

export default function bitSsoSessionStateTest() {
  describe('BitSsoSession restore state', () => {
    it('treats empty cookie dump as fully logged out', 0, () => {
      const state = inferRestoredBitSsoState(false, []);
      expect(state.hasSso).assertFalse();
      expect(state.hasLexue).assertFalse();
      expect(state.requiresTicketRefresh).assertFalse();
    });

    it('treats inner moodle session as fully reusable login state', 0, () => {
      const state = inferRestoredBitSsoState(false, [
        ...cookie('MoodleSession', 'moodle-1', 'lexue.bit.edu.cn'),
      ]);
      expect(state.hasSso).assertTrue();
      expect(state.hasLexue).assertTrue();
      expect(state.requiresTicketRefresh).assertFalse();
    });

    it('treats webvpn portal cookie as a candidate session that still needs live validation', 0, () => {
      const state = inferRestoredBitSsoState(true, [
        ...cookie('wengine_vpn_ticketwebvpn_bit_edu_cn', 'vpn-1', 'webvpn.bit.edu.cn'),
      ]);
      expect(state.hasSso).assertFalse();
      expect(state.hasLexue).assertTrue();
      expect(state.requiresTicketRefresh).assertTrue();
    });

    it('treats webvpn portal and moodle cookies as a candidate session that still needs live validation', 0, () => {
      const state = inferRestoredBitSsoState(true, [
        ...cookie('wengine_vpn_ticketwebvpn_bit_edu_cn', 'vpn-1', 'webvpn.bit.edu.cn'),
        ...cookie('MoodleSession', 'moodle-1', 'lexue.bit.edu.cn'),
      ]);
      expect(state.hasSso).assertFalse();
      expect(state.hasLexue).assertTrue();
      expect(state.requiresTicketRefresh).assertTrue();
    });

    it('accepts restored lexue export page with sesskey', 0, () => {
      const usable = isRestoredLexueExportUsable(
        200,
        'https://webvpn.bit.edu.cn/https/example/calendar/export.php',
        '<html><input name="sesskey" value="abc123"></html>',
      );
      expect(usable).assertTrue();
    });

    it('rejects restored lexue export page when it falls back to sso login', 0, () => {
      const usable = isRestoredLexueExportUsable(
        200,
        'https://sso.bit.edu.cn/cas/login?service=foo',
        '<html>统一身份认证</html>',
      );
      expect(usable).assertFalse();
    });

    it('rejects restored lexue export page without sesskey', 0, () => {
      const usable = isRestoredLexueExportUsable(
        200,
        'https://webvpn.bit.edu.cn/https/example/calendar/export.php',
        '<html>calendar export page but no sesskey</html>',
      );
      expect(usable).assertFalse();
    });

    it('extracts sesskey from input field', 0, () => {
      const sesskey = extractLexueSesskey(
        '<html><input name="sesskey" value="abc123"></html>',
      );
      expect(sesskey).assertEqual('abc123');
    });

    it('returns empty sesskey when html does not contain one', 0, () => {
      const sesskey = extractLexueSesskey('<html>no sesskey here</html>');
      expect(sesskey).assertEqual('');
    });

    it('treats webvpn lexue-ready state as fully logged in even if sso flag is false', 0, () => {
      const ready = isBitSsoSessionReady(true, false, true);
      expect(ready).assertTrue();
    });

    it('treats inner mode as requiring both sso and lexue flags', 0, () => {
      const ready = isBitSsoSessionReady(false, false, true);
      expect(ready).assertFalse();
    });
  });
}
