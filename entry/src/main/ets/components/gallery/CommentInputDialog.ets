// entry/src/main/ets/components/gallery/CommentInputDialog.ets
import photoAccessHelper from '@ohos.file.photoAccessHelper';
import promptAction from '@ohos.promptAction';
import common from '@ohos.app.ability.common';
import { ImageUploadItem } from '../../services/gallery/GalleryModels';
import { ImagePickerGrid } from './ImagePickerGrid';
import { galleryService } from '../../services/gallery/GalleryService';
import { uiShowToast } from '../../utils/uiContextBridge';

@CustomDialog
export struct CommentInputDialog {
  controller: CustomDialogController;

  title: string = '发表评论';
  onSend: (text: string, isAnonymous: boolean, imageMids: string[]) => void = () => {};

  @State text: string = '';
  @State isAnonymous: boolean = false;
  @State images: ImageUploadItem[] = [];

  private context = this.getUIContext().getHostContext() as common.UIAbilityContext;

  // ⚠️ 这里的逻辑是为了复用 ImagePickerGrid 的功能
  // 由于无法直接调用子组件方法，我们将 pickImages 逻辑在这里重新实现一遍
  async triggerPickImages(): Promise<void> {
    try {
      const maxCount = 9;
      const photoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
      photoSelectOptions.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      photoSelectOptions.maxSelectNumber = maxCount - this.images.length;

      if (photoSelectOptions.maxSelectNumber <= 0) {
        uiShowToast(this.getUIContext(), { message: `最多只能上传${maxCount}张图片` });
        return;
      }

      const photoViewPicker = new photoAccessHelper.PhotoViewPicker();
      const photoSelectResult = await photoViewPicker.select(photoSelectOptions);

      if (photoSelectResult && photoSelectResult.photoUris.length > 0) {
        const newItems: ImageUploadItem[] = photoSelectResult.photoUris.map((uri: string): ImageUploadItem => {
          return {
            uri: uri,
            status: 'uploading',
            mid: undefined
          } as ImageUploadItem;
        });

        // 更新 UI
        newItems.forEach((item) => this.images.push(item));

        // 异步上传
        newItems.forEach(async (item) => {
          const mid = await galleryService.uploadImage(this.context, item.uri);

          const index = this.images.indexOf(item);
          if (index !== -1) {
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

  build() {
    Column() {
      // 1. 标题栏
      Row() {
        Text(this.title).fontSize(16).fontWeight(FontWeight.Medium)
        Blank()
        // ✅ 修复：使用刚才新建的 ic_public_cancel
        Image($r('app.media.ic_public_cancel'))
          .width(20).height(20)
          .onClick(() => this.controller.close())
      }
      .width('100%').padding({ bottom: 12 })

      // 2. 输入框
      TextArea({ text: this.text, placeholder: '友善的评论是交流的起点...' })
        .width('100%').height(100).backgroundColor('#F3F4F6').borderRadius(8)
        .onChange((value: string) => { this.text = value; })

      // 3. 图片展示区域 (复用组件)
      if (this.images.length > 0) {
        ImagePickerGrid({ images: $images })
          .margin({ top: 8 })
      }

      // 4. 底部工具栏
      Row() {
        // 匿名开关
        Row() {
          Checkbox({ name: 'anonymous', group: 'grp' })
            .select(this.isAnonymous)
            .selectedColor('#2563EB')
            .onChange((val: boolean) => { this.isAnonymous = val })
            .width(18).height(18)
          Text('匿名').fontSize(14).fontColor('#6B7280').margin({ left: 4 })
        }

        // 图片按钮
        Image($r('app.media.ic_image'))
          .width(24).height(24)
          .fillColor('#6B7280')
          .margin({ left: 16 })
          .onClick(() => {
            this.triggerPickImages()
          })

        Blank()

        Button('发送')
          .type(ButtonType.Capsule)
          .backgroundColor(this.text.trim().length === 0 ? '#E5E7EB' : '#2563EB')
          .fontColor(this.text.trim().length === 0 ? '#9CA3AF' : Color.White)
          .enabled(this.text.trim().length > 0)
          .height(32)
          .onClick(() => {
            // 提取上传成功的 mids
            const mids = this.images
              .filter(i => i.status === 'success' && i.mid !== undefined)
              .map((i): string => i.mid as string);

            this.onSend(this.text, this.isAnonymous, mids);
            this.controller.close();
          })
      }
      .width('100%').margin({ top: 12 }).alignItems(VerticalAlign.Center)
    }
    .padding(16).width('100%').backgroundColor(Color.White).borderRadius(16)
  }
}
