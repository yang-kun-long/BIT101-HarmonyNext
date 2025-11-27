// entry/src/main/ets/pages/PostEditorPage.ets
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import picker from '@ohos.file.picker';
import { galleryService } from '../services/gallery/GalleryService';
import { PosterClaim, PosterPostRequest } from '../services/gallery/GalleryModels';

// ===============================================================
// 1. 数据模型
// ===============================================================

interface ImageUploadItem {
  uri: string;
  status: 'pending' | 'uploading' | 'success' | 'fail';
  mid?: string;
}

// ===============================================================
// 2. 自定义弹窗
// ===============================================================
@CustomDialog
struct TagInputDialog {
  controller: CustomDialogController;
  initialText: string = '';
  // 显式声明箭头函数的返回值类型
  onConfirm: (tags: string[]) => void = (tags: string[]) => {};
  onDelete: () => void = () => {};
  @State textValue: string = '';

  aboutToAppear() {
    this.textValue = this.initialText;
  }

  build() {
    Column() {
      Text(this.initialText ? '编辑标签' : '添加标签')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 24, bottom: 16 })

      TextInput({ placeholder: '输入标签 (空格可分隔多个)', text: this.textValue })
        .height(48)
        .margin({ left: 16, right: 16, bottom: 8 })
        .backgroundColor('#F5F5F5')
        .borderRadius(8)
        .onChange((value: string) => {
          this.textValue = value;
        })
        .defaultFocus(true)
        .onSubmit(() => this.handleConfirm())

      Text(`${this.textValue.length}/11`)
        .fontSize(12)
        .fontColor(this.textValue.length > 11 ? Color.Red : Color.Gray)
        .alignSelf(ItemAlign.End)
        .margin({ right: 16, bottom: 20 })

      Row() {
        if (this.initialText) {
          Button('删除')
            .onClick((): void => {
              this.onDelete();
              this.controller.close();
            })
            .backgroundColor(Color.Transparent)
            .fontColor(Color.Red)
            .layoutWeight(1)
        } else {
          Button('取消')
            .onClick((): void => this.controller.close())
            .backgroundColor(Color.Transparent)
            .fontColor($r('sys.color.font_secondary'))
            .layoutWeight(1)
        }

        Button('确定')
          .onClick((): void => this.handleConfirm())
          .backgroundColor(Color.Transparent)
          .fontColor($r('sys.color.brand'))
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ bottom: 16 })
    }
    .backgroundColor(Color.White)
    .borderRadius(24)
    .width('80%')
  }

  handleConfirm() {
    const rawText = this.textValue.trim();
    if (rawText.length === 0) {
      promptAction.showToast({ message: '标签不能为空' });
      return;
    }
    const splitTags = rawText.split(/\s+/)
      .filter((t: string) => t.length > 0)
      .map((t: string) => t.substring(0, 11));

    this.onConfirm(splitTags);
    this.controller.close();
  }
}

// ===============================================================
// 新增：创作者声明选择弹窗 (复刻 Android AlertDialog + RadioButton)
// ===============================================================
@CustomDialog
struct SelectClaimDialog {
  controller: CustomDialogController;
  claims: PosterClaim[] = [];
  defaultClaimId: number = 0;
  onConfirm: (claim: PosterClaim) => void = () => {};

  // 内部维护选中的索引
  @State selectedId: number = 0;

  aboutToAppear() {
    this.selectedId = this.defaultClaimId;
  }

