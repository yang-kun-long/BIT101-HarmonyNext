// entry/src/main/ets/utils/Logger.ts.
import hilog from '@ohos.hilog';

// 定义日志模式类型
type LogFilterMode = 'BLOCK_LIST' | 'ALLOW_LIST';

export class Logger {
  // ===================== 核心配置区域 =====================

  private static readonly DOMAIN: number = 0x0101;
  private static readonly ROOT_TAG: string = 'BIT101';

  /** 全局总开关：false 则彻底关闭所有日志 */
  private static IS_DEBUG: boolean = true;

  /** * 过滤模式：
   * - 'BLOCK_LIST' (黑名单): 默认打印所有，**屏蔽** LIST 中的模块 (适合日常开发，屏蔽刷屏的)
   * - 'ALLOW_LIST' (白名单): 默认不打印，**只看** LIST 中的模块 (适合专注调试某几个功能)
   */
  private static readonly FILTER_MODE: LogFilterMode = 'ALLOW_LIST';

  /**
   * 模块列表
   * 将你想 屏蔽(黑名单时) 或 关注(白名单时) 的模块名填入这里
   */
  private static readonly TARGET_MODULES: string[] = [
    'WebPage',
    'PosterRepository',
    'PosterCard',
    'GalleryService',  // 查看 uploadImage 和 postPoster 的日志 (关键)
    'PostEditorPage',  // 查看页面层的数据收集和报错
    'RcpSession',      // 查看网络请求的底层日志 (针对 postPoster)
    'ReactionService', // 查看评论发送日志
    'PosterDetailPage',
    'DebugCase'
    // --- 可以在这里填入下方 ALL_MODULES 里的名字 ---
    // 'ScheduleGrid',
    // 'SchedulePage',
    // 'RcpSession',
  ];

  // =======================================================

  // 📝 备忘录：项目中已注册的所有模块名称
  public static readonly ALL_MODULES = {
    // [App & Ability]
    EntryAbility: 'EntryAbility',
    AppEnv: 'AppEnv',

    // [Pages - 页面]
    Index: 'Index',
    LoginPage: 'LoginPage',
    SchedulePage: 'SchedulePage',
    ScheduleShellPage: 'ScheduleShellPage',
    PostPage: 'PostPage',
    PostEditorPage: 'PostEditorPage',
    PosterDetailPage: 'PosterDetailPage',

    // [Components - 组件]
    ScheduleGrid: 'ScheduleGrid',
    CourseDetailDialog: 'CourseDetailDialog',
    DdlList: 'DdlList',
    DdlDetailDialog: 'DdlDetailDialog',
    MapCanvas: 'MapCanvas',
    AvatarWithVerified: 'AvatarWithVerified',
    LinkableText: 'LinkableText',
    WebPage: 'WebPage',

    // [Network & Auth - 网络与认证]
    RcpSession: 'RcpSession',
    Bit101Auth: 'Bit101Auth',
    BitSsoSession: 'BitSsoSession',
    BitSsoWebvpn: 'BitSsoWebvpn',
    BitSsoAuto: 'BitSsoAuto',
    EncryptPassword: 'EncryptPassword',

    // [Services - 业务服务]
    CalendarService: 'CalendarService',
    GalleryService: 'GalleryService',
    PosterRepository: 'PosterRepository',
    ReactionService: 'ReactionService',
    PosterListState: 'PosterListState',
    LexueCalendarClient: 'LexueCalendarClient',
    Timetable: 'Timetable',

    // [Storage - 本地存储]
    SemesterStore: 'SemesterStore',
    PeriodTimesStore: 'PeriodTimesStore',
    LexueCookieStore: 'LexueCookieStore',
    LexueCalendarStore: 'LexueCalendarStore',
    // TokenStore: 'TokenStore', // (如果 TokenStore 也改了的话)

    // [Debug - 调试]
    DebugCase: 'DebugCase',
  };

  // ================= 逻辑实现区域 (无需修改) =================

  private moduleName: string;

  constructor(moduleName: string) {
    this.moduleName = moduleName;
  }

  private shouldLog(): boolean {
    // 1. 总开关
    if (!Logger.IS_DEBUG) return false;

    // 2. 判断是否在列表中
    const isInList = Logger.TARGET_MODULES.includes(this.moduleName);

    if (Logger.FILTER_MODE === 'BLOCK_LIST') {
      // 黑名单模式：在列表里 -> 不打印；不在列表里 -> 打印
      return !isInList;
    } else {
      // 白名单模式：在列表里 -> 打印；不在列表里 -> 不打印
      return isInList;
    }
  }

  debug(...args: any[]) {
    if (!this.shouldLog()) return;
    hilog.debug(Logger.DOMAIN, this.getFullTag(), this.formatLog(args));
  }

  info(...args: any[]) {
    if (!this.shouldLog()) return;
    hilog.info(Logger.DOMAIN, this.getFullTag(), this.formatLog(args));
  }

  warn(...args: any[]) {
    if (!this.shouldLog()) return;
    hilog.warn(Logger.DOMAIN, this.getFullTag(), this.formatLog(args));
  }

  error(...args: any[]) {
    // Error 级别通常建议始终打印，方便发现 Bug
    // 如果你也想屏蔽 Error，就加上: if (!this.shouldLog()) return;
    if (!Logger.IS_DEBUG) return;
    hilog.error(Logger.DOMAIN, this.getFullTag(), this.formatLog(args));
  }

  fatal(...args: any[]) {
    if (!Logger.IS_DEBUG) return;
    hilog.fatal(Logger.DOMAIN, this.getFullTag(), this.formatLog(args));
  }

  private getFullTag(): string {
    return `${Logger.ROOT_TAG}_${this.moduleName}`;
  }

  private formatLog(args: any[]): string {
    return args.map(arg => {
      if (arg === null) return 'null';
      if (arg === undefined) return 'undefined';
      if (arg instanceof Error) return `Error: ${arg.message}\nStack: ${arg.stack}`;
      if (typeof arg === 'object') {
        try { return JSON.stringify(arg); } catch (e) { return String(arg); }
      }
      return String(arg);
    }).join(' ');
  }
}