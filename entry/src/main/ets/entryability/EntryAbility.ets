import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { Logger } from '../utils/Logger';

import { initTokenStore } from '../services/storage/tokenStore'
import { initLexueCookieStore } from '../services/storage/LexueCookieStore';
import { runCurrentDebugCase } from '../debug/DebugRunner';
import { initLexueCalendarStore } from '../services/storage/LexueCalendarStore';
// 确保路径正确，如果在 pages 下就是 '../pages/PageEnum'
import { PageShowOnNav } from '../pages/PageEnum';

export default class EntryAbility extends UIAbility {
  private logger = new Logger('EntryAbility');

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.logger.info('Ability onCreate');

    AppStorage.setOrCreate('filesDir', this.context.filesDir);
    AppStorage.setOrCreate('cacheDir', this.context.cacheDir);
    AppStorage.setOrCreate('tempDir',  this.context.tempDir);

    initTokenStore(this.context);
    initLexueCookieStore(this.context);
    initLexueCalendarStore(this.context);

    if (this.isDebugMode()) {
      this.logger.info('Debug mode detected, running debug cases...');
      runCurrentDebugCase();
    }

    try {
      this.context.getApplicationContext()
        .setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      this.logger.error('Failed to set colorMode. Cause:', err);
    }
  }

  private isDebugMode(): boolean {
    return true;
  }

  onDestroy(): void {
    this.logger.info('Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    this.logger.info('Ability onWindowStageCreate');

    // 🔥🔥🔥【核心修复】：在加载 UI 之前，先初始化持久化数据 🔥🔥🔥
    this.initPersistentStorage();

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        this.logger.error('Failed to load the content. Cause:', err);
        return;
      }
      this.logger.info('Succeeded in loading the content.');
    });
  }

  // 🔥 新增：初始化持久化存储的方法
  private initPersistentStorage() {
    this.logger.info('Initializing PersistentStorage...');

    // 1. 定义默认顺序
    const defaultPages = [
      PageShowOnNav.Home,   // 1. 卷
      PageShowOnNav.Map,    // 2. 图 (之前漏了导致Tab消失)
      PageShowOnNav.Forum,  // 3. 网
      PageShowOnNav.Post,   // 4. 话 (之前漏了导致Tab消失)
      PageShowOnNav.Mine    // 5. 我
    ];

    // 2. 初始化 pages_order
    // persistProp 的作用是：如果磁盘里没有这个key，就写入默认值；如果有，就读磁盘的
    PersistentStorage.persistProp('pages_order', defaultPages);

    // 3. 初始化其他配置
    PersistentStorage.persistProp('pages_hidden', []);
    PersistentStorage.persistProp('home_page', PageShowOnNav.Home);

    // 4. 🔥 强制数据清洗 🔥
    // 因为之前的 bug 可能导致磁盘里存了一个空数组 []
    // persistProp 读到空数组会认为是有效数据，导致 Tab 栏消失
    // 所以这里必须手动检查一下，如果是空的，强制覆盖！
    const currentOrder = AppStorage.get<PageShowOnNav[]>('pages_order');
    if (!currentOrder || currentOrder.length === 0) {
      this.logger.warn('Found empty or dirty pages_order, resetting to default.');
      AppStorage.setOrCreate('pages_order', defaultPages);
    }
  }

  onWindowStageDestroy(): void {
    this.logger.info('Ability onWindowStageDestroy');
  }

  onForeground(): void {
    this.logger.info('Ability onForeground');
  }

  onBackground(): void {
    this.logger.info('Ability onBackground');
  }
}