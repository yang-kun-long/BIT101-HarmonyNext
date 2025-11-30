import { GalleryUser } from '../../services/gallery/GalleryModels';

// 1. 用户操作按钮 (关注/私信/主页)
@Component
export struct UserInfoButton {
  @Prop text: string;
  @Prop enable: boolean = true;
  @Prop isPrimary: boolean = true;

  // 自定义回调
  onAction: () => void = () => {};

  build() {
    Row() {
      Text(this.text)
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.isPrimary ? Color.White : $r('sys.color.ohos_id_color_text_primary'))
    }
    .height(28)
    .padding({ left: 12, right: 12 })
    .backgroundColor(this.isPrimary ? $r('sys.color.ohos_id_color_primary') : $r('sys.color.ohos_id_color_sub_background'))
    .borderRadius(14)
    .opacity(this.enable ? 1.0 : 0.6)
    .onClick(() => {
      if (this.enable) {
        this.onAction();
      }
    })
  }
}

// 2. 粉丝/关注 统计信息项
@Component
struct FollowInfoItem {
  @Prop count: string;
  @Prop label: string;

  onItemClick: () => void = () => {};

  build() {
    Row() {
      Text(this.count)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))

      Text(` ${this.label}`)
        .fontSize(12)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        .margin({ left: 4 }) // 使用 margin 替代之前的空格微调
    }
    .onClick(() => {
      this.onItemClick();
    })
  }
}

// 3. 粉丝/关注 统计栏容器
@Component
export struct FollowInfo {
  @Prop followerNum: number;
  @Prop followingNum: number;

  build() {
    Row() {
      FollowInfoItem({ count: this.followerNum.toString(), label: "粉丝" })

      // 分割线
      Divider()
        .vertical(true)
        .height(12)
        .color(Color.Gray)
        .margin({ left: 12, right: 12 })
        .opacity(0.5)

      FollowInfoItem({ count: this.followingNum.toString(), label: "关注" })
    }
  }
}

// 4. [核心] 头像 + 名字 + 按钮插槽
@Component
export struct AvatarWithName {
  @ObjectLink user: GalleryUser;

  // 定义默认 builder 防止未初始化错误
  @BuilderParam actionButton: () => void = this.emptyBuilder;
  @Builder emptyBuilder() {}

  @Prop createTime: string = "";

  private getJoinTime(): string {
    if (!this.createTime) return "未知时间";
    return this.createTime.split(' ')[0] + "加入";
  }

  build() {
    Column() {
      // 上部分：居中布局
      Column() {
        // 1. 头像 (下边距替代 Spacer)
        Image(this.user.avatar)
          .width(78)
          .height(78)
          .borderRadius(39)
          .backgroundColor('#f0f0f0')
          .objectFit(ImageFit.Cover)
          .margin({ bottom: 8 })

        // 2. 名字 + 按钮 (下边距替代 Spacer)
        Row() {
          // 名字
          Text(this.user.nickname)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))

          // 身份标签 (左边距)
          if (this.user.identity && this.user.identity.text) {
            Text(this.user.identity.text)
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.user.identity.color || Color.Gray)
              .margin({ left: 6 })
          }

          // 按钮插槽 (容器左边距)
          Row() {
            this.actionButton()
          }
          .margin({ left: 8 })
        }
        .alignItems(VerticalAlign.Center)
        .margin({ bottom: 6 })

        // 3. UID 和 时间
        Row() {
          // UID
          Row() {
            Text("#")
              .fontSize(12)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
              .opacity(0.5)

            Text(`UID: ${this.user.id}`)
              .fontSize(12)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
              .opacity(0.5)
              .margin({ left: 2 })
          }

          // 中间间距 (左边距替代 Spacer)
          Row() {
            Text("@")
              .fontSize(12)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
              .opacity(0.5)

            Text(this.getJoinTime())
              .fontSize(12)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
              .opacity(0.5)
              .margin({ left: 2 })
          }
          .margin({ left: 12 }) // 替代 Spacer().width(12)
        }
        .justifyContent(FlexAlign.Center)
        .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .padding({ top: 12, bottom: 12 })
  }
}