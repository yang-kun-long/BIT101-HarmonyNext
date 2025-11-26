// entry/src/main/ets/pages/PosterDetailPage.ets
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { PosterDetail, GalleryImage, Comment, GalleryUser } from '../services/gallery/GalleryModels';
import { galleryService } from '../services/gallery/GalleryService';
import { TimeUtils } from '../utils/TimeUtils';
import { RCP_BASE_URL } from '../core/network/bit101Session';
import { reactionService } from '../services/gallery/ReactionService';
import { AvatarWithVerified } from '../components/gallery/AvatarWithVerified';
import { UserNameWithIdentity } from '../components/gallery/UserNameWithIdentity';
import curves from '@ohos.curves';

// ✅ 1. 引入支持链接点击的文本组件
import { LinkableText } from '../components/gallery/LinkableText';

@Entry
@Component
export default struct PosterDetailPage {
  @State postId: number = 0;
  @State poster: PosterDetail | null = null;
  @State loading: boolean = true;
  @State comments: Comment[] = [];
  @State commentsLoading: boolean = false;

  // UI 状态
  @State isTitleVisibleInTopBar: boolean = false; // 控制 TopBar 显示状态
  private scroller: Scroller = new Scroller();
  private readonly SCROLL_THRESHOLD = 60; // 滚动多少距离后切换标题

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object>;
    const idParam = params?.['id'];

    if (idParam !== undefined) {
      this.postId = Number(idParam);
      this.loadPoster();
      this.loadComments();
    } else {
      this.loading = false;
    }
  }

  private async loadComments(): Promise<void> {
    this.commentsLoading = true;
    const list = await reactionService.getCommentsForPoster(this.postId, 'new');
    this.comments = list;
    this.commentsLoading = false;
  }

  private async loadPoster(): Promise<void> {
    this.loading = true;
    const detail = await galleryService.getPosterById(this.postId);
    if (detail) {
      this.poster = detail;
    }
    this.loading = false;
  }

  // 模拟 Toast
  private showToast(msg: string) : void{
    promptAction.showToast({ message: msg, duration: 1500 });
  }

  build() {
    Column() {
      // 1. 顶部导航栏 (固定在顶部)
      this.TopBar();

      // 2. 内容滚动区域 (权重1，占满中间)
      if (this.loading && !this.poster) {
        this.LoadingView();
      } else if (!this.poster) {
        this.ErrorView();
      } else {
        Scroll(this.scroller) {
          Column() {
            this.PosterContent(this.poster as PosterDetail);
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }
        .layoutWeight(1)
        .width('100%')
        .backgroundColor(Color.White)
        .align(Alignment.TopStart)
        .onScroll(() => {
          // 监听滚动，切换 TopBar 状态
          const yOffset = this.scroller.currentOffset().yOffset;
          if (yOffset > this.SCROLL_THRESHOLD && !this.isTitleVisibleInTopBar) {
            this.isTitleVisibleInTopBar = true; // 切换为标题
          } else if (yOffset <= this.SCROLL_THRESHOLD && this.isTitleVisibleInTopBar) {
            this.isTitleVisibleInTopBar = false; // 切换为用户信息
          }
        })
      }

      // 3. 底部操作栏 (固定在底部)
      if (this.poster) {
        this.BottomBar();
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.White)
  }

  // =============== 组件：加载/错误 ===============
  @Builder LoadingView() {
    Column() {
      Text('正在加载帖子...').fontSize(16).fontColor('#9CA3AF')
    }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
  }

  @Builder ErrorView() {
    Column() {
      Text('未找到帖子').fontSize(16).fontColor('#9CA3AF')
    }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
  }

  // =============== 组件：TopBar ===============
  @Builder
  TopBar(): void {
    Row() {
      // 返回按钮
      Image($r('app.media.ic_public_back'))
        .width(24)
        .height(24)
        .fillColor('#1F2937')
        .onClick(() => router.back())
        .margin({ right: 12 });

      // 中间动态内容
      Stack() {
        if (this.poster) {
          // 状态 A: 显示用户信息 (默认)
          Row() {
            // ✅ 1. 替换头像
            AvatarWithVerified({
              user: this.poster.user,
              avatarSize: 32, // TopBar 头像稍大
              onClickUser: () => this.showToast(`查看用户: ${this.poster?.user?.id}`)
            })

            Column() {
              // ✅ 2. 替换昵称和身份
              // 注意：UserNameWithIdentity 已经包含了身份标签，所以这里只需要放这一个组件
              UserNameWithIdentity({
                user: this.poster.user,
                fontSize: 14,
                fontColor: '#1F2937'
              })

              // 如果想保留原来的副标题逻辑（比如 "身份: 管理员"），由于新组件已经集成了标签，
              // 这里通常不需要再额外显示身份文本了，除非你有其他信息（比如时间）要显示。
            }
            .alignItems(HorizontalAlign.Start)
            .margin({ left: 8 })
          }
          .width('100%')
          .opacity(this.isTitleVisibleInTopBar ? 0 : 1) // 渐隐
          .animation({ duration: 200 })
          .visibility(this.isTitleVisibleInTopBar ? Visibility.None : Visibility.Visible)

          // 状态 B: 显示标题 (滚动后)
          Text(this.poster.title)
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1F2937')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .opacity(this.isTitleVisibleInTopBar ? 1 : 0) // 渐显
            .animation({ duration: 200 })
            .visibility(this.isTitleVisibleInTopBar ? Visibility.Visible : Visibility.None)
        }
      }
      .layoutWeight(1)
      .alignContent(Alignment.Start)

      // 更多按钮
      Image($r('app.media.ic_public_more'))
        .width(24)
        .height(24)
        .fillColor('#1F2937')
        .margin({ left: 12 })
        .onClick(() => this.showToast('更多操作'));
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(Color.White)
    .shadow({ radius: 3, color: '#0A000000', offsetY: 1 }) // 细微阴影
    .zIndex(10)
  }

  // =============== 组件：BottomBar ===============
  @Builder
  BottomBar(): void {
    Row() {
      // 胶囊输入框
      Row() {
        Text('快来评论吧')
          .fontSize(14)
          .fontColor('#9CA3AF') // 灰色占位符
      }
      .height(36)
      .layoutWeight(1)
      .backgroundColor('#F3F4F6')
      .borderRadius(18)
      .padding({ left: 16 })
      .alignItems(VerticalAlign.Center)
      .margin({ right: 16 })
      .onClick(() => this.showToast('打开评论输入框'));

      // 点赞区域
      Row() {
        Image(this.poster?.like ? $r('app.media.ic_public_heart_filled') : $r('app.media.ic_public_heart_outline'))
          .width(26)
          .height(26)
          .fillColor(this.poster?.like ? '#EF4444' : '#6B7280')
          .onClick(() => {
            if (this.poster) {
              this.poster.like = !this.poster.like;
              this.poster.likeNum += this.poster.like ? 1 : -1;
              this.showToast(this.poster.like ? '点赞成功' : '取消点赞');
            }
          })
          .animation({ duration: 300, curve: curves.springCurve(10, 1, 228, 30) })

        Text(this.formatNumber(this.poster?.likeNum || 0))
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1F2937')
          .margin({ left: 4 });
      }
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(60)
    .padding({ left: 12, right: 16 })
    .backgroundColor(Color.White)
    .border({ width: { top: 0.5 }, color: '#E5E7EB' })
  }

  // =============== 组件：帖子正文 ===============
  @Builder
  PosterContent(p: PosterDetail): void {
    Column() {
      // 1. 标题 (SelectionContainer 允许复制)
      Text(p.title)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor('#111827')
        .lineHeight(30)
        .margin({ bottom: 8 })
        .copyOption(CopyOptions.LocalDevice);

      // 2. 创作者声明 (红色警告)
      if (p.claim && p.claim.id !== 0) {
        Text(`创作者声明：${p.claim.text}`)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor('#EF4444') // Error Red
          .margin({ bottom: 8 });
      }

      // 3. 正文 (✅ 核心修改：使用 LinkableText 替换 Text)
      if (p.text) {
        LinkableText({
          text: p.text,
          fontSize: 16,
          fontColor: '#1F2937', // 保持原有颜色
          lineHeight: 26        // 保持原有行高
        })
          .margin({ bottom: 12 })
          .width('100%')
      }

      // 4. 图片网格
      if (p.images && p.images.length > 0) {
        this.ImageGrid(p.images);
      }

      // 5. 标签 (Flex Wrap)
      if (p.tags && p.tags.length > 0) {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(p.tags, (tag: string) => {
            Text('#' + tag)
              .fontSize(15)
              .fontColor('#2563EB')
              .margin({ right: 12, bottom: 6 })
              .onClick(() => this.showToast(`复制标签: #${tag}`));
          })
        }.margin({ top: 4, bottom: 4 });
      }

      // 6. 最后编辑时间
      Text(`最后编辑于：${this.getTimeText(p)}`)
        .fontSize(12)
        .fontColor('#9CA3AF')
        .margin({ top: 4, bottom: 16 });

      // 7. 分隔线
      Divider().color('#F3F4F6').strokeWidth(8).margin({ left: -16, right: -16 });

      // 8. 评论区
      this.CommentsSection(p);
    }
    .padding({ left: 16, right: 16, top: 16, bottom: 24 })
    .alignItems(HorizontalAlign.Start)
  }

  // =============== 组件：图片网格 (保持不变) ===============
  @Builder
  ImageGrid(images: GalleryImage[]): void {
    Grid() {
      ForEach(images, (img: GalleryImage, index: number) => {
        GridItem() {
          Image(this.getImageUrl(img.url))
            .width('100%')
            .aspectRatio(1)
            .objectFit(ImageFit.Cover)
            .borderRadius(6)
            .backgroundColor('#F3F4F6')
            .onClick(() => this.showToast(`查看大图 ${index + 1}`));
        }
      })
    }
    .columnsTemplate('1fr 1fr 1fr') // 3列
    .columnsGap(4)
    .rowsGap(4)
    .height(Math.ceil(images.length / 3) * 120)
    .margin({ bottom: 12 });
  }

  // =============== 组件：评论区 (保持不变) ===============
  @Builder
  CommentsSection(p: PosterDetail): void {
    Column() {
      // 头部
      Row() {
        Text(`评论 ${p.commentNum || 0}`)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#111827');

        Blank();

        // 排序 Mock
        Row() {
          Text('默认排序').fontSize(13).fontColor('#6B7280');
        }.onClick(() => this.showToast('切换排序'));
      }
      .width('100%')
      .height(48)
      .alignItems(VerticalAlign.Center);

      // 列表
      if (this.commentsLoading && this.comments.length === 0) {
        Text('加载评论中...').fontSize(14).fontColor('#9CA3AF').margin({top: 20});
      } else if (this.comments.length === 0) {
        Column() {
          Image($r('app.media.ic_public_empty_comment')) // ⚠️ Empty icon
            .width(40).height(40).fillColor('#D1D5DB').margin({bottom: 8});
          Text('这里没有评论呢').fontSize(14).fontColor('#9CA3AF');
        }
        .width('100%')
        .padding({ top: 32, bottom: 32 })
        .alignItems(HorizontalAlign.Center);
      } else {
        ForEach(this.comments, (c: Comment) => {
          this.CommentItem(c);
        });

        Text('没有更多评论了')
          .fontSize(12)
          .fontColor('#D1D5DB')
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding(24);
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ top: 8 })
  }

  // =============== 组件：单条评论 (保持不变) ===============
  @Builder
  CommentItem(c: Comment): void {
    Row() {
      // 1. 头像
      Image(this.getCommentAvatarUrl(c))
        .width(36)
        .height(36)
        .borderRadius(18)
        .backgroundColor('#F3F4F6')
        .objectFit(ImageFit.Cover)
        .margin({ right: 12 })
        .onClick(() => this.showToast(`跳转用户: ${c.user?.nickname}`));

      Column() {
        // 2. 昵称栏
        Row() {
          Text(this.getCommentNickname(c))
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#4B5563')
            .layoutWeight(1);

          // 点赞
          Row() {
            Image(c.like ? $r('app.media.ic_public_heart_filled') : $r('app.media.ic_public_heart_outline'))
              .width(14)
              .height(14)
              .fillColor(c.like ? '#EF4444' : '#9CA3AF')
              .animation({ duration: 300, curve: Curve.FastOutSlowIn })

            Text(this.formatNumber(c.likeNum))
              .fontSize(12)
              .fontColor('#6B7280')
              .margin({ left: 4 });
          }
          .onClick(() => {
            const index = this.comments.indexOf(c);
            if (index !== -1) {
              const newComment: Comment = JSON.parse(JSON.stringify(c));
              newComment.like = !newComment.like;
              newComment.likeNum = (newComment.likeNum || 0) + (newComment.like ? 1 : -1);
              this.comments[index] = newComment;
              this.showToast(newComment.like ? '点赞' : '取消');
            }
          })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center);

        // 3. 内容
        Text(c.text)
          .fontSize(15)
          .fontColor('#1F2937')
          .lineHeight(22)
          .margin({ top: 4 })
          .onClick(() => this.showToast('回复评论'));

        // 4. 底部信息
        Row() {
          Text(this.getCommentTimeText(c)).fontSize(12).fontColor('#9CA3AF').margin({ right: 12 });
          Text('回复').fontSize(12).fontColor('#4B5563').fontWeight(FontWeight.Bold);
        }
        .margin({ top: 6, bottom: 6 });

        // 5. 子评论
        if (c.sub && c.sub.length > 0) {
          Column() {
            ForEach(c.sub, (item: Comment) => {
              this.SubCommentItem(c, item);
            }, (item: Comment) => item.id.toString());
            Text('查看更多回复')
              .fontSize(13).fontColor('#2563EB').padding({ top: 6 })
              .onClick(() => this.showToast('展开更多回复'));
          }
          .width('100%')
          .backgroundColor('#F9FAFB')
          .borderRadius(8)
          .padding(8)
          .margin({ top: 4 });
        }

        Divider().color('#E5E7EB').margin({ top: 12 });
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding({ top: 12 });
  }

  @Builder
  SubCommentItem(parentComment: Comment, subComment: Comment): void {
    Row() {
      // 头像
      Image(this.getCommentAvatarUrl(subComment))
        .width(24)
        .height(24)
        .borderRadius(12)
        .backgroundColor('#E5E7EB')
        .margin({ right: 8 })
        .objectFit(ImageFit.Cover);

      Column() {
        // 昵称栏 + 点赞
        Row() {
          // 1. 昵称
          Text(this.getCommentNickname(subComment))
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#4B5563')
            .layoutWeight(1);

          // 2. 子评论点赞按钮
          Row() {
            Image(subComment.like ? $r('app.media.ic_public_heart_filled') : $r('app.media.ic_public_heart_outline'))
              .width(14)
              .height(14)
              .fillColor(subComment.like ? '#EF4444' : '#9CA3AF')
              .animation({ duration: 300, curve: Curve.FastOutSlowIn })

            Text(this.formatNumber(subComment.likeNum))
              .fontSize(12)
              .fontColor('#9CA3AF')
              .margin({ left: 4 });
          }
          .onClick(() => {
            const parentIndex = this.comments.indexOf(parentComment);
            if (parentIndex !== -1) {
              try {
                const newParent = JSON.parse(JSON.stringify(parentComment)) as Comment;
                if (newParent.sub) {
                  const subIndex = newParent.sub.findIndex((item: Comment) => item.id === subComment.id);
                  if (subIndex !== -1) {
                    const targetSub = newParent.sub[subIndex];
                    targetSub.like = !targetSub.like;
                    targetSub.likeNum = (targetSub.likeNum || 0) + (targetSub.like ? 1 : -1);
                    this.comments[parentIndex] = newParent;
                    this.showToast(targetSub.like ? '点赞' : '取消');
                  }
                }
              } catch (e) {
                console.error('Like sub comment failed:', e);
              }
            }
          })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center);

        // 3. 正文
        Text(subComment.text)
          .fontSize(15)
          .fontColor('#1F2937')
          .lineHeight(24)
          .margin({ top: 4 });
      }
      .layoutWeight(1);
    }
    .width('100%')
    .margin({ bottom: 12 });
  }

  // =============== 工具方法 ===============

  private formatNumber(num: number | undefined): string {
    if (!num) return '0';
    if (num > 9999) return (num / 10000).toFixed(1) + 'w';
    return num.toString();
  }

  private getIdentityColor(colorStr?: string): string {
    if (!colorStr) return '#999999';
    try {
      return colorStr;
    } catch (e) {
      return '#999999';
    }
  }

  private getNickname(p: PosterDetail): string {
    if (p.anonymous) return '匿名用户';
    return p.user?.nickname || '匿名用户';
  }

  private getTimeText(p: PosterDetail): string {
    const rawTime = p.editTime || p.createTime;
    return TimeUtils.getRelativeTime(rawTime);
  }

  private getCommentNickname(c: Comment): string {
    return c.anonymous ? '匿名用户' : (c.user?.nickname || '匿名用户');
  }

  private getCommentTimeText(c: Comment): string {
    return TimeUtils.getRelativeTime(c.updateTime || c.createTime);
  }

  private getCommentAvatarUrl(c: Comment): string | Resource {
    if (c.anonymous || !c.user || !c.user.avatar) {
      return $r('app.media.startIcon');
    }
    return this.getImageUrl(c.user.avatar);
  }

  private getAvatarUrl(p: PosterDetail): string | Resource {
    if (p.anonymous || !p.user || !p.user.avatar) {
      return $r('app.media.startIcon');
    }
    return this.getImageUrl(p.user.avatar);
  }

  private getImageUrl(url: string): string {
    if (!url) return '';
    if (url.startsWith('http')) return url;
    return `${RCP_BASE_URL}${url}`;
  }
}