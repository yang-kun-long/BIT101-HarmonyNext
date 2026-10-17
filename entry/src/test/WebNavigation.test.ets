import { describe, it, expect } from '@ohos/hypium';
import { WebNavigationState, webBackward, WebBackTarget, shouldShowWebError, canOpenExternalWebUrl,
  isHttpWebUrl } from '../main/ets/components/web/WebNavigationModel';

export default function webNavigationTest() {
  describe('Shared Web container browsing policy', () => {
    it('preserves per-page URL, history and scroll in memory and isolates browser pages', 0, () => {
      const state = new WebNavigationState(); state.recordUrl('https://bit101.cn/gallery/1');
      state.recordScroll(10, 300); state.recordHistory(new Uint8Array([1, 2]));
      state.recordUrl('https://bit101.cn/gallery/1'); expect(state.scroll.y).assertEqual(300);
      expect(new WebNavigationState().history).assertNull();
      state.recordUrl('https://bit101.cn/gallery/2'); expect(state.scroll.y).assertEqual(0);
      state.recordScroll(NaN, -1); expect(state.scroll.x + state.scroll.y).assertEqual(0);
      state.recordUrl('javascript:evil()'); expect(state.url).assertEqual('https://bit101.cn/gallery/2');
      state.recordHistory(new Uint8Array(512 * 1024 + 1)); expect(state.history).assertNull();
      state.clear(); expect(state.url).assertEqual(''); expect(state.history).assertNull();
    });

    it('ignores failed subresources and reports only main-frame HTTP or network failures', 0, () => {
      expect(shouldShowWebError(false)).assertFalse(); expect(shouldShowWebError(false, 503)).assertFalse();
      expect(shouldShowWebError(true, 200)).assertFalse(); expect(shouldShowWebError(true, 503)).assertTrue();
      expect(shouldShowWebError(true)).assertTrue();
    });

    it('allows browser downloads and ordinary external links with explicit protocols', 0, () => {
      expect(canOpenExternalWebUrl('https://example.org/file.pdf')).assertTrue();
      expect(canOpenExternalWebUrl('mailto:example@bit.edu.cn')).assertTrue();
      expect(canOpenExternalWebUrl('tel:+861234567')).assertTrue();
      for (const url of ['javascript:alert(1)', 'file:///data/private', 'data:text/plain,secret',
        'blob:https://bit101.cn/id', 'https://example.org/\nattack']) {
        expect(canOpenExternalWebUrl(url)).assertFalse();
      }
      expect(isHttpWebUrl('about:blank')).assertFalse();
    });

    it('consumes back only when a controller can navigate and handles unattached controllers', 0, () => {
      let backed = 0; let canBack = false;
      const target: WebBackTarget = { accessBackward: () => canBack, backward: () => { backed++; } };
      expect(webBackward(target)).assertFalse(); canBack = true; expect(webBackward(target)).assertTrue();
      expect(backed).assertEqual(1);
      const unattached: WebBackTarget = { accessBackward: () => { throw new Error('not attached'); }, backward: () => {} };
      expect(webBackward(unattached)).assertFalse();
    });
  });
}
