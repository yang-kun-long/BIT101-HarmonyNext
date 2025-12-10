export enum PageShowOnNav {
  Home = "Home",       // 对应 TabKey.Schedule (卷/首页)
  Schedule = "Schedule", // 对应 TabKey.Schedule (作为备选)
  DDL = "DDL",         // 对应 TabKey.Schedule (作为备选)

  Map = "Map",         // 对应 TabKey.Map (图) --- 之前漏了这个！
  Forum = "Forum",     // 对应 TabKey.Forum (网)
  Post = "Post",       // 对应 TabKey.Post (话) --- 之前漏了这个！
  Mine = "Mine"        // 对应 TabKey.Me (我)
}

export function getPageName(page: PageShowOnNav): string {
  switch (page) {
    case PageShowOnNav.Home: return "首页";
    case PageShowOnNav.Schedule: return "课表";
    case PageShowOnNav.DDL: return "DDL";

    case PageShowOnNav.Map: return "地图"; // 必须有
    case PageShowOnNav.Forum: return "论坛";
    case PageShowOnNav.Post: return "发帖"; // 必须有
    case PageShowOnNav.Mine: return "我的";
    default: return "未知";
  }
}