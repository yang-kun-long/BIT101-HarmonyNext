import { describe, it, expect } from '@ohos/hypium';
import { CookieDump } from '../main/ets/core/network/cookieJar';
import { RcpRequestOptions, RcpResponseData } from '../main/ets/core/network/rcpSession';
import {
  LexueBootstrap,
  LexueBootstrapAuth,
  LexueBootstrapClient,
} from '../main/ets/services/school/bootstrap/LexueBootstrap';
import { SchoolLoginResult } from '../main/ets/services/school/SchoolAuthTypes';

class FakeLexueAuth implements LexueBootstrapAuth {
  readonly calls: string[];

  constructor(calls: string[]) {
    this.calls = calls;
  }

  async loginWebvpnTarget(targetUrl: string, targetName: string): Promise<SchoolLoginResult> {
    this.calls.push(`target:${targetUrl}:${targetName}`);
    return {
      mode: 'webvpn',
      portalLoggedIn: true,
      targetLoggedIn: true,
      targetName,
      effectiveUrl: targetUrl,
    };
  }

  async loginInnerTarget(
    targetUrl: string,
    targetName: string,
    username: string,
    password: string,
  ): Promise<SchoolLoginResult> {
    this.calls.push(`inner:${targetUrl}:${targetName}:${username}:${password}`);
    return {
      mode: 'inner',
      portalLoggedIn: false,
      targetLoggedIn: true,
      targetName,
      effectiveUrl: targetUrl,
    };
  }

  getCookieDump(): CookieDump {
    this.calls.push('dump');
    return [
      {
        name: 'MoodleSession',
        value: 'session',
        domain: 'lexue.bit.edu.cn',
        path: '/',
        secure: false,
        httpOnly: false,
      },
    ];
  }
}

class FakeLexueClient implements LexueBootstrapClient {
  readonly calls: string[];

  constructor(calls: string[]) {
    this.calls = calls;
  }

  restoreFromDump(dump: CookieDump): void {
    this.calls.push(`restore:${dump.map((c) => c.name).join(',')}`);
  }

  async get(url: string, options?: RcpRequestOptions): Promise<RcpResponseData> {
    const referer = options?.headers?.Referer ?? '';
    this.calls.push(`get:${url}:${referer}`);
    return {
      statusCode: 200,
      headers: {},
      bodyText: '<html><input name="sesskey" value="abc123"></html>',
      effectiveUrl: url,
    };
  }
}

export default function lexueBootstrapTest() {
  describe('LexueBootstrap', () => {
    it('logs into WebVPN target then verifies export page sesskey', 0, async () => {
      const calls: string[] = [];
      const auth = new FakeLexueAuth(calls);
      const client = new FakeLexueClient(calls);
      const bootstrap = new LexueBootstrap(auth, client, {
        mode: 'webvpn',
        lexueBase: 'https://webvpn.bit.edu.cn/https/encoded/',
      });

      const result = await bootstrap.run();

      expect(result.success).assertTrue();
      expect(result.targetName).assertEqual('lexue');
      expect(result.details).assertEqual('sesskey=abc123');
      expect(calls.join('|')).assertEqual(
        'target:https://webvpn.bit.edu.cn/https/encoded/calendar/export.php:lexue|' +
          'dump|' +
          'restore:MoodleSession|' +
          'get:https://webvpn.bit.edu.cn/https/encoded/calendar/export.php:https://webvpn.bit.edu.cn/',
      );
    });

    it('verifies inner Lexue export page without WebVPN target login', 0, async () => {
      const calls: string[] = [];
      const auth = new FakeLexueAuth(calls);
      const client = new FakeLexueClient(calls);
      const bootstrap = new LexueBootstrap(auth, client, {
        mode: 'inner',
        lexueBase: 'https://lexue.bit.edu.cn/',
        username: 'u',
        password: 'p',
      });

      const result = await bootstrap.run();

      expect(result.success).assertTrue();
      expect(result.targetName).assertEqual('lexue');
      expect(result.details).assertEqual('sesskey=abc123');
      expect(calls.join('|')).assertEqual(
        'inner:https://lexue.bit.edu.cn/calendar/export.php:lexue:u:p|' +
          'dump|' +
          'restore:MoodleSession|' +
          'get:https://lexue.bit.edu.cn/calendar/export.php:https://lexue.bit.edu.cn/',
      );
    });
  });
}
