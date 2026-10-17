export enum NavigationPage {
  Schedule = 'Schedule',
  Map = 'Map',
  Forum = 'Forum',
  Post = 'Post',
  Mine = 'Mine',
}

export interface PageSettings {
  order: NavigationPage[];
  hidden: NavigationPage[];
  home: NavigationPage;
}

export interface LegacyPageSettings {
  order: string[];
  hidden: string[];
  home: string;
}

export function defaultPageSettings(): PageSettings {
  return {
    order: [NavigationPage.Schedule, NavigationPage.Map, NavigationPage.Forum, NavigationPage.Post, NavigationPage.Mine],
    hidden: [],
    home: NavigationPage.Schedule,
  };
}

export function parseNavigationPage(value: string): NavigationPage | null {
  if (value === 'Home' || value === 'DDL' || value === 'Schedule') return NavigationPage.Schedule;
  return defaultPageSettings().order.find(page => page === value) ?? null;
}

/** Consolidate the old Home/Schedule/DDL aliases while preserving relative order. */
export function migratePageSettings(input: LegacyPageSettings): PageSettings {
  const defaults = defaultPageSettings();
  const order: NavigationPage[] = [];
  for (const value of Array.isArray(input.order) ? input.order : []) {
    const page = parseNavigationPage(value);
    if (page !== null && !order.includes(page)) order.push(page);
  }
  for (const page of defaults.order) {
    if (!order.includes(page)) order.push(page);
  }
  const home = parseNavigationPage(input.home) ?? defaults.home;
  const hidden: NavigationPage[] = [];
  for (const value of Array.isArray(input.hidden) ? input.hidden : []) {
    const page = parseNavigationPage(value);
    if (page !== null && page !== home && page !== NavigationPage.Mine && !hidden.includes(page)) hidden.push(page);
  }
  return { order, hidden, home };
}

export function validatePageSettings(settings: PageSettings): void {
  const pages = defaultPageSettings().order;
  if (settings.order.length !== pages.length || new Set(settings.order).size !== pages.length ||
    settings.order.some(page => !pages.includes(page)) || !pages.includes(settings.home) ||
    settings.hidden.some(page => !pages.includes(page))) throw new Error('页面配置无效，请恢复默认后重试');
  if (settings.hidden.includes(settings.home)) throw new Error('主页不能被隐藏');
  if (settings.hidden.includes(NavigationPage.Mine)) throw new Error('“我的”页面不能被隐藏');
}

export function navigationTabIndex(page: NavigationPage): number {
  return defaultPageSettings().order.indexOf(page);
}

export function resolveStartupTab(home: NavigationPage, routeTab?: number): number {
  if (routeTab !== undefined && Number.isInteger(routeTab) && routeTab >= 0 && routeTab < 5) return routeTab;
  const index = navigationTabIndex(home);
  return index >= 0 ? index : 0;
}
