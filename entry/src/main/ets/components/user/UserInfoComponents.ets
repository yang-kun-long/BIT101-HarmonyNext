// entry/src/main/ets/components/user/UserInfoComponents.ets
import { GalleryUser } from '../../services/gallery/GalleryModels';

// 1. 用户操作按钮 (关注/私信/主页)
@Component
export struct UserInfoButton {
  @Prop text: string;
  @Prop enable: boolean = true;
  @Prop isPrimary: boolean = true; // isPrimary=true 代表"未关注/主要操作"

  // 自定义回调
  onAction: () => void = () => {};

  build() {
    Row() {
      Text(this.text)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        // [Android对齐] 文字颜色使用 Primary 色 (Android源码: MaterialTheme.colorScheme.primary)
        // 注意：如果你的 App 还没配置粉色主题，这里会显示系统默认蓝。
        .fontColor($r('sys.color.ohos_id_color_primary'))
        // "已关注"状态下文字透明度 0.5
        .opacity(this.isPrimary ? 1.0 : 0.5)
    }
    .height(32)
    .padding({ left: 16, right: 16 })
    // [Android对齐] 背景使用 PrimaryContainer (Android源码: MaterialTheme.colorScheme.primaryContainer)
    // 通常是极浅的主题色背景
    .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
    // "已关注"状态下背景透明度 0.5
    .opacity(this.isPrimary ? 1.0 : 0.5)
    .borderRadius(16)
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
        .margin({ left: 4 })
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

      Divider()
        .vertical(true)
        .height(12)
        .color($r('sys.color.ohos_id_color_list_separator'))
        .margin({ left: 16, right: 16 })

      FollowInfoItem({ count: this.followingNum.toString(), label: "关注" })
    }
  }
}

// 4. [核心] 头像 + 名字 + 按钮插槽
@Component
export struct AvatarWithName {
  @ObjectLink user: GalleryUser;
  @BuilderParam actionButton: () => void = this.emptyBuilder;
  @Builder emptyBuilder() {}

  @Prop createTime: string = "";

  // [Android对齐] 时间格式化逻辑
  // 规则：今年显示 "MM月dd日"，往年显示 "yyyy年MM月dd日"
  private getJoinTime(): string {
    if (!this.createTime) return "";

    try {
      // 兼容处理时间字符串
      let dateStr = this.createTime.replace(/-/g, '/');
      let date = new Date(dateStr);

      if (isNaN(date.getTime())) {
        return this.createTime.substring(0, 10) + "加入";
      }

      const now = new Date();
      const isSameYear = date.getFullYear() === now.getFullYear();

      const month = date.getMonth() + 1;
      const day = date.getDate();

      let result = "";
      if (isSameYear) {
        result = `${month}月${day}日`;
      } else {
        result = `${date.getFullYear()}年${month}月${day}日`;
      }

      return result + "加入";

    } catch (e) {
      return this.createTime;
    }
  }

  build() {
    Column() {
      // 上部分：居中布局
      Column() {
        // 1. 头像
        Image(this.user.avatar)
          .width(80)
          .height(80)
          .borderRadius(40)
          .backgroundColor('#f0f0f0')
          .objectFit(ImageFit.Cover)
          .margin({ bottom: 12 })
          .border({ width: 0.5, color: '#1A000000' })

        // 2. 名字 + 按钮
        Row() {
          Text(this.user.nickname)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))

          if (this.user.identity && this.user.identity.text) {
            Text(this.user.identity.text)
              .fontSize(10)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
              .backgroundColor(this.user.identity.color || '#CCCCCC')
              .padding({ left: 4, right: 4, top: 1, bottom: 1 })
              .borderRadius(4)
              .margin({ left: 6 })
          }

          Row() {
            this.actionButton()
          }
          .margin({ left: 8 })
        }
        .alignItems(VerticalAlign.Center)
        .margin({ bottom: 8 })

        // 3. UID 和 时间
        Row() {
          Text(`UID: ${this.user.id}`)
            .fontSize(12)
            .fontColor($r('sys.color.ohos_id_color_text_tertiary'))

          if (this.getJoinTime()) {
            Text("·")
              .fontSize(12)
              .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
              .margin({ left: 6, right: 6 })

            // ✅ [新增] 补上小图标 (Icons.Rounded.DateRange)
            SymbolGlyph($r('sys.symbol.calendar'))
              .fontSize(14)
              .fontColor([$r('sys.color.ohos_id_color_text_tertiary')])
              .margin({ right: 2 })

            Text(this.getJoinTime())
              .fontSize(12)
              .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
          }
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