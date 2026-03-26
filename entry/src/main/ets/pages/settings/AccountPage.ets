import { router, promptAction } from '@kit.ArkUI';
import photoAccessHelper from '@ohos.file.photoAccessHelper';
import { BusinessError } from '@kit.BasicServicesKit';
import { TokenStore } from '../../services/storage/tokenStore';
import { GalleryUser } from '../../services/gallery/GalleryModels';
import { uiBack, uiClear, uiPushUrl, uiReplaceUrl, uiShowToast } from '../../utils/uiContextBridge';

// ----------------------------------------------------------------------------
// 1. 主页面结构
// ----------------------------------------------------------------------------

@Entry
@Component
struct AccountPage {
  // --- 状态管理 ---
  @State ifLogin: boolean = true;
  @State checkingLogin: boolean = false;
  @State updatingUserInfo: boolean = false;

  // 用户数据
  @State user: GalleryUser = {
    id: "1120202222",
    nickname: "BIT101_User",
    avatar: "",
  } as GalleryUser;
  @State userMotto: string = "行胜于言";
  @State sid: string = "1120202222";

  // --- 弹窗控制器 ---
  nicknameDialogController: CustomDialogController = new CustomDialogController({
    builder: EditDialog({
      title: '修改昵称',
      textValue: this.user?.nickname || '', // 安全访问
      onConfirm: (val: string) => {
        this.updatingUserInfo = true;
        setTimeout(() => {
          if (this.user) {
            this.user.nickname = val;
          }
          this.updatingUserInfo = false;
          uiShowToast(this.getUIContext(), { message: "昵称更新成功" });
        }, 500);
      }
    }),
    alignment: DialogAlignment.Center,
    autoCancel: true,
    customStyle: true
  });

  mottoDialogController: CustomDialogController = new CustomDialogController({
    builder: EditDialog({
      title: '修改个性签名',
      textValue: this.userMotto,
      onConfirm: (val: string) => {
        this.updatingUserInfo = true;
        setTimeout(() => {
          this.userMotto = val;
          this.updatingUserInfo = false;
          uiShowToast(this.getUIContext(), { message: "个性签名更新成功" });
        }, 500);
      }
    }),
    alignment: DialogAlignment.Center,
    autoCancel: true,
    customStyle: true
  });

  build() {
    Column() {
      // 1. TopBar
      Row() {
        Image($r('app.media.ic_chevron_left'))
          .width(24)
          .height(24)
          .fillColor($r('sys.color.ohos_id_color_text_primary'))
          .onClick(() => { uiBack(this.getUIContext()); })

        Text("账号设置")
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .margin({ left: 16 })
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
      }
      .width('100%')
      .height(56)
      .padding({ left: 16 })
      .backgroundColor($r('sys.color.ohos_id_color_background'))

      // 2. 内容列表
      List() {
        // --- Group 1: 个人信息 ---
        if (this.ifLogin) {
          ListItem() {
            SettingsGroup({ title: "个人信息" }) {
              Column() {
                // 1. 头像
                SettingItem({
                  title: "头像",
                  enable: !this.updatingUserInfo,
                  onItemClick: () => { this.handlePickAvatar() },
                  // 【修复点 1】使用闭包包裹，确保 this 指向正确
                  customRightView: () => { this.AvatarView() }
                })
                Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

                // 2. 昵称
                SettingItem({
                  title: "昵称",
                  // 【修复点 2】安全访问
                  valueText: this.user?.nickname || "",
                  enable: !this.updatingUserInfo,
                  onItemClick: () => { this.nicknameDialogController.open() }
                })
                Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

                // 3. 个性签名
                SettingItem({
                  title: "个性签名",
                  valueText: this.userMotto,
                  enable: !this.updatingUserInfo,
                  onItemClick: () => { this.mottoDialogController.open() }
                })
                Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

                // 4. 学号 (ReadOnly)
                SettingItem({
                  title: "学号",
                  valueText: this.sid,
                  showArrow: false
                })
                Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

                // 5. UID (ReadOnly)
                SettingItem({
                  title: "UID",
                  // 【修复点 3】安全访问
                  valueText: this.user?.id || "",
                  showArrow: false
                })
              }
            }
          }
          .padding({ left: 16, right: 16, top: 16 })
        }

        // --- Group 2: 登录状态 ---
        ListItem() {
          SettingsGroup({ title: "登录状态" }) {
            Column() {
              // 1. 登录状态检查
              SettingItem({
                title: "登录状态检查",
                subTitle: "登录分为两步，首先进行学校统一身份认证，然后登录BIT101。\n点击检查二者登录状态，如果检查登录的结果为“未登录”，APP会根据之前自动加密保存的密码尝试重新登录。",
                valueText: this.ifLogin ? "已登录" : "未登录",
                enable: !this.checkingLogin,
                onItemClick: () => { this.handleCheckLogin() }
              })

              Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

              // 2. 退出登录 / 登录
              if (this.ifLogin) {
                SettingItem({
                  title: "退出登录",
                  subTitle: "清除所有登录状态和保存的账号密码",
                  onItemClick: () => { this.handleLogout() }
                })
              } else {
                SettingItem({
                  title: "登录",
                  onItemClick: () => { this.handleLogin() }
                })
              }
            }
          }
        }
        .padding({ left: 16, right: 16, top: 16, bottom: 32 })
      }
      .width('100%')
      .layoutWeight(1)
    }
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  // --- ViewBuilders & Logic ---

  @Builder
  AvatarView() {
    // 【修复点 4】终极防御：如果 user 为空，给一个兜底，虽然上面改了调用方式应该不会空了
    if (this.user) {
      Image(this.user.avatar || $r('app.media.ic_face'))
        .width(40)
        .height(40)
        .borderRadius(20)
        .fillColor($r('sys.color.ohos_id_color_text_secondary'))
    } else {
      // user 尚未初始化时的占位
      Row().width(40).height(40).backgroundColor(Color.Gray).borderRadius(20)
    }
  }

  handleCheckLogin() {
    this.checkingLogin = true;
    uiShowToast(this.getUIContext(), { message: "正在检查登录状态..." });
    setTimeout(() => {
      this.checkingLogin = false;
      uiShowToast(this.getUIContext(), { message: "登录状态检查成功" });
    }, 1500);
  }

  async handleLogout() {
    const tokenStore = new TokenStore();
    await tokenStore.clear();
    this.ifLogin = false;
    uiClear(this.getUIContext());
    uiReplaceUrl(this.getUIContext(), { url: 'pages/LoginPage' });
  }

  handleLogin() {
    uiPushUrl(this.getUIContext(), { url: 'pages/LoginPage' });
  }

  async handlePickAvatar() {
    try {
      const photoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
      photoSelectOptions.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      photoSelectOptions.maxSelectNumber = 1;

      const photoViewPicker = new photoAccessHelper.PhotoViewPicker();
      const photoSelectResult: photoAccessHelper.PhotoSelectResult = await photoViewPicker.select(photoSelectOptions);

      if (photoSelectResult.photoUris.length > 0) {
        const uri: string = photoSelectResult.photoUris[0];
        // 确保 user 存在再赋值
        if (this.user) {
          this.user.avatar = uri;
          uiShowToast(this.getUIContext(), { message: "头像已选择" });
        }
      }
    } catch (err) {
      const error = err as BusinessError;
      console.error(`PhotoViewPicker failed, code is ${error.code}, message is ${error.message}`);
    }
  }
}


// ----------------------------------------------------------------------------
// 2. 组件封装
// ----------------------------------------------------------------------------

@Component
struct SettingsGroup {
  @Prop title: string;
  @BuilderParam content: () => void;

  build() {
    Column() {
      if (this.title) {
        Text(this.title)
          .fontSize(14)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .fontWeight(FontWeight.Medium)
          .margin({ bottom: 8, left: 4 })
          .width('100%')
      }

      Column() {
        this.content()
      }
      .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
      .borderRadius(12)
      .clip(true)
    }
    .width('100%')
  }
}

@Component
struct SettingItem {
  @Prop title: string;
  @Prop subTitle: string = "";
  @Prop valueText: string = "";
  @Prop showArrow: boolean = true;
  @Prop enable: boolean = true;

  @BuilderParam customRightView?: () => void;

  onItemClick: () => void = () => {};

  build() {
    Row() {
      Column() {
        Text(this.title)
          .fontSize(16)
          .fontColor(this.enable ? $r('sys.color.ohos_id_color_text_primary') : $r('sys.color.ohos_id_color_text_tertiary'))

        if (this.subTitle) {
          Text(this.subTitle)
            .fontSize(12)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .margin({ top: 4 })
            .lineHeight(16)
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .padding({ right: 12 })

      if (this.customRightView) {
        this.customRightView()
      } else if (this.valueText) {
        Text(this.valueText)
          .fontSize(14)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }

      if (this.showArrow) {
        Image($r('app.media.ic_chevron_right'))
          .width(20)
          .height(20)
          .margin({ left: 4 })
          .fillColor(this.enable ? $r('sys.color.ohos_id_color_text_tertiary') : Color.Transparent)
      } else {
        Row().width(4)
      }
    }
    .width('100%')
    .constraintSize({ minHeight: 56 })
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor(Color.Transparent)
    .opacity(this.enable ? 1 : 0.6)
    .enabled(this.enable)
    .onClick(() => {
      if (this.enable) {
        this.onItemClick();
      }
    })
  }
}

@CustomDialog
struct EditDialog {
  controller: CustomDialogController;
  title: string = '';
  @State textValue: string = '';
  onConfirm: (val: string) => void = () => {};

  build() {
    Column() {
      Text(this.title)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .padding({ top: 24, bottom: 16, left: 24, right: 24 })
        .width('100%')

      TextInput({ text: this.textValue, placeholder: '' })
        .width('90%')
        .height(56)
        .margin({ bottom: 24 })
        .borderRadius(8)
        .backgroundColor(Color.Transparent)
        .border({ width: 1, color: $r('sys.color.ohos_id_color_text_tertiary'), radius: 8 })
        .onChange((value: string) => {
          this.textValue = value;
        })

      Row() {
        Button("取消", { type: ButtonType.Normal })
          .onClick(() => { this.controller.close() })
          .backgroundColor(Color.Transparent)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .layoutWeight(1)

        Button("确定", { type: ButtonType.Normal })
          .onClick(() => {
            this.onConfirm(this.textValue);
            this.controller.close();
          })
          .backgroundColor(Color.Transparent)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .layoutWeight(1)
      }
      .width('100%')
      .height(52)
      .margin({ bottom: 8 })
    }
    .backgroundColor($r('sys.color.ohos_id_color_dialog_bg'))
    .borderRadius(28)
    .width('80%')
  }
}
