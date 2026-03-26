// entry/src/main/ets/components/gallery/ImagePickerGrid.ets
import photoAccessHelper from '@ohos.file.photoAccessHelper';
import promptAction from '@ohos.promptAction';
import common from '@ohos.app.ability.common';
import { ImageUploadItem } from '../../services/gallery/GalleryModels';
import { galleryService } from '../../services/gallery/GalleryService';
import { uiShowToast } from '../../utils/uiContextBridge';

@Component
export struct ImagePickerGrid {
  @Link images: ImageUploadItem[];
  maxCount: number = 9;

  private context = this.getUIContext().getHostContext() as common.UIAbilityContext;

  async pickImages(): Promise<void> {
    try {
      const photoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
      photoSelectOptions.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      photoSelectOptions.maxSelectNumber = this.maxCount - this.images.length;

      if (photoSelectOptions.maxSelectNumber <= 0) {
        uiShowToast(this.getUIContext(), { message: `最多只能上传${this.maxCount}张图片` });
        return;
      }

      const photoViewPicker = new photoAccessHelper.PhotoViewPicker();
      const photoSelectResult = await photoViewPicker.select(photoSelectOptions);

      if (photoSelectResult && photoSelectResult.photoUris.length > 0) {
        // ✅ 修复：显式声明 map 的返回类型，并使用 'as ImageUploadItem' 断言
        const newItems: ImageUploadItem[] = photoSelectResult.photoUris.map((uri: string): ImageUploadItem => {
          return {
            uri: uri,
            status: 'uploading',
            mid: undefined
          } as ImageUploadItem;
        });

        // 这一步因为 images 是 @Link，push 可能会有代理问题，但在 ArkTS 中通常支持
        // 如果报错，可以写成: this.images = this.images.concat(newItems);
        // 这里暂时保持 push，因为通常 Link 数组支持 push 触发更新
        newItems.forEach((item) => {
          this.images.push(item);
        });

        // 异步上传
        newItems.forEach(async (item) => {
          const mid = await galleryService.uploadImage(this.context, item.uri);

          // 查找当前最新的 index (因为数组可能变动)
          const index = this.images.indexOf(item);
          if (index !== -1) {
            // 需要构建新对象来触发更新，直接修改属性有时监听不到
            if (mid) {
              this.images[index] = {
                uri: item.uri,
                status: 'success',
                mid: mid
              } as ImageUploadItem;
            } else {
              this.images[index] = {
                uri: item.uri,
                status: 'fail',
                mid: undefined
              } as ImageUploadItem;
            }
          }
        });
      }
    } catch (err) {
      console.error('PhotoViewPicker failed', err);
    }
  }

  deleteImage(index: number): void {
    this.images.splice(index, 1);
  }

  build() {
    if (this.images.length > 0) {
      List({ space: 8 }) {
        ForEach(this.images, (item: ImageUploadItem, index: number) => {
          ListItem() {
            Stack({ alignContent: Alignment.TopEnd }) {
              Image(item.uri)
                .width(80).height(80)
                .borderRadius(8)
                .objectFit(ImageFit.Cover)
                .opacity(item.status === 'uploading' ? 0.5 : 1)

              if (item.status === 'uploading') {
                LoadingProgress()
                  .width(24).height(24).color(Color.White)
                  .alignRules({
                    center: { anchor: '__container__', align: VerticalAlign.Center },
                    middle: { anchor: '__container__', align: HorizontalAlign.Center }
                  })
              } else if (item.status === 'fail') {
                // ✅ 修复：这里使用你已有的红色叉号
                Image($r('app.media.ic_cancel_red'))
                  .width(24).height(24)
              }

              // 删除按钮
              // ✅ 修复：这里也使用你已有的红色叉号
              Image($r('app.media.ic_cancel_red'))
                .width(20).height(20)
                .margin({ top: 4, right: 4 })
                .onClick(() => this.deleteImage(index))
            }
          }
        })
      }
      .listDirection(Axis.Horizontal)
      .height(90)
      .width('100%')
      .scrollBar(BarState.Off)
    }
  }
}
