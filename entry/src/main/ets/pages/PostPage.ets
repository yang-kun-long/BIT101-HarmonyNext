@Component
export default struct PostPage {
  @State content: string = ''

  build() {
    Column({ space: 12 }) {
      Text('话 · 发帖').fontSize(20).fontWeight(FontWeight.Bold)

      TextInput({ placeholder: '说点什么…', text: this.content })
        .onChange(v => this.content = v)
        .height(120).backgroundColor('#FFF').borderRadius(12).padding(8)

      Button('发布')
        .type(ButtonType.Capsule)
        .backgroundColor(this.content.trim().length ? '#2563EB' : '#9CA3AF')
        .enabled(!!this.content.trim().length)
        .onClick(() => {
          // TODO: 调用发布接口
          this.content = ''
        })
    }.padding(16)
  }
}
