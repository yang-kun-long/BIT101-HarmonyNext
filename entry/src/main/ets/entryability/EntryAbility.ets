// entry/src/main/ets/entryability/EntryAbility.ets
import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { initTokenStore } from '../services/storage/tokenStore'

/*** 测试区域*/
// import BitSsoSession from '../services/lexue/BitSsoSession';
// import LexueCalendarClient from '../services/lexue/LexueCalendarClient';
//
// // 注意：这里填你自己的统一身份认证账号密码（别忘了提交代码前改回空）
// const TEST_USERNAME = '';
// const TEST_PASSWORD = '';
//
// async function testBitSsoLexue() {
//   const sso = new BitSsoSession({
//     debug: true,
//   });
//
//   try {
//     console.log('[testBitSsoLexue] start login...');
//     await sso.loginToLexue(TEST_USERNAME, TEST_PASSWORD);
//     console.log(
//       '[testBitSsoLexue] loginToLexue OK, isFullyLoggedIn =',
//       sso.isFullyLoggedIn(),
//     );
//
//     // ===== 新增：调用 LexueCalendarClient 拉取日历 ICS =====
//     const calClient = new LexueCalendarClient(sso, {
//       debug: true,
//     });
//
//     const result = await calClient.exportCalendar({
//       what: 'all',              // 对应 Python PRESET_WHAT
//       time: 'recentupcoming',   // 对应 Python PRESET_TIME
//     });
//
//     console.log('[testBitSsoLexue] calendar subscribeUrl =', result.subscribeUrl);
//     console.log(
//       '[testBitSsoLexue] ICS length =',
//       result.icsText.length,
//     );
//     console.log(
//       '[testBitSsoLexue] ICS preview =',
//       result.icsText.replace(/\r?\n/g, '\\n').slice(0, 200),
//     );
//     // ===============================================
//
//   } catch (e) {
//     console.error('[testBitSsoLexue] error =', e);
//   }
// }
/*** 测试区域结束*/


const DOMAIN = 0x0000;
export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    AppStorage.SetOrCreate('filesDir', this.context.filesDir)   // 必须
    AppStorage.SetOrCreate('cacheDir', this.context.cacheDir)   // 建议
    AppStorage.SetOrCreate('tempDir',  this.context.tempDir)    // 建议
    // testBitSsoLexue();
    initTokenStore(this.context);  // 从 '../services/storage/tokenStore' 引入
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}