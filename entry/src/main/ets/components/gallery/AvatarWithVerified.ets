// entry/src/main/ets/components/gallery/AvatarWithVerified.ets
import { GalleryUser } from '../../services/gallery/GalleryModels';
import { RCP_BASE_URL } from '../../core/network/bit101Session';

@Component
export struct AvatarWithVerified {
  @Prop user: GalleryUser | null = null;
  // 🔴 修改：将 'size' 改名为 'avatarSize'
  @Prop avatarSize: number = 40;

  onClickUser?: () => void;

  private isVerified(): boolean {
    return !!this.user?.identity && this.user.identity.id !== 0 && !!this.user.identity.color;
  }

  private getAvatarUrl(): string | Resource {
    if (!this.user || !this.user.avatar) return $r('app.media.startIcon');
    if (this.user.avatar.startsWith('http')) return this.user.avatar;
    return `${RCP_BASE_URL}${this.user.avatar}`;
  }
  aboutToAppear() {
    // 打印整个 user 对象
    console.info('【调试头像】User:', JSON.stringify(this.user));

    if (this.user && this.user.identity) {
      console.info('【调试头像】Identity ID:', this.user.identity.id);
      console.info('【调试头像】Identity Color:', this.user.identity.color);
    } else {
      console.error('【调试头像】User 或 Identity 为空！');
    }
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      // 1. 头像
      Image(this.getAvatarUrl())
      // 🔴 修改：使用 this.avatarSize
        .width(this.avatarSize)
        .height(this.avatarSize)
        .borderRadius(this.avatarSize / 2)
        .objectFit(ImageFit.Cover)
        .backgroundColor('#F3F4F6')
        .onClick(() => {
          if (this.onClickUser) this.onClickUser();
        })

      // 2. 认证图标
      if (this.isVerified()) {
        Image($r('app.media.ic_verified'))
        // 🔴 修改：使用 this.avatarSize
          .width(this.avatarSize * 0.4)
          .height(this.avatarSize * 0.4)
          .fillColor(this.user!.identity!.color)
          // .fillColor('#FF0000')
          .margin({ right: -2, bottom: -2 })
          // 🔴 修改：使用 this.avatarSize
          .border({ width: 1, color: Color.White, radius: this.avatarSize * 0.2 })
      }
    }
    // 🔴 修改：使用 this.avatarSize
    .width(this.avatarSize)
    .height(this.avatarSize)
    .clip(false)
  }
}