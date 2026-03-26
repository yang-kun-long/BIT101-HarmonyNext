import { router, promptAction } from '@kit.ArkUI';
import { uiBack, uiShowToast } from '../../utils/uiContextBridge';
// 注意：这里改为上一级目录，因为 PageEnum 在 pages/ 下
import { PageShowOnNav, getPageName } from '../PageEnum';

@Entry
@Component
struct PagesSettingPage {
  // --- 从 AppStorage 获取当前配置 (作为初始数据) ---
  @StorageLink('pages_order') allPages: PageShowOnNav[] = [
    PageShowOnNav.Home,
    PageShowOnNav.Schedule,
    PageShowOnNav.DDL,
    PageShowOnNav.Forum,
    PageShowOnNav.Mine
  ];
  @StorageLink('home_page') homePage: PageShowOnNav = PageShowOnNav.Home;
  @StorageLink('pages_hidden') hiddenPages: PageShowOnNav[] = [];

  // --- 编辑状态 (用户操作时修改这些临时变量，点击保存才写入 AppStorage) ---
  @State editingPages: PageShowOnNav[] = [];
  @State editingHomePage: PageShowOnNav = PageShowOnNav.Home;
  @State editingHiddenPages: PageShowOnNav[] = [];

  aboutToAppear() {
    // 初始化编辑状态
    this.resetState();
  }

  // 重置编辑状态为当前生效的配置
  resetState() {
    this.editingPages = [...this.allPages];
    this.editingHomePage = this.homePage;
    this.editingHiddenPages = [...this.hiddenPages];
  }

  // 恢复默认设置 (硬编码的默认值)
  restoreDefault() {
    this.editingPages = [
      PageShowOnNav.Home,
      PageShowOnNav.Schedule,
      PageShowOnNav.DDL,
      PageShowOnNav.Map,
      PageShowOnNav.Forum,
      PageShowOnNav.Post,
      PageShowOnNav.Mine
    ];
    this.editingHomePage = PageShowOnNav.Home;
    this.editingHiddenPages = [];
    uiShowToast(this.getUIContext(), { message: "已恢复默认配置，请点击保存生效" });
  }

  // 保存逻辑
  saveSettings() {
    // 1. 校验逻辑：主页不能隐藏
    if (this.editingHiddenPages.includes(this.editingHomePage)) {
      uiShowToast(this.getUIContext(), { message: "主页不能被隐藏" });
      return;
    }
    // 2. 校验逻辑：我的页面不能隐藏
    if (this.editingHiddenPages.includes(PageShowOnNav.Mine)) {
      uiShowToast(this.getUIContext(), { message: "“我的”页面不能被隐藏" });
      return;
    }

    // 3. 写入 AppStorage (这将触发 Index.ets 的自动更新)
    AppStorage.setOrCreate('pages_order', this.editingPages);
    AppStorage.setOrCreate('home_page', this.editingHomePage);
    AppStorage.setOrCreate('pages_hidden', this.editingHiddenPages);

    // 同时持久化保存
    PersistentStorage.persistProp('pages_order', this.editingPages);
    PersistentStorage.persistProp('home_page', this.editingHomePage);
    PersistentStorage.persistProp('pages_hidden', this.editingHiddenPages);

    uiShowToast(this.getUIContext(), { message: "保存成功" });
    uiBack(this.getUIContext());
  }

  build() {
    Column() {
      // 1. 顶部导航栏
      Row() {
        Image($r('app.media.ic_chevron_left'))
          .width(24)
          .height(24)
          .fillColor($r('sys.color.ohos_id_color_text_primary'))
          .onClick(() => { uiBack(this.getUIContext()); })

        Text("页面设置")
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .margin({ left: 16 })
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
      }
      .width('100%')
      .height(56)
      .padding({ left: 16 })
      .backgroundColor($r('sys.color.ohos_id_color_background'))

      // 2. 说明卡片
      Column() {
        Text("页面编辑")
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .margin({ bottom: 8 })

        Text("长按条目可拖动排序。\n右侧复选框控制是否在底部导航栏显示。\n右侧单选框设置启动时的主页。\n\nTips: “我的”页面不能隐藏。")
          .fontSize(14)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
          .lineHeight(20)
      }
      .width('94%')
      .padding(16)
      .margin({ top: 8, bottom: 8 })
      .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
      .borderRadius(12)

      // 3. 拖拽列表
      List({ space: 12 }) {
        ForEach(this.editingPages, (page: PageShowOnNav) => {
          ListItem() {
            this.PageItemRow(page)
          }
        }, (page: PageShowOnNav) => page.toString()) // Key 使用枚举值
      }
      .width('94%')
      .layoutWeight(1) // 占据剩余空间
      .onItemMove((from: number, to: number) => {
        // ArkUI List 原生拖拽逻辑
        const item = this.editingPages.splice(from, 1)[0];
        this.editingPages.splice(to, 0, item);
        return true;
      })
      .margin({ top: 8 })

      // 4. 底部按钮区
      Row() {
        Button("重置")
          .type(ButtonType.Normal)
          .backgroundColor($r('sys.color.ohos_id_color_button_normal')) // 灰色/次要按钮
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .borderRadius(20)
          .height(40)
          .width(80)
          .onClick(() => { this.restoreDefault() })

        Blank().width(12)

        Button("保存")
          .type(ButtonType.Normal)
          .backgroundColor($r('sys.color.ohos_id_color_primary')) // 主色按钮
          .fontColor(Color.White)
          .borderRadius(20)
          .height(40)
          .width(80)
          .onClick(() => { this.saveSettings() })
      }
      .padding({ top: 16, bottom: 32, right: 16 })
      .width('100%')
      .justifyContent(FlexAlign.End)
    }
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  // --- 自定义列表项组件 ---
  @Builder
  PageItemRow(page: PageShowOnNav) {
    Row() {
      // 左侧：拖拽手柄图标
      Image($r('app.media.ic_sort')) // 确保你有 ic_sort 图标
        .width(24)
        .height(24)
        .fillColor($r('sys.color.ohos_id_color_text_tertiary'))
        .margin({ right: 12 })

      // 中间：页面名称
      Text(getPageName(page))
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .layoutWeight(1)

      // 右侧：隐藏复选框 (Checkbox)
      // 逻辑：选中 = 显示 (不在隐藏列表中)
      Checkbox({ name: 'visible', group: 'visibleGroup' })
        .select(!this.editingHiddenPages.includes(page))
        .onChange((isVisible: boolean) => {
          if (isVisible) {
            // 变为显示 -> 从隐藏列表中移除
            this.editingHiddenPages = this.editingHiddenPages.filter(p => p !== page);
          } else {
            // 变为隐藏 -> 加入隐藏列表
            this.editingHiddenPages.push(page);
          }
        })
        .width(20)
        .height(20)
        .margin({ right: 16 })

      // 右侧：主页单选框 (Radio)
      Radio({ value: page.toString(), group: 'homePageGroup' })
        .checked(this.editingHomePage === page)
        .onChange((isChecked: boolean) => {
          if (isChecked) {
            this.editingHomePage = page;
          }
        })
        .width(20)
        .height(20)
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
    .borderRadius(8)
    .shadow({ radius: 2, color: '#1A000000', offsetY: 1 }) // 轻微阴影，增加卡片感
  }
}
