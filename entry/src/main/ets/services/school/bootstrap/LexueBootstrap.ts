import { CookieDump } from '../../../core/network/cookieJar';
import { RcpRequestOptions, RcpResponseData } from '../../../core/network/rcpSession';
import { Logger } from '../../../utils/Logger';
import { SchoolBootstrap } from '../SchoolBootstrap';
import {
  SchoolBootstrapResult,
  SchoolLoginMode,
  SchoolLoginResult,
} from '../SchoolAuthTypes';

const WEBVPN_PORTAL_HOME = 'https://webvpn.bit.edu.cn/';

export interface LexueBootstrapAuth {
  loginWebvpnTarget(targetUrl: string, targetName: string): Promise<SchoolLoginResult>;
  loginInnerTarget(
    targetUrl: string,
    targetName: string,
    username: string,
    password: string,
  ): Promise<SchoolLoginResult>;
  getCookieDump(): CookieDump;
}

export interface LexueBootstrapClient {
  get(url: string, options?: RcpRequestOptions): Promise<RcpResponseData>;
  restoreFromDump?(dump: CookieDump): void;
}

export interface LexueBootstrapOptions {
  mode: SchoolLoginMode;
  lexueBase: string;
  username?: string;
  password?: string;
  debug?: boolean;
}

function looksLikeSchoolLoginPage(html: string): boolean {
  if (!html) return false;
  return html.includes('统一身份认证') || html.includes('帐号登录或动态码登录');
}

export function extractLexueBootstrapSesskey(html: string): string {
  let m = html.match(
    /<input[^>]+name=["']sesskey["'][^>]+value=["']([^"']+)["']/i,
  );
  if (m && m[1]) {
    return m[1];
  }

  m = html.match(/M\.cfg\s*=\s*\{[^}]*"sesskey"\s*:\s*"([^"]+)"/i);
  if (m && m[1]) {
    return m[1];
  }

  m = html.match(/"sesskey"\s*:\s*"([^"]+)"/i);
  if (m && m[1]) {
    return m[1];
  }

  return '';
}

export class LexueBootstrap implements SchoolBootstrap {
  private readonly auth: LexueBootstrapAuth;
  private readonly client: LexueBootstrapClient;
  private readonly options: LexueBootstrapOptions;
  private readonly logger = new Logger('LexueBootstrap');

  constructor(
    auth: LexueBootstrapAuth,
    client: LexueBootstrapClient,
    options: LexueBootstrapOptions,
  ) {
    this.auth = auth;
    this.client = client;
    this.options = options;
  }

  async run(): Promise<SchoolBootstrapResult> {
    if (this.options.mode === 'webvpn') {
      return await this.runWebvpn();
    }
    return await this.runInner();
  }

  private async runInner(): Promise<SchoolBootstrapResult> {
    const base = this.options.lexueBase.replace(/\/+$/, '');
    const exportUrl = `${base}/calendar/export.php`;
    if (!this.options.username || !this.options.password) {
      throw new Error('[LexueBootstrap] inner mode requires username and password');
    }

    const targetResult = await this.auth.loginInnerTarget(
      exportUrl,
      'lexue',
      this.options.username,
      this.options.password,
    );
    this.client.restoreFromDump?.(this.auth.getCookieDump());
    const exportResp = await this.client.get(exportUrl, {
      autoRedirect: true,
      collectTimeInfo: false,
      headers: {
        Referer: `${base}/`,
      },
    });

    const sesskey = this.assertExportPageUsable(exportResp, 'inner');

    if (this.options.debug) {
      this.logger.info('inner target effectiveUrl =', targetResult.effectiveUrl);
      this.logger.info('inner export.php effectiveUrl =', exportResp.effectiveUrl);
      this.logger.debug('sesskey =', sesskey);
    }

    return {
      targetName: 'lexue',
      success: true,
      effectiveUrl: String(exportResp.effectiveUrl ?? targetResult.effectiveUrl ?? ''),
      details: `sesskey=${sesskey}`,
    };
  }

  private async runWebvpn(): Promise<SchoolBootstrapResult> {
    const base = this.options.lexueBase.replace(/\/+$/, '');
    const exportUrl = `${base}/calendar/export.php`;
    const targetResult = await this.auth.loginWebvpnTarget(exportUrl, 'lexue');
    this.client.restoreFromDump?.(this.auth.getCookieDump());

    const exportResp = await this.client.get(exportUrl, {
      autoRedirect: true,
      collectTimeInfo: false,
      headers: {
        Referer: WEBVPN_PORTAL_HOME,
      },
    });

    const sesskey = this.assertExportPageUsable(exportResp, 'WebVPN');

    if (this.options.debug) {
      this.logger.info('target effectiveUrl =', targetResult.effectiveUrl);
      this.logger.info('export.php effectiveUrl =', exportResp.effectiveUrl);
      this.logger.debug('sesskey =', sesskey);
    }

    return {
      targetName: 'lexue',
      success: true,
      effectiveUrl: String(exportResp.effectiveUrl ?? targetResult.effectiveUrl ?? ''),
      details: `sesskey=${sesskey}`,
    };
  }

  private assertExportPageUsable(exportResp: RcpResponseData, modeLabel: string): string {
    if (exportResp.statusCode !== 200) {
      throw new Error(
        `[LexueBootstrap] ${modeLabel} Lexue 导出页校验失败：HTTP ${exportResp.statusCode}`,
      );
    }

    if (looksLikeSchoolLoginPage(exportResp.bodyText)) {
      throw new Error(`[LexueBootstrap] ${modeLabel} Lexue 导出页仍然是统一身份认证登录页`);
    }

    const sesskey = extractLexueBootstrapSesskey(exportResp.bodyText ?? '');
    if (!sesskey) {
      const preview = (exportResp.bodyText ?? '').replace(/\s+/g, ' ').slice(0, 300);
      throw new Error(
        `[LexueBootstrap] ${modeLabel} Lexue 导出页未解析到 sesskey，preview=${preview}`,
      );
    }

    return sesskey;
  }
}
