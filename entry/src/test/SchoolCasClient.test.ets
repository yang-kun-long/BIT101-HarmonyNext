import { describe, it, expect } from '@ohos/hypium';
import { parseSt, parseTgtLocationFromHtml, parseTgtUrl } from '../main/ets/services/school/SchoolCasClient';

export default function schoolCasClientTest() {
  describe('SchoolCasClient parsing', () => {
    it('parses tgt from location header', 0, () => {
      const tgtUrl = parseTgtUrl(201, {
        Location: 'https://sso.bit.edu.cn/cas/v1/tickets/TGT-123',
      }, '');
      expect(tgtUrl).assertEqual('https://sso.bit.edu.cn/cas/v1/tickets/TGT-123');
    });

    it('parses tgt from html fallback', 0, () => {
      const tgtUrl = parseTgtUrl(201, {}, '<form action="https://sso.bit.edu.cn/cas/v1/tickets/TGT-HTML">');
      expect(tgtUrl).assertEqual('https://sso.bit.edu.cn/cas/v1/tickets/TGT-HTML');
    });

    it('extracts action url from html snippet', 0, () => {
      const tgtUrl = parseTgtLocationFromHtml('<form action="https://example.com/tgt">');
      expect(tgtUrl).assertEqual('https://example.com/tgt');
    });

    it('parses st body by trimming whitespace', 0, () => {
      const st = parseSt('  ST-12345  ');
      expect(st).assertEqual('ST-12345');
    });
  });
}
