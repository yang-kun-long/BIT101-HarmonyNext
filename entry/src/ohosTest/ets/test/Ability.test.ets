import { abilityDelegatorRegistry, Driver, ON } from '@kit.TestKit';
import { describe, it, expect } from '@ohos/hypium';

export default function abilityTest() {
  describe('Parity navigation', () => {
    it('opens settings and returns from account gallery theme and about pages', 0, async () => {
      const delegator = abilityDelegatorRegistry.getAbilityDelegator();
      await delegator.startAbility({
        bundleName: abilityDelegatorRegistry.getArguments().bundleName,
        abilityName: 'EntryAbility'
      });
      const driver = Driver.create();
      const mine = await driver.waitForComponent(ON.text('我'), 10000);
      expect(mine !== null).assertTrue();
      await mine!.click();
      const settings = await driver.waitForComponent(ON.text('设置'), 10000);
      expect(settings !== null).assertTrue();
      await settings!.click();
      expect(await driver.waitForComponent(ON.text('页面设置'), 5000) !== null).assertTrue();
      const checks: string[][] = [
        ['账号设置', '账号设置'],
        ['话廊设置', '允许横向滑动'],
        ['外观设置', '自动旋转'],
        ['关于', 'BIT101']
      ];
      for (const check of checks) {
        const entry = await driver.waitForComponent(ON.text(check[0]), 5000);
        expect(entry !== null).assertTrue();
        await entry!.click();
        expect(await driver.waitForComponent(ON.text(check[1]), 5000) !== null).assertTrue();
        await driver.pressBack();
        expect(await driver.waitForComponent(ON.text('页面设置'), 5000) !== null).assertTrue();
      }
      await driver.pressBack();
      expect(await driver.waitForComponent(ON.text('我'), 5000) !== null).assertTrue();
    });

    it('opens login without credentials and returns to the guest page', 0, async () => {
      const driver = Driver.create();
      const login = await driver.waitForComponent(ON.text('去登录'), 5000);
      expect(login !== null).assertTrue();
      await login!.click();
      expect(await driver.waitForComponent(ON.text('BIT101 登录（HarmonyOS NEXT）'), 5000) !== null).assertTrue();
      await driver.pressBack();
      expect(await driver.waitForComponent(ON.text('去登录'), 5000) !== null).assertTrue();
    });

    it('updates every gallery switch immediately and retains values after reopening', 0, async () => {
      const driver = Driver.create();
      await (await driver.waitForComponent(ON.text('设置'), 5000))!.click();
      await (await driver.waitForComponent(ON.text('话廊设置'), 5000))!.click();
      expect(await driver.waitForComponent(ON.text('允许横向滑动'), 5000) !== null).assertTrue();
      const switches = await driver.findComponents(ON.type('Toggle'));
      expect(switches.length).assertEqual(5);
      for (let index = 0; index < switches.length; index++) {
        const active = await driver.findComponents(ON.type('Toggle'));
        const original = await active[index].isChecked();
        try {
          await active[index].click();
          await driver.delayMs(300);
          expect(await active[index].isChecked()).assertEqual(!original);
          await driver.pressBack();
          await (await driver.waitForComponent(ON.text('话廊设置'), 5000))!.click();
          expect(await driver.waitForComponent(ON.text('允许横向滑动'), 5000) !== null).assertTrue();
          const reopened = await driver.findComponents(ON.type('Toggle'));
          expect(await reopened[index].isChecked()).assertEqual(!original);
        } finally {
          const current = await driver.findComponents(ON.type('Toggle'));
          if (await current[index].isChecked() !== original) await current[index].click();
          await driver.delayMs(300);
        }
      }
      await driver.pressBack();
      await driver.pressBack();
    });

  });
}
