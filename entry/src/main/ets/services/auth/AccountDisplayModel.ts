import type { GalleryUser } from '../gallery/GalleryModels';
import type { UserInfoResponse } from '../user/userRepository';

export interface AccountDisplayAvatarInfo {
  url?: string;
  low_url?: string;
  lowUrl?: string;
}

export interface AccountDisplayUserInfo {
  sid?: string;
  id?: string | number;
  nickname?: string;
  motto?: string;
  avatar?: string | AccountDisplayAvatarInfo;
}

export type AccountLoginActionKind = 'login' | 'logout' | 'relogin';

export interface AccountLoginActionItem {
  kind: AccountLoginActionKind;
  title: string;
  subTitle: string;
}

export interface AccountDisplayModel {
  sid: string;
  user: GalleryUser;
  motto: string;
}

function resolveAvatarUrl(avatar: string | AccountDisplayAvatarInfo | undefined): string {
  if (avatar === undefined) {
    return '';
  }
  if (typeof avatar === 'string') {
    return avatar;
  }
  return avatar.url || avatar.low_url || avatar.lowUrl || '';
}

export function resolveAccountDisplaySid(
  currentUsername: string,
  userInfo: AccountDisplayUserInfo | null,
  persistedUsername: string = '',
): string {
  const storageUsername: string = currentUsername.trim();
  if (storageUsername.length > 0) {
    return storageUsername;
  }

  const persisted: string = persistedUsername.trim();
  if (persisted.length > 0) {
    return persisted;
  }

  const sid: string = userInfo?.sid === undefined || userInfo?.sid === null ? '' : String(userInfo.sid).trim();
  return sid;
}

export function buildAccountDisplayModel(
  currentUsername: string,
  userInfo: AccountDisplayUserInfo | null,
  persistedUsername: string = '',
): AccountDisplayModel {
  const sid: string = resolveAccountDisplaySid(currentUsername, userInfo, persistedUsername);
  const id: string = userInfo?.id === undefined || userInfo?.id === null ? '' : String(userInfo.id).trim();
  const nickname: string = userInfo?.nickname === undefined || userInfo?.nickname === null
    ? ''
    : String(userInfo.nickname).trim();
  const motto: string = userInfo?.motto === undefined || userInfo?.motto === null
    ? ''
    : String(userInfo.motto).trim();

  return {
    sid,
    user: {
      id,
      nickname,
      avatar: resolveAvatarUrl(userInfo?.avatar),
    },
    motto,
  };
}

export function hasAccountDisplayProfile(model: AccountDisplayModel): boolean {
  return model.user.id.length > 0 || model.user.nickname.length > 0 || model.user.avatar.length > 0 || model.motto.length > 0;
}

export function buildAccountDisplayModelFromCurrentUser(
  currentUsername: string,
  response: UserInfoResponse,
): AccountDisplayModel {
  return {
    sid: currentUsername.trim(),
    user: {
      id: String(response.user.id),
      nickname: response.user.nickname,
      avatar: response.user.avatar.url || response.user.avatar.low_url || '',
      identity: response.user.identity,
    },
    motto: response.user.motto,
  };
}

export function buildAccountLoginActionItem(ifLogin: boolean, loginStatusText: string): AccountLoginActionItem {
  if (!ifLogin) {
    return {
      kind: 'login',
      title: '登录',
      subTitle: '',
    };
  }

  if (loginStatusText === '部分异常') {
    return {
      kind: 'relogin',
      title: '重新登录',
      subTitle: '重新建立教务应用登录态，用于考试和空教室',
    };
  }

  return {
    kind: 'logout',
    title: '退出登录',
    subTitle: '清除所有登录状态',
  };
}
