import { DebugCase } from './DebugCase';
import { TEST_PASSWORD, TEST_USERNAME } from './local.secret';
import SimpleCookieJar, { CookieDump } from '../core/network/cookieJar';
import RcpSession, { RcpRequestOptions, RcpResponseData } from '../core/network/rcpSession';
import { SchoolAuthService } from '../services/school/SchoolAuthService';
import { LexueBootstrap, LexueBootstrapClient } from '../services/school/bootstrap/LexueBootstrap';
import { detectSchoolLoginMode } from '../services/school/SchoolNetworkProbe';
import type { SchoolLoginMode } from '../services/school/SchoolAuthTypes';

const WEBVPN_LEXUE_BASE =
  'https://webvpn.bit.edu.cn/https/77726476706e69737468656265737421fcf25989227e6a596a468ca88d1b203b';
const INNER_LEXUE_BASE = 'https://lexue.bit.edu.cn';

class LexueBootstrapDebugClient implements LexueBootstrapClient {
  private readonly session: RcpSession;
  private readonly jar: SimpleCookieJar;

  constructor(session: RcpSession, jar: SimpleCookieJar) {
    this.session = session;
    this.jar = jar;
  }

  restoreFromDump(dump: CookieDump): void {
    this.jar.restoreFromDump(dump);
  }

  async get(url: string, options?: RcpRequestOptions): Promise<RcpResponseData> {
    return await this.session.get(url, options);
  }
}

export class LexueBootstrapCase extends DebugCase {
  readonly name = 'Lexue bootstrap auto';

  async run(): Promise<void> {
    this.logInfo('=== LexueBootstrapCase START ===');

    if (!TEST_USERNAME || !TEST_PASSWORD) {
      this.logInfo('Missing TEST_USERNAME / TEST_PASSWORD in local.secret.ts');
      this.logInfo('=== LexueBootstrapCase ABORT ===');
      this.fail('Missing TEST_USERNAME / TEST_PASSWORD in local.secret.ts');
    }

    const auth = new SchoolAuthService({ debug: true });

    try {
      const mode: SchoolLoginMode = await detectSchoolLoginMode({ debug: true });
      this.logInfo('detected school login mode =', mode);

      const jar = new SimpleCookieJar();
      if (mode === 'webvpn') {
        const portalResult = await auth.loginWebvpnPortal(TEST_USERNAME, TEST_PASSWORD);
        this.logInfo('portal result =', portalResult);
        jar.restoreFromDump(auth.getCookieDump());
      }

      const client = new RcpSession({
        debug: true,
        timeoutMs: 15000,
        defaultHeaders: {
          'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36',
        },
        cookieJar: jar,
      });
      const bootstrapClient = new LexueBootstrapDebugClient(client, jar);

      const bootstrap = new LexueBootstrap(auth, bootstrapClient, {
        mode,
        lexueBase: mode === 'inner' ? INNER_LEXUE_BASE : WEBVPN_LEXUE_BASE,
        username: TEST_USERNAME,
        password: TEST_PASSWORD,
        debug: true,
      });
      const result = await bootstrap.run();
      this.logInfo('bootstrap result =', result);
      this.logInfo('cookie names =', auth.getCookieDump().map((c) => c.name));

      this.assertTrue(result.success, 'Lexue bootstrap should succeed');
      this.assertEquals(result.targetName, 'lexue', 'targetName should be lexue');
      this.assertTrue(
        (result.details ?? '').includes('sesskey='),
        'Lexue bootstrap should parse sesskey',
      );
    } catch (e) {
      this.logError('LexueBootstrapCase failed =', e);
      throw e;
    }

    this.logInfo('=== LexueBootstrapCase END ===');
  }
}
