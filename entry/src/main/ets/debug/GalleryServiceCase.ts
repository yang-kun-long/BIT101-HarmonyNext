import { DebugCase } from './DebugCase';
import { galleryService, PostersMode } from '../services/gallery/GalleryService';
import { bit101Session } from '../core/network/bit101Session'; // 仅为了打印一些调试信息

export class GalleryServiceCase extends DebugCase {
  readonly name = 'Gallery Service / API Connectivity Test';

  async run(): Promise<void> {
    this.logInfo('=== 🧪 开始测试 GalleryService ===');

    // 1. 检查基础环境
    this.logInfo('1. 检查 Session 配置...');
    // 这里我们无法直接打印内部 URL，但可以发起一个简单请求测试
    // 假设 TokenStore 能正常工作（即使没登录，getFakeCookie 返回 undefined 也不应报错）

    // 2. 测试获取推荐列表 (最常用接口)
    this.logInfo('2. 请求 [推荐] 列表 (Page 0)...');
    const start = Date.now();

    try {
      const list = await galleryService.getPosters(PostersMode.Recommend, 0);
      const cost = Date.now() - start;

      this.logInfo(`   ✅ 请求成功! 耗时: ${cost}ms`);
      this.logInfo(`   📊 返回数据条数: ${list.length}`);

      if (list.length > 0) {
        const item = list[0];
        // 打印第一条数据的关键字段，肉眼确认解析是否正确
        this.logInfo('   🧐 第一条数据样本:', {
          id: item.id,
          userName: item.user?.nickname || '❌解析失败', // 如果 user 为空，说明模型定义不对
          text: item.text ? item.text.substring(0, 30) + '...' : '❌无内容',
          imgCount: item.images ? item.images.length : '❌无图片字段',
          likeNum: item.likeNum
        });
      } else {
        this.logWarn('   ⚠️ 列表为空。如果是新用户或游客模式，这可能是正常的，但也请确认 API 是否有数据。');
      }

    } catch (e) {
      this.logError('   ❌ 请求失败 / 解析异常', e);
    }

    // 3. 测试获取最新 (验证参数传递)
    this.logInfo('3. 请求 [最新] 列表 (带参数测试)...');
    try {
      const listNew = await galleryService.getPosters(PostersMode.Newest, 0);
      this.logInfo(`   ✅ 最新列表获取成功, 条数: ${listNew.length}`);
    } catch (e) {
      this.logError('   ❌ 最新列表请求失败', e);
    }

    this.logInfo('=== 🏁 测试结束 ===');
  }
}