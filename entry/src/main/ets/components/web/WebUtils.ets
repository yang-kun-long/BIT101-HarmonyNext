// 文件路径：ets/components/web/WebUtils.ets
import photoAccessHelper from '@ohos.file.photoAccessHelper';
import picker from '@ohos.file.picker';

// 1. 手动定义我们需要用到的接口，不再依赖 SDK 导出
interface MyFileSelectorParam {
  getAcceptType(): Array<string>;
}

interface MyFileSelectorResult {
  handleFileList(fileList: Array<string>): void;
}

// 定义事件对象的结构
export interface WebFileSelectorEvent {
  result: MyFileSelectorResult;
  fileSelectorParam: MyFileSelectorParam;
}

/**
 * 处理 Web 组件的文件选择请求
 */
export async function handleFileSelect(event: WebFileSelectorEvent): Promise<void> {
  // 获取网页想要的文件类型
  const acceptTypes = event.fileSelectorParam.getAcceptType();

  // 2. 这里的 (type: string) 显式声明了类型，解决了 "implicit any" 报错
  const isImage = acceptTypes.some((type: string) => type.includes('image'));

  if (isImage) {
    // === 情况 A：选择图片 ===
    const photoPicker = new photoAccessHelper.PhotoViewPicker();
    try {
      const result = await photoPicker.select({
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1
      });

      if (result.photoUris.length > 0) {
        event.result.handleFileList(result.photoUris);
      } else {
        event.result.handleFileList([]); // 用户取消
      }
    } catch (err) {
      // 这里的 err 类型在 catch 中通常是 unknown，我们不处理它，直接返回空
      event.result.handleFileList([]);
    }
  } else {
    // === 情况 B：选择其他文件 ===
    const docPicker = new picker.DocumentViewPicker();
    try {
      const result = await docPicker.select({
        maxSelectNumber: 1
      });

      if (result.length > 0) {
        event.result.handleFileList(result);
      } else {
        event.result.handleFileList([]);
      }
    } catch (err) {
      event.result.handleFileList([]);
    }
  }
}
