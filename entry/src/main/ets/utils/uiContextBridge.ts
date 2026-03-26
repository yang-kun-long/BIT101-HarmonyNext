import type router from '@ohos.router';
import type promptAction from '@ohos.promptAction';

type UiContextLike = {
  getRouter(): {
    pushUrl(options: router.RouterOptions): Promise<void>;
    replaceUrl(options: router.RouterOptions): Promise<void>;
    back(options?: router.RouterOptions): void;
    clear(): void;
    getParams(): Object;
  };
  getPromptAction(): {
    showToast(options: promptAction.ShowToastOptions): void;
  };
};

export function uiPushUrl(uiContext: UiContextLike, options: router.RouterOptions): Promise<void> {
  try {
    return uiContext.getRouter().pushUrl(options);
  } catch (error) {
    return Promise.reject(error);
  }
}

export function uiReplaceUrl(uiContext: UiContextLike, options: router.RouterOptions): Promise<void> {
  try {
    return uiContext.getRouter().replaceUrl(options);
  } catch (error) {
    return Promise.reject(error);
  }
}

export function uiBack(uiContext: UiContextLike, options?: router.RouterOptions): void {
  try {
    uiContext.getRouter().back(options);
  } catch (_) {
  }
}

export function uiClear(uiContext: UiContextLike): void {
  try {
    uiContext.getRouter().clear();
  } catch (_) {
  }
}

export function uiGetParams(uiContext: UiContextLike): Object {
  return uiContext.getRouter().getParams();
}

export function uiShowToast(uiContext: UiContextLike, options: promptAction.ShowToastOptions): void {
  try {
    uiContext.getPromptAction().showToast(options);
  } catch (_) {
  }
}

export function uiShowAlertDialog(
  uiContext: { showAlertDialog(options: Object): void },
  options: Object,
): void {
  try {
    uiContext.showAlertDialog(options);
  } catch (_) {
  }
}
