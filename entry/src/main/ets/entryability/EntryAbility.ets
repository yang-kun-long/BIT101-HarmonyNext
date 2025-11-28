import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
// 1. 移除 hilog 导入，换成 Logger
import { Logger } from '../utils/Logger';

import { initTokenStore } from '../services/storage/tokenStore'
import { initLexueCookieStore } from '../services/storage/LexueCookieStore';
import { runCurrentDebugCase } from '../debug/DebugRunner';
import { initLexueCalendarStore } from '../services/storage/LexueCalendarStore';

// 2. 移除 DOMAIN 常量，Logger 内部已定义
// const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  // 3. 实例化 Logger
  // Tag: BIT101_EntryAbility
  private logger = new Logger('EntryAbility');

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    // 使用 Logger 替代 hilog
    this.logger.info('Ability onCreate');

    AppStorage.SetOrCreate('filesDir', this.context.filesDir);
    AppStorage.SetOrCreate('cacheDir', this.context.cacheDir);
    AppStorage.SetOrCreate('tempDir',  this.context.tempDir);

    initTokenStore(this.context);
    initLexueCookieStore(this.context);
    initLexueCalendarStore(this.context);

    // 如果是 Debug 包就跑测试
    // (这里的 isDebugMode 控制是否运行测试用例，和 Logger.IS_DEBUG 是两回事，可以保留)
    if (this.isDebugMode()) {
      this.logger.info('Debug mode detected, running debug cases...');
      runCurrentDebugCase();
    }

    try {
      this.context.getApplicationContext()
        .setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      // 4. 替换错误打印
      // 旧: hilog.error(..., JSON.stringify(err));
      // 新: 自动处理 error 对象
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

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        // 5. 替换加载报错
        this.logger.error('Failed to load the content. Cause:', err);
        return;
      }
      this.logger.info('Succeeded in loading the content.');
    });
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