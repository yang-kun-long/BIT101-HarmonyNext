import { NavigationPage } from '../services/settings/PageSettingsModel';
export { NavigationPage as PageShowOnNav } from '../services/settings/PageSettingsModel';

export function getPageName(page: NavigationPage): string {
  switch (page) {
    case NavigationPage.Schedule: return "课程与日程";
    case NavigationPage.Map: return "地图";
    case NavigationPage.Forum: return "BIT101 网页";
    case NavigationPage.Post: return "话廊";
    case NavigationPage.Mine: return "我的";
    default: return "未知";
  }
}
