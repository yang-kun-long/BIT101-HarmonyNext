// entry/src/main/ets/components/gallery/LinkableText.ets
import { TextUtils, TextSegment } from '../../utils/TextUtils';
import router from '@ohos.router';

@Component
export struct LinkableText {
  @Prop text: string;

  // 字体样式配置，方便外部控制大小和颜色
  fontSize: number | string | Resource = 16;
  fontColor: ResourceColor = '#333333';
  lineHeight: number | string | Resource = 24;

  build() {
    Text() {
      // 遍历切分后的文本片段
      ForEach(TextUtils.splitTextWithUrls(this.text), (seg: TextSegment) => {
        if (seg.isUrl) {
          // === 链接部分 ===
          Span(seg.content)
            .fontColor('#007DFF') // 链接显示蓝色
            .decoration({ type: TextDecorationType.Underline, color: '#007DFF' }) // 下划线
            .onClick(() => {
              // 💡 点击链接，跳转到 WebView 页面
              console.info(`点击了链接: ${seg.content}`);
              router.pushUrl({
                url: 'pages/WebBrowserPage', // 确保你创建了这个页面（上一条回答里的）
                params: {
                  url: seg.content,
                  title: '外部链接'
                }
              });
            })
        } else {
          // === 普通文本部分 ===
          Span(seg.content)
            .fontColor(this.fontColor)
            .fontSize(this.fontSize)
        }
      })
    }
    .fontSize(this.fontSize)
    .lineHeight(this.lineHeight)
    .copyOption(CopyOptions.LocalDevice) // 允许长按复制
  }
}