import { DebugCase } from './DebugCase';
import { detectSchoolLoginMode } from '../services/school/SchoolNetworkProbe';
import { createBitSsoSessionAuto } from '../services/lexue/BitSsoAuto';

const WEBVPN_LEXUE_BASE =
  'https://webvpn.bit.edu.cn/https/77726476706e69737468656265737421fcf25989227e6a596a468ca88d1b203b';

export class SchoolNetworkProbeCase extends DebugCase {
  readonly name = 'School network probe';

  async run(): Promise<void> {
    this.logInfo('=== SchoolNetworkProbeCase START ===');

    try {
      const probeMode = await detectSchoolLoginMode({ debug: true });
      this.logInfo('probe mode =', probeMode);

      const { mode, sso } = await createBitSsoSessionAuto({
        debug: true,
        webvpnLexueBase: WEBVPN_LEXUE_BASE,
      });
      this.logInfo('auto session mode =', mode);
      this.logInfo('auto session ready =', sso.isFullyLoggedIn());
    } catch (e) {
      this.logError('SchoolNetworkProbeCase failed =', e);
    }

    this.logInfo('=== SchoolNetworkProbeCase END ===');
  }
}
