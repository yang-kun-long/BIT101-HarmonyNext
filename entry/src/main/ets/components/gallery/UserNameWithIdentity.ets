// entry/src/main/ets/components/gallery/UserNameWithIdentity.ets
import { GalleryUser } from '../../services/gallery/GalleryModels';

@Component
export struct UserNameWithIdentity {
  @Prop user: GalleryUser | null = null;
  @Prop fontSize: number = 16;
  @Prop fontColor: ResourceColor = '#1F2937';

  build() {
    Row({ space: 6 }) {
      // 1. 昵称
      Text(this.user?.nickname || '匿名用户')
        .fontSize(this.fontSize)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.fontColor)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .constraintSize({ maxWidth: '70%' })

      // 2. 身份标签
      if (this.user?.identity && this.user.identity.id !== 0 && this.user.identity.text) {
        Text(this.user.identity.text)
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.user.identity.color)
          .backgroundColor(this.hexToRgba(this.user.identity.color, 0.1))
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .borderRadius(4)
      }
    }
    .alignItems(VerticalAlign.Center)
  }

  // 🔴 修复：重写 hexToRgba，移除 'any' 类型
  private hexToRgba(hex: string, alpha: number): string {
    if (!hex || !hex.startsWith('#')) return '#00000000';

    let hexValue = hex.substring(1); // 去掉 #

    // 处理缩写情况 #ABC -> #AABBCC
    if (hexValue.length === 3) {
      hexValue = hexValue.split('').map((char) => char + char).join('');
    }

    if (hexValue.length !== 6) return hex; // 格式不对直接返回

    // 显式解析为数字
    const r = parseInt(hexValue.substring(0, 2), 16);
    const g = parseInt(hexValue.substring(2, 4), 16);
    const b = parseInt(hexValue.substring(4, 6), 16);

    return `rgba(${r},${g},${b},${alpha})`;
  }
}