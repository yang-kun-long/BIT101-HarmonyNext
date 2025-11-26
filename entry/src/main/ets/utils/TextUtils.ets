// entry/src/main/ets/utils/TextUtils.ets

export interface TextSegment {
  content: string;
  isUrl: boolean;
}

export class TextUtils {
  /**
   * 将文本按 URL 切分
   * 输入: "详情请看 https://baidu.com 谢谢"
   * 输出: [{content: "详情请看 ", isUrl: false}, {content: "https://baidu.com", isUrl: true}, {content: " 谢谢", isUrl: false}]
   */
  static splitTextWithUrls(text: string): TextSegment[] {
    if (!text) return [];

    // 匹配 HTTP/HTTPS 链接的正则
    const urlRegex = /(https?:\/\/[^\s]+)/g;
    const segments: TextSegment[] = [];

    let lastIndex = 0;
    let match: RegExpExecArray | null;

    // 循环查找所有链接
    while ((match = urlRegex.exec(text)) !== null) {
      // 1. 放入链接前的普通文本
      if (match.index > lastIndex) {
        segments.push({
          content: text.substring(lastIndex, match.index),
          isUrl: false
        });
      }

      // 2. 放入链接本身
      segments.push({
        content: match[0],
        isUrl: true
      });

      lastIndex = urlRegex.lastIndex;
    }

    // 3. 放入剩余的文本
    if (lastIndex < text.length) {
      segments.push({
        content: text.substring(lastIndex),
        isUrl: false
      });
    }

    return segments;
  }
}