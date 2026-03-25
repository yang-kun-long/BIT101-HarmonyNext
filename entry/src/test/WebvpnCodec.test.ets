import { describe, it, expect } from '@ohos/hypium';
import { encodeVpnHost } from '../main/ets/services/school/WebvpnCodec';
import { buildWebvpnJumpUrl } from '../main/ets/services/school/WebvpnJumpBuilder';

export default function webvpnCodecTest() {
  describe('WebVPN codec', () => {
    it('encodes webvpn host using known reference output', 0, () => {
      const encoded = encodeVpnHost('webvpn.bit.edu.cn');
      expect(encoded).assertEqual('77726476706e69737468656265737421e7f2438a373e2652771cc7a99c406d36da');
    });

    it('encodes stu host using known reference output', 0, () => {
      const encoded = encodeVpnHost('stu.bit.edu.cn');
      expect(encoded).assertEqual('77726476706e69737468656265737421e3e354d225397c1e7b0c9ce29b5b');
    });

    it('builds a jump url with the ticket appended', 0, () => {
      const jumpUrl = buildWebvpnJumpUrl('https://webvpn.bit.edu.cn/login?cas_login=true', 'ST-123');
      expect(jumpUrl).assertEqual(
        'https://webvpn.bit.edu.cn/https/77726476706e69737468656265737421e7f2438a373e2652771cc7a99c406d36da/login?cas_login=true&ticket=ST-123',
      );
    });
  });
}