  build() {
    Column() {
      // 1. 标题
      Text('创作者声明')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .padding({ top: 24, bottom: 16, left: 24, right: 24 })
        .width('100%')

      // 2. 滚动列表 (Radio + Text)
      List() {
        ForEach(this.claims, (item: PosterClaim) => {
          ListItem() {
            Row() {
              // 单选框
              Radio({ value: item.id.toString(), group: 'claimGroup' })
                .checked(item.id === this.selectedId)
                .height(24)
                .width(24)
                .onChange((isChecked: boolean) => {
                  if (isChecked) this.selectedId = item.id;
                })
                // 解决点击穿透问题，让 Radio 不拦截行点击
                .hitTestBehavior(HitTestMode.None)

              // 文本
              Text(item.text)
                .fontSize(16)
                .fontColor('#1d1b20')
                .layoutWeight(1)
                .padding({ left: 16 })
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .width('100%')
            .padding({ top: 12, bottom: 12, left: 24, right: 24 })
            .onClick(() => {
              // 点击整行也能选中
              this.selectedId = item.id;
            })
          }
        })
      }
      .width('100%')
      .constraintSize({ maxHeight: '50%' }) // 限制最大高度，内容多了可以滚动

      // 3. 底部按钮栏
      Row() {
        // 取消按钮 (Android 通常在左边或者根据系统习惯，鸿蒙习惯右边确认)
        Button('取消')
          .onClick(() => this.controller.close())
          .backgroundColor(Color.Transparent)
          .fontColor($r('sys.color.brand')) // 或次要颜色
          .fontSize(16)
          .layoutWeight(1)

        // 确定按钮
        Button('确定')
          .onClick(() => {
            const selected = this.claims.find(c => c.id === this.selectedId);
            if (selected) {
              this.onConfirm(selected);
            }
            this.controller.close();
          })
          .backgroundColor(Color.Transparent)
          .fontColor($r('sys.color.brand'))
          .fontSize(16)
          .layoutWeight(1)
      }
      .padding({ top: 16, bottom: 16, left: 16, right: 16 })
      .width('100%')
    }
    .backgroundColor(Color.White)
    .borderRadius(28) // Android Material 3 默认圆角较大
    .width('90%') // 稍微宽一点
  }
}
// ===============================================================
// 3. 主页面
// ===============================================================
@Entry
@Component
struct PostEditorPage {
  @State posterId: number = 0;
  @State isLoading: boolean = false;

  @State title: string = '';
  @State text: string = '';
  @State tags: string[] = [];
  @State isAnonymous: boolean = false;
  @State isPublic: boolean = true;
  @State selectedClaim: PosterClaim | null = null;

  @State localImages: ImageUploadItem[] = [];
  @State claimsList: PosterClaim[] = [];

  @State editingTagIndex: number = -1;

  tagDialogController: CustomDialogController | null = null;
  claimDialogController: CustomDialogController | null = null;

  openTagDialog(index: number) {
    this.editingTagIndex = index;
    const initialText = index >= 0 && index < this.tags.length ? this.tags[index] : '';

    this.tagDialogController = new CustomDialogController({
      builder: TagInputDialog({
        initialText: initialText,
        onConfirm: (newTags: string[]) => {
          this.handleTagResult(newTags);
        },
        onDelete: () => {
          if (index >= 0) {
            this.tags.splice(index, 1);
          }
        }
      }),
      alignment: DialogAlignment.Center,
      autoCancel: true,
      customStyle: true
    });
    this.tagDialogController.open();
  }

  async aboutToAppear() {
    const params = router.getParams() as Record<string, Object>;
    if (params && params['id']) {
      this.posterId = params['id'] as number;
    }

    this.claimsList = await galleryService.getClaims();

    if (this.posterId !== 0) {
      await this.loadEditData(this.posterId);
    } else {
      if (this.claimsList.length > 0) {
        this.selectedClaim = this.claimsList[0];
      }
    }
  }

  async loadEditData(id: number) {
    this.isLoading = true;
    const detail = await galleryService.getPosterById(id);
    if (detail) {
      this.title = detail.title || '';
      this.text = detail.text;
      this.tags = detail.tags;
      this.isAnonymous = detail.anonymous;
      this.isPublic = detail.public;
      if (detail.claim) {
        this.selectedClaim = this.claimsList.find(c => c.id === detail.claim!.id) || detail.claim;
      }
    }
    this.isLoading = false;
  }

  handleTagResult(newTags: string[]) {
    if (this.editingTagIndex === -1) {
      const uniqueNew = newTags.filter((t: string) => !this.tags.includes(t));
      this.tags.push(...uniqueNew);
      if(uniqueNew.length < newTags.length) {
        promptAction.showToast({ message: '已过滤重复标签' });
      }
    } else {
      this.tags.splice(this.editingTagIndex, 1, ...newTags);
      const uniqueSet = new Set(this.tags);
      if (uniqueSet.size !== this.tags.length) {
        this.tags = Array.from(uniqueSet);
      }
    }
  }

