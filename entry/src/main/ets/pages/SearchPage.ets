// entry/src/main/ets/pages/SearchPage.ets
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { PostersTabPage } from '../components/gallery/PostersTabPage'; // ✅ 复用列表组件
import { PosterListState } from '../services/gallery/PosterListState'; // ✅ 引入状态管理
import { PostersMode } from '../services/gallery/GalleryService';      // ✅ 引入模式枚举

// 定义下拉菜单的数据模型
class SearchOrderOption {
  value: string = '';
  label: string = '';
}

@Entry
@Component
struct SearchPage {
  // --- 1. 核心数据状态 ---
  // 初始化为 Search 模式
  @State searchState: PosterListState = new PosterListState(PostersMode.Search);

  // --- 2. UI 交互状态 ---
  @State searchKeyword: string = '';
  @State currentOrder: string = 'new'; // 默认按最新排序

  // 排序选项配置
  @State orderOptions: SearchOrderOption[] = [
    { value: 'new', label: '最新' },
    { value: 'like', label: '相似' },
    { value: 'comment', label: '热评' }
  ];

  // --- 3. 业务逻辑 ---

  // 执行搜索
  private doSearch() {
    if (!this.searchKeyword.trim()) {
      promptAction.showToast({ message: '请输入搜索内容', duration: 1500 });
      return;
    }

    // 调用 ViewModel 发起请求
    // 注意：uid 暂时传 -1 (全站搜索)，后续对接用户系统时可从 UserStore 获取
    this.searchState.doSearch(this.searchKeyword, this.currentOrder, 0);
  }

  // 跳转详情页 (复用 PostPage 的逻辑)
  private openPosterDetail(id: number): void {
    router.pushUrl({
      url: 'pages/PosterDetailPage',
      params: { id }
    });
  }

  // 构建排序菜单
  @Builder
  MyMenu() {
    Menu() {
      ForEach(this.orderOptions, (option: SearchOrderOption) => {
        MenuItem({
          content: option.label,
          // 选中状态打钩
          startIcon: this.currentOrder === option.value ? $r('sys.symbol.checkmark') : undefined
        })
          .onClick(() => {
            this.currentOrder = option.value;
            // 切换排序后立即重新搜索
            this.doSearch();
          })
      })
    }
  }

  build() {
    Column() {
      // ============================================================
      // 1. 顶部搜索栏
      // ============================================================
      Row() {
        // 返回按钮
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(24)
            .fontColor([$r('sys.color.icon_primary')])
        }
        .backgroundColor(Color.Transparent)
        .width(40)
        .height(40)
        .margin({ right: 8 })
        .onClick(() => {
          router.back();
        })

        // 搜索框容器
        Row() {
          // 输入框
          TextInput({
            placeholder: '搜索帖子、用户...',
            text: this.searchKeyword
          })
            .layoutWeight(1)
            .height('100%')
            .backgroundColor(Color.Transparent)
            .enterKeyType(EnterKeyType.Search) // 键盘显示搜索键
            .placeholderColor($r('sys.color.font_secondary'))
            .onChange((value: string) => {
              this.searchKeyword = value;
            })
            .onSubmit(() => {
              // 键盘回车触发搜索
              this.doSearch();
            })

          // 排序按钮
          Button({ type: ButtonType.Circle, stateEffect: true }) {
            // 使用之前添加的 SVG 图标
            Image($r('app.media.ic_sort'))
              .width(22)
              .height(22)
              .fillColor($r('sys.color.icon_secondary'))
          }
          .width(36)
          .height(36)
          .backgroundColor(Color.Transparent)
          .bindMenu(this.MyMenu) // 绑定下拉菜单
        }
        .layoutWeight(1)
        .height(42)
        .backgroundColor($r('sys.color.ohos_id_color_list_card_bg'))
        .borderRadius(21)
        .border({ width: 1, color: $r('sys.color.ohos_id_color_list_separator') })
        .padding({ left: 12, right: 4 })

      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      .backgroundColor($r('sys.color.ohos_id_color_background'))
      .zIndex(1)

      // ============================================================
      // 2. 内容区域
      // ============================================================
      Column() {
        // 如果列表为空且未在加载，显示提示页 (初始状态)
        if (this.searchState.items.length === 0 && !this.searchState.isLoading && !this.searchState.isRefreshing) {
          Column() {
            SymbolGlyph($r('sys.symbol.magnifyingglass'))
              .fontSize(48)
              .fontColor([$r('sys.color.icon_tertiary')])
              .margin({ bottom: 12 })

            Text('输入关键词开始搜索')
              .fontSize(16)
              .fontColor($r('sys.color.font_secondary'))
          }
          .justifyContent(FlexAlign.Center)
          .height('100%')
        } else {
          // ✅ 显示真实的帖子列表
          PostersTabPage({
            state: this.searchState,
            onOpenPoster: (id: number) => this.openPosterDetail(id),
            // 搜索页通常不需要显示“发帖”入口，或者跳转去发帖
            onOpenPostOrEdit: () => {
              router.pushUrl({ url: 'pages/PostEditorPage' });
            }
          })
        }
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
    }
    .width('100%')
    .height('100%')
  }
}