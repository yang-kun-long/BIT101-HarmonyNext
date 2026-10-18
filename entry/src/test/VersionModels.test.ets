import { describe, it, expect } from '@ohos/hypium';
import { evaluateVersion, isHarmonyPlatform, parseVersionInfo, resolveUpdateUrl, HARMONY_PROJECT_URL } from '../main/ets/services/version/VersionModels';
import type { HttpRequest, HttpResponse } from '../main/ets/core/network/httpClient';
import { VersionService, VersionHttpClient } from '../main/ets/services/version/VersionService';

class VersionPayload {
  min_version_code: number = 4;
  min_version_name: string = '1.3.0';
  version_code: number = 6;
  version_name: string = '1.4.0';
  url: string = 'https://example.invalid/bit101-harmonyos.hap';
  msg: string = '新增消息中心';
  platform: string = 'harmonyos';
}

class MissingVersionPayload {
  version_code: number = 6;
}

class MalformedVersionPayload {
  min_version_code: number = 4;
  min_version_name: string = '1.3.0';
  version_code: string = '6';
  version_name: string = '1.4.0';
  url: string = 'https://example.invalid/bit101-harmonyos.hap';
  msg: string = '新增消息中心';
}

class AndroidVersionPayload extends VersionPayload {
  platform: string = 'android';
}

const PAYLOAD: VersionPayload = new VersionPayload();

class ResponseVersionClient implements VersionHttpClient {
  response: HttpResponse<Object> = { status: 200, headers: {}, text: '' };
  failure: Error | null = null;

  async request<T = Object>(_request: HttpRequest): Promise<HttpResponse<T>> {
    if (this.failure !== null) throw this.failure;
    return this.response as HttpResponse<T>;
  }
}

export default function versionModelsTest() {
  describe('Version models', () => {
    it('never reports up to date for an empty or malformed successful response', 0, async () => {
      const http = new ResponseVersionClient();
      const service = new VersionService({ httpClient: http });
      for (const body of ['', 'null', '{}', '{']) {
        http.response.text = body;
        let failed = false;
        try { await service.check(6); } catch (_) { failed = true; }
        expect(failed).assertTrue();
      }
    });
    it('falls back to the project for absent, unsafe or Android update URLs', 0, () => {
      expect(resolveUpdateUrl('')).assertEqual(HARMONY_PROJECT_URL);
      expect(resolveUpdateUrl('javascript:alert(1)')).assertEqual(HARMONY_PROJECT_URL);
      expect(resolveUpdateUrl('https://android.bit101.cn/app%2eapk?download=1')).assertEqual(HARMONY_PROJECT_URL);
      expect(resolveUpdateUrl('https://example.org/app.apk')).assertEqual(HARMONY_PROJECT_URL);
      expect(resolveUpdateUrl('https://example.org/app.hap')).assertEqual('https://example.org/app.hap');
    });
    it('parses the Android-compatible snake_case payload and keeps platform', 0, () => {
      const result = parseVersionInfo(PAYLOAD);
      expect(result.minVersionCode).assertEqual(4);
      expect(result.versionCode).assertEqual(6);
      expect(result.versionName).assertEqual('1.4.0');
      expect(result.message).assertEqual('新增消息中心');
      expect(result.platform).assertEqual('harmonyos');
    });

    it('rejects missing or malformed required fields', 0, () => {
      let message = '';
      try {
        parseVersionInfo(new MissingVersionPayload());
      } catch (error) {
        message = error instanceof Error ? error.message : String(error);
      }
      expect(message).assertContain('min_version_code');

      message = '';
      try {
        parseVersionInfo(new MalformedVersionPayload());
      } catch (error) {
        message = error instanceof Error ? error.message : String(error);
      }
      expect(message).assertContain('version_code');
    });

    it('forces an update below the minimum version', 0, () => {
      const result = evaluateVersion(3, parseVersionInfo(PAYLOAD));
      expect(result.decision).assertEqual('forced_update');
    });

    it('honors an ignored optional update but never ignores a forced update', 0, () => {
      const latest = parseVersionInfo(PAYLOAD);
      expect(evaluateVersion(5, latest, 6).decision).assertEqual('ignored');
      expect(evaluateVersion(3, latest, 6).decision).assertEqual('forced_update');
    });

    it('requires an explicit HarmonyOS platform before using a channel-specific response', 0, () => {
      expect(isHarmonyPlatform('harmonyos')).assertTrue();
      expect(isHarmonyPlatform('OHOS')).assertTrue();
      expect(isHarmonyPlatform(null)).assertFalse();
      expect(isHarmonyPlatform('android')).assertFalse();
    });

    it('fetches /version through an injected client and evaluates the result', 0, async () => {
      class FakeVersionClient implements VersionHttpClient {
        requests: HttpRequest[] = [];

        async request<T = Object>(request: HttpRequest): Promise<HttpResponse<T>> {
          this.requests.push(request);
          return { status: 200, headers: {}, text: '', data: PAYLOAD } as HttpResponse<T>;
        }
      }

      const http = new FakeVersionClient();
      const service = new VersionService({ httpClient: http });
      const result = await service.check(5);
      expect(http.requests.length).assertEqual(1);
      expect(http.requests[0].url).assertEqual('/version');
      expect(http.requests[0].method).assertEqual('GET');
      expect(result.decision).assertEqual('update_available');
    });

    it('rejects an explicitly Android-only channel', 0, async () => {
      class FakeVersionClient implements VersionHttpClient {
        async request<T = Object>(_request: HttpRequest): Promise<HttpResponse<T>> {
          return { status: 200, headers: {}, text: '', data: new AndroidVersionPayload() } as HttpResponse<T>;
        }
      }

      let message = '';
      try {
        await new VersionService({ httpClient: new FakeVersionClient() }).fetchLatest();
      } catch (error) {
        message = error instanceof Error ? error.message : String(error);
      }
      expect(message).assertContain('not confirmed for harmonyos');
    });

    it('rejects the existing platformless Android contract', 0, async () => {
      const http = new ResponseVersionClient();
      http.response.text = '{"min_version_code":4,"min_version_name":"1.3.0","version_code":6,"version_name":"1.4.0","url":"https://android.bit101.cn/app.apk","msg":"update"}';
      let message = '';
      try { await new VersionService({ httpClient: http }).fetchLatest(); }
      catch (error) { message = error instanceof Error ? error.message : String(error); }
      expect(message).assertContain('not confirmed for harmonyos');
    });

    it('parses a text response and rejects non-2xx and network failures', 0, async () => {
      const http = new ResponseVersionClient();
      http.response.text = JSON.stringify(PAYLOAD);
      const service = new VersionService({ httpClient: http });
      expect((await service.check(6)).decision).assertEqual('up_to_date');
      http.response.status = 500;
      let message = '';
      try { await service.fetchLatest(); }
      catch (error) { message = error instanceof Error ? error.message : String(error); }
      expect(message).assertContain('500');
      http.failure = new Error('offline');
      try { await service.fetchLatest(); }
      catch (error) { message = error instanceof Error ? error.message : String(error); }
      expect(message).assertEqual('offline');
    });
  });
}