  async pickImages() {
    try {
      const photoSelectOptions = new picker.PhotoSelectOptions();
      photoSelectOptions.MIMEType = picker.PhotoViewMIMETypes.IMAGE_TYPE;
      photoSelectOptions.maxSelectNumber = 9 - this.localImages.length;

      if (photoSelectOptions.maxSelectNumber <= 0) {
        promptAction.showToast({ message: '最多只能上传9张图片' });
        return;
      }

      const photoViewPicker = new picker.PhotoViewPicker();
      const photoSelectResult = await photoViewPicker.select(photoSelectOptions);

      if (photoSelectResult && photoSelectResult.photoUris.length > 0) {
        const newItems: ImageUploadItem[] = photoSelectResult.photoUris.map((uri: string): ImageUploadItem => ({
          uri: uri,
          status: 'success',
          mid: 'mock_mid_' + Math.random()
        }));
        this.localImages.push(...newItems);
      }
    } catch (err) {
      console.error('PhotoViewPicker failed', err);
    }
  }

  deleteImage(index: number) {
    // 修复点：Strict Mode 下，必须构建符合 AlertDialogParam 类型的对象
    // 不能直接传字面量，需要类型断言或构建正确结构
    AlertDialog.show({
      title: '删除图片',
      message: '确定要移除这张图片吗？',
      autoCancel: true,
      alignment: DialogAlignment.Bottom,
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '删除',
        fontColor: Color.Red,
        action: () => {
          this.localImages.splice(index, 1);
        }
      }
    })
  }

  showClaimSelect() {
    if (this.claimsList.length === 0) return;

    // 每次打开都重新实例化，以确保传入最新的 selectedClaim 状态
    this.claimDialogController = new CustomDialogController({
      builder: SelectClaimDialog({
        claims: this.claimsList,
        defaultClaimId: this.selectedClaim ? this.selectedClaim.id : (this.claimsList[0]?.id || 0),
        onConfirm: (claim: PosterClaim) => {
          this.selectedClaim = claim;
        }
      }),
      alignment: DialogAlignment.Center, // 居中显示，像 Android AlertDialog
      autoCancel: true,
      customStyle: true // 使用自定义样式去除默认背景 padding
    });

    this.claimDialogController.open();
  }

  async handleSubmit() {
    if (!this.title.trim()) {
      promptAction.showToast({ message: '标题不能为空哟' });
      return;
    }
    if (!this.text.trim()) {
      promptAction.showToast({ message: '内容不能为空哟' });
      return;
    }
    if (this.tags.length < 2) {
      promptAction.showToast({ message: '请至少添加2个标签哟' });
      return;
    }

    const imageMids = this.localImages
      .filter((img) => img.status === 'success' && img.mid)
      .map((img) => img.mid!);

    const req: PosterPostRequest = {
      title: this.title,
      text: this.text,
      tags: this.tags,
      anonymous: this.isAnonymous,
      public: this.isPublic,
      claim_id: this.selectedClaim ? this.selectedClaim.id : 0,
      image_mids: imageMids,
      plugins: "[]"
    };

    this.isLoading = true;
    let success = false;
    if (this.posterId === 0) success = await galleryService.postPoster(req);
    else success = await galleryService.updatePoster(this.posterId, req);
    this.isLoading = false;

    if (success) {
      promptAction.showToast({ message: this.posterId === 0 ? '发布成功' : '修改成功' });
      router.back();
    } else {
      promptAction.showToast({ message: '失败，请重试' });
    }
  }

