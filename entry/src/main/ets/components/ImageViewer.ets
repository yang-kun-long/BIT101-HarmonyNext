import promptAction from '@ohos.promptAction';
import { GalleryImage } from '../services/gallery/GalleryModels';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { rcp } from '@kit.RemoteCommunicationKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { uiShowToast } from '../utils/uiContextBridge';

@Component
export struct ImageViewer {
  @Prop images: GalleryImage[] = [];
  initialIndex: number = 0;

  @State currentIndex: number = 0;

  // ✅ 1. 创建 Swiper 控制器
  private scroller: SwiperController = new SwiperController();

  onClose: () => void = () => {};

  aboutToAppear() {
    this.currentIndex = this.initialIndex;
  }

  async saveImageToGallery(url: string) {
    try {
      uiShowToast(this.getUIContext(), { message: '正在下载...' });

      const session = rcp.createSession();
      const req = new rcp.Request(url);
      const response = await session.fetch(req);

      if (response.statusCode !== 200 || !response.body) {
        throw new Error('网络请求失败');
      }
      const imageBuffer = response.body;

      const context = this.getUIContext().getHostContext();
      const phAccessHelper = photoAccessHelper.getPhotoAccessHelper(context);

      const photoType = photoAccessHelper.PhotoType.IMAGE;
      const extension = 'jpg';
      const assetUri = await phAccessHelper.createAsset(photoType, extension);

      const file = await fs.open(assetUri, fs.OpenMode.READ_WRITE);
      await fs.write(file.fd, imageBuffer);
      await fs.close(file.fd);

      uiShowToast(this.getUIContext(), { message: '已保存到系统相册', duration: 2000 });
      session.close();

    } catch (err) {
      const error = err as BusinessError;
      console.error(`[ImageViewer] 保存失败: ${error.message}, code: ${error.code}`);
      uiShowToast(this.getUIContext(), { message: '保存失败: ' + error.message });
    }
  }

  build() {
    Stack() {
      // 1. 背景
      Rect()
        .width('100%').height('100%').fill(Color.Black)
        .onClick(() => this.onClose())

      // 2. 轮播图
      // ✅ 2. 绑定控制器
      Swiper(this.scroller) {
        ForEach(this.images, (img: GalleryImage) => {
          Stack({ alignContent: Alignment.Center }) {
            LoadingProgress().width(40).height(40).color(Color.White).zIndex(0)

            Image(img.url)
              .width('100%')
              .objectFit(ImageFit.Contain)
              .onClick(() => this.onClose())
              .zIndex(1)
          }
        })
      }
      .index(this.currentIndex) // 初始索引
      .indicator(
        Indicator.digit().fontColor(Color.White).selectedFontColor(Color.White).bottom(20)
      )
      .loop(false)
      .effectMode(EdgeEffect.Spring)
      .cachedCount(2)
      // ✅ 3. 监听滑动，手动同步 currentIndex
      // 这样无论是手滑还是点按钮，index 都是准的
      .onChange((index: number) => {
        this.currentIndex = index;
      })

      // 3. 左右按钮 (使用控制器驱动)
      if (this.images.length > 1) {
        // 左按钮
        if (this.currentIndex > 0) {
          Row() {
            Image($r('app.media.ic_chevron_left')).width(36).height(36).fillColor(Color.White)
          }
          .padding(16)
          .position({ x: 0, y: '50%' }).translate({ y: '-50%' })
          .zIndex(10) // 确保在最上层
          .onClick(() => {
            // ✅ 4. 使用控制器切换上一页
            this.scroller.showPrevious();
          })
        }

        // 右按钮
        if (this.currentIndex < this.images.length - 1) {
          Row() {
            Image($r('app.media.ic_chevron_right')).width(36).height(36).fillColor(Color.White)
          }
          .padding(16)
          .position({ x: '100%', y: '50%' }).translate({ x: '-100%', y: '-50%' })
          .zIndex(10) // 确保在最上层
          .onClick(() => {
            // ✅ 4. 使用控制器切换下一页
            this.scroller.showNext();
          })
        }
      }

      // 4. 下载按钮 (包裹 Row 以支持布局属性)
      Row() {
        SaveButton({
          icon: SaveIconStyle.FULL_FILLED,
          text: SaveDescription.DOWNLOAD,
          buttonType: ButtonType.Normal
        })
          .fontColor(Color.White)
          .backgroundColor(Color.Transparent)
          .padding(12)
          .onClick(async (event: ClickEvent, result: SaveButtonOnClickResult) => {
            if (result === SaveButtonOnClickResult.SUCCESS) {
              const currentUrl = this.images[this.currentIndex]?.url;
              if (currentUrl) {
                await this.saveImageToGallery(currentUrl);
              }
            } else {
              uiShowToast(this.getUIContext(), { message: '权限校验失败' });
            }
          })
      }
      .position({ x: '100%', y: '100%' })
      .translate({ x: '-100%', y: '-100%' })
      .margin({ bottom: 16, right: 16 })
      .zIndex(10) // 确保在最上层

    }
    .width('100%').height('100%').backgroundColor(Color.Black)
  }
}
