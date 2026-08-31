import { describe, it, expect } from '@ohos/hypium';
import type { HttpRequest, HttpResponse } from '../main/ets/core/network/httpClient';
import {
  UserProfileHttpClient,
  UserProfileTokenStore,
  UserRepository,
  UserRepositoryOptions,
} from '../main/ets/services/user/userRepository';
import type { UpdateUserInfoRequest } from '../main/ets/services/user/UserModels';

class FakeUserProfileHttpClient implements UserProfileHttpClient {
  requests: HttpRequest[] = [];
  response: HttpResponse<string> = {
    status: 204,
    headers: {},
    text: '',
  };
  failure: Error | null = null;

  async request<T = Object>(request: HttpRequest): Promise<HttpResponse<T>> {
    this.requests.push(request);
    if (this.failure) {
      throw this.failure;
    }
    return this.response as HttpResponse<T>;
  }
}

class FakeUserProfileTokenStore implements UserProfileTokenStore {
  private readonly fakeCookie: string | null;

  constructor(fakeCookie: string | null) {
    this.fakeCookie = fakeCookie;
  }

  async getFakeCookie(): Promise<string | null> {
    return this.fakeCookie;
  }
}

const REQUEST: UpdateUserInfoRequest = {
  nickname: '新昵称',
  motto: '新签名',
  avatar_mid: 'avatar-mid-1',
};

export default function userProfileTest() {
  describe('User profile repository', () => {
    it('puts all profile fields with fake-cookie and accepts an empty 2xx response', 0, async () => {
      const http = new FakeUserProfileHttpClient();
      const options: UserRepositoryOptions = {
        httpClient: http,
        tokenStore: new FakeUserProfileTokenStore('fake-cookie-value'),
      };
      const repository = new UserRepository(options);

      await repository.updateUserInfo(REQUEST);

      expect(http.requests.length).assertEqual(1);
      expect(http.requests[0].url).assertEqual('/user/info');
      expect(http.requests[0].method).assertEqual('PUT');
      expect(http.requests[0].headers?.['fake-cookie']).assertEqual('fake-cookie-value');
      expect(JSON.stringify(http.requests[0].json)).assertEqual(JSON.stringify(REQUEST));
    });

    it('rejects a non-2xx response returned by an injected client', 0, async () => {
      const http = new FakeUserProfileHttpClient();
      http.response = {
        status: 500,
        headers: {},
        text: 'server failed',
      };
      const options: UserRepositoryOptions = {
        httpClient: http,
        tokenStore: new FakeUserProfileTokenStore('fake-cookie-value'),
      };
      const repository = new UserRepository(options);
      let errorMessage: string = '';

      try {
        await repository.updateUserInfo(REQUEST);
      } catch (error) {
        errorMessage = error instanceof Error ? error.message : String(error);
      }

      expect(errorMessage).assertContain('500');
    });

    it('propagates network failures', 0, async () => {
      const http = new FakeUserProfileHttpClient();
      http.failure = new Error('network unavailable');
      const options: UserRepositoryOptions = {
        httpClient: http,
        tokenStore: new FakeUserProfileTokenStore('fake-cookie-value'),
      };
      const repository = new UserRepository(options);
      let errorMessage: string = '';

      try {
        await repository.updateUserInfo(REQUEST);
      } catch (error) {
        errorMessage = error instanceof Error ? error.message : String(error);
      }

      expect(errorMessage).assertEqual('network unavailable');
    });

    it('does not send an update without a BIT101 session', 0, async () => {
      const http = new FakeUserProfileHttpClient();
      const options: UserRepositoryOptions = {
        httpClient: http,
        tokenStore: new FakeUserProfileTokenStore(null),
      };
      const repository = new UserRepository(options);
      let errorMessage: string = '';

      try {
        await repository.updateUserInfo(REQUEST);
      } catch (error) {
        errorMessage = error instanceof Error ? error.message : String(error);
      }

      expect(errorMessage).assertContain('fake_cookie');
      expect(http.requests.length).assertEqual(0);
    });
  });
}