  build() {
    Column() {
      this.TopBarBuilder()

      Scroll() {
        Column() {
          TextInput({ placeholder: '在这里输入标题', text: this.title })
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .placeholderColor('#99000000')
            .backgroundColor(Color.Transparent)
            .padding({ left: 12, right: 12, top: 16, bottom: 8 })
            .width('100%')
            .onChange((val) => this.title = val)

          if (this.selectedClaim && this.selectedClaim.id !== 0) {
            Text(`创作者声明：${this.selectedClaim.text}`)
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.Red)
              .padding({ left: 16, right: 16, bottom: 8 })
              .width('100%')
          }

          TextArea({ placeholder: '在这里输入内容', text: this.text })
            .fontSize(16)
            .backgroundColor(Color.Transparent)
            .padding({ left: 12, right: 12 })
            .width('100%')
            .constraintSize({ minHeight: 300 })
            .align(Alignment.TopStart)
            .onChange((val) => this.text = val)
        }
      }
      .layoutWeight(1)
      .align(Alignment.TopStart)

      Column() {
        Divider().color('#1A000000')

        // 图片预览区域
        if (this.localImages.length > 0) {
          List({ space: 8 }) {
            ForEach(this.localImages, (item: ImageUploadItem, index: number) => {
              ListItem() {
                Stack({ alignContent: Alignment.TopEnd }) {
                  Image(item.uri)
                    .width(80).height(80)
                    .borderRadius(8)
                    .objectFit(ImageFit.Cover)

                  // 修复点：使用本地资源 ic_cancel_red.svg
                  Image($r('app.media.ic_cancel_red'))
                    .width(20).height(20)
                    .fillColor(Color.Red)
                    .offset({ x: 5, y: -5 })
                    .onClick((): void => this.deleteImage(index))
                }
                .padding({ top: 5, right: 5 })
              }
            })
          }
          .listDirection(Axis.Horizontal)
          .height(90)
          .width('100%')
          .padding({ left: 12, right: 12, top: 8 })
        }

        // 标签区域
        Row() {
          List({ space: 8 }) {
            ForEach(this.tags, (tag: string, index: number) => {
              ListItem() {
                Text(`#${tag}`)
                  .fontSize(14)
                  .fontColor('#1d1b20')
                  .backgroundColor('#e7e0ec')
                  .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                  .borderRadius(16)
                  .onClick((): void => this.openTagDialog(index))
              }
            })
            if (this.tags.length === 0) {
              ListItem() {
                Text('#添加一个标签吧')
                  .fontSize(14)
                  .fontColor('#99000000')
                  .backgroundColor('#f0f0f0')
                  .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                  .borderRadius(16)
              }
            }
          }
          .listDirection(Axis.Horizontal)
          .scrollBar(BarState.Off)
        }
        .height(48)
        .width('100%')
        .padding({ left: 12, right: 12, top: 8, bottom: 8 })

        // 底部工具栏
        Row() {
          Row({ space: 4 }) {
            // 匿名切换
            this.EditIconButton(this.isAnonymous ? $r('app.media.ic_face_off') : $r('app.media.ic_face'),
              (): void => { this.isAnonymous = !this.isAnonymous })

            // 隐私切换
            this.EditIconButton(this.isPublic ? $r('app.media.ic_public') : $r('app.media.ic_public_off'),
              (): void => { this.isPublic = !this.isPublic })

            // 标签管理
            this.EditIconButton($r('app.media.ic_tag'),
              (): void => this.openTagDialog(-1))

            // 图片选择
            this.EditIconButton($r('app.media.ic_image'),
              (): void => { this.pickImages() })

            // 声明选择
            this.EditIconButton($r('app.media.ic_warning'),
              (): void => this.showClaimSelect())
          }
          .layoutWeight(1)

          Button(this.isLoading ? (this.posterId === 0 ? '发布中' : '提交中') : (this.posterId === 0 ? '发布' : '修改'))
            .type(ButtonType.Capsule)
            .backgroundColor($r('sys.color.brand'))
            .height(40)
            .onClick((): void => { this.handleSubmit() })
            .enabled(!this.isLoading)
        }
        .width('100%')
        .padding({ left: 12, right: 12, bottom: 12 })
        .alignItems(VerticalAlign.Center)

      }
      .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
      .shadow({ radius: 8, color: '#1A000000', offsetY: -2 })
    }
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_background'))
  }

  @Builder TopBarBuilder() {
    Row() {
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        // 修复点：使用本地资源 ic_arrow_back.svg
        Image($r('app.media.ic_public_back'))
          .width(24).height(24)
          .fillColor($r('sys.color.font_primary'))
      }
      .backgroundColor(Color.Transparent)
      .width(48).height(48)
      .onClick((): void => router.back())

      Text(this.posterId === 0 ? '发布帖子' : `编辑帖子#${this.posterId}`)
        .fontSize(20).fontWeight(FontWeight.Bold).layoutWeight(1).padding({ left: 8 })

      Row({ space: 8 }) {
        if (this.isAnonymous) {
          Text('匿名').fontSize(14).fontWeight(FontWeight.Bold).fontColor($r('sys.color.brand'))
        }
        if (!this.isPublic) {
          Text('仅自己可见').fontSize(14).fontWeight(FontWeight.Bold).fontColor($r('sys.color.brand'))
        }
      }
      .margin({ right: 12 })
    }
    .width('100%').height(56).padding({ left: 4 })
  }

  @Builder EditIconButton(icon: Resource, onClick: () => void) {
    Button({ type: ButtonType.Circle }) {
      Image(icon)
        .width(24).height(24)
        .fillColor($r('sys.color.font_primary'))
    }
    .backgroundColor(Color.Transparent)
    .width(44).height(44)
    .onClick(onClick)
  }
}