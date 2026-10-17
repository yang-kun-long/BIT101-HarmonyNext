import { initializeGallerySettings } from '../services/storage/GallerySettingsStore';
import { initializeCredentialStore } from '../services/storage/CredentialStorePlatform';
import { initializeAutomaticLogin } from '../services/auth/AutomaticLogin';
import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { Logger } from '../utils/Logger';

import { initTokenStore } from '../services/storage/tokenStore'
import { initLexueCookieStore } from '../services/storage/LexueCookieStore';
import { initSchoolCookieStore } from '../services/storage/SchoolCookieStore';
import { initLexueCalendarStore } from '../services/storage/LexueCalendarStore';
import { initDdlStore } from '../services/storage/DdlStore';
import {
  applyDdlDisplaySettingsToAppStorage,
  DEFAULT_DDL_DISPLAY_SETTINGS,
  DDL_APP_RETENTION_DAYS,
  DDL_APP_WARNING_DAYS,
  DdlSettingsStore,
  initDdlSettingsStore,
} from '../services/storage/DdlSettingsStore';
import {
  DEFAULT_FREE_CLASSROOM_SETTINGS,
  FREE_CLASSROOM_APP_CAMPUS_CODE,
  FREE_CLASSROOM_APP_CAMPUS_NAME,
  FREE_CLASSROOM_APP_FREE_THRESHOLD,
  FREE_CLASSROOM_APP_HIDE_BUSY,
  initFreeClassroomSettingsStore,
} from '../services/storage/FreeClassroomSettingsStore';
import {
  applyCourseScheduleSettingsToAppStorage,
  CourseScheduleSettingsStore,
  initCourseScheduleSettingsStore,
} from '../services/storage/CourseScheduleSettingsStore';
import { DEFAULT_SCHEDULE_DISPLAY_SETTINGS } from '../services/schoolSchedule/ScheduleSettingsModels';
import { initSystemCalendarService } from '../services/systemCalendar/SystemCalendarService';
// 确保路径正确，如果在 pages 下就是 '../pages/PageEnum'
import { LegacyPageSettings, migratePageSettings } from '../services/settings/PageSettingsModel';
import { applyPageSettings, createPageSettingsStore } from '../services/storage/PageSettingsStore';
import { initializeWindowTheme, releaseWindowTheme } from '../services/settings/WindowThemeTarget';

export default class EntryAbility extends UIAbility {
  private logger = new Logger('EntryAbility');

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    const isDebugBuild = this.context.applicationInfo.debug;
    Logger.configure(isDebugBuild);
    this.logger.info('Ability onCreate');

    AppStorage.setOrCreate('filesDir', this.context.filesDir);
    AppStorage.setOrCreate('cacheDir', this.context.cacheDir);
    AppStorage.setOrCreate('tempDir',  this.context.tempDir);

    initTokenStore(this.context);
    initializeCredentialStore(this.context);
    initializeAutomaticLogin(this.context);
    initLexueCookieStore(this.context);
    initSchoolCookieStore(this.context);
    initLexueCalendarStore(this.context);
    initDdlStore(this.context);
    initDdlSettingsStore(this.context);
    initFreeClassroomSettingsStore(this.context);
    initCourseScheduleSettingsStore(this.context);
    initSystemCalendarService(this.context);
    this.bootstrapDdlSettings();
    this.bootstrapCourseScheduleSettings();

    this.startDebugRunner(isDebugBuild);

    try {
      this.context.getApplicationContext()
        .setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      this.logger.error('Failed to set colorMode. Cause:', err);
    }
  }

  private bootstrapDdlSettings(): void {
    AppStorage.setOrCreate(DDL_APP_WARNING_DAYS, DEFAULT_DDL_DISPLAY_SETTINGS.warningDays);
    AppStorage.setOrCreate(DDL_APP_RETENTION_DAYS, DEFAULT_DDL_DISPLAY_SETTINGS.retentionDays);

    const store = new DdlSettingsStore();
    store.load()
      .then((settings) => {
        applyDdlDisplaySettingsToAppStorage(settings);
      })
      .catch((error: Error) => {
        this.logger.error('Failed to load DDL settings. Cause:', error);
      });
  }

  private startDebugRunner(isDebugBuild: boolean): void {
    if (!isDebugBuild) {
      return;
    }

    import('../debug/DebugRunner')
      .then((runner): Promise<void> => runner.runCurrentDebugCase(isDebugBuild))
      .catch((error: Error) => {
        this.logger.error('Debug runner failed. Cause:', error);
      });
  }

  private bootstrapCourseScheduleSettings(): void {
    applyCourseScheduleSettingsToAppStorage(DEFAULT_SCHEDULE_DISPLAY_SETTINGS);

    const store = new CourseScheduleSettingsStore();
    store.load()
      .then((settings) => {
        applyCourseScheduleSettingsToAppStorage(settings);
      })
      .catch((error: Error) => {
        this.logger.error('Failed to load course schedule settings. Cause:', error);
      });
  }

  onDestroy(): void {
    this.logger.info('Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    this.logger.info('Ability onWindowStageCreate');

    this.loadInitialContent(windowStage);
  }

  private async loadInitialContent(windowStage: window.WindowStage): Promise<void> {
    await this.initPersistentStorage();
    try { await initializeGallerySettings(this.context); }
    catch (error) { this.logger.error('Failed to load gallery settings', error); }
    try {
      await initializeWindowTheme(this.context, windowStage.getMainWindowSync());
    } catch (error) {
      this.logger.error('Failed to initialize window theme. Cause:', error);
    }
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        this.logger.error('Failed to load the content. Cause:', err);
        return;
      }
      this.logger.info('Succeeded in loading the content.');
    });
  }

  private async initPersistentStorage(): Promise<void> {
    // Read old values before detaching their legacy persistence bindings.
    PersistentStorage.persistProp('pages_order', ['Home', 'Map', 'Forum', 'Post', 'Mine']);
    PersistentStorage.persistProp('pages_hidden', []);
    PersistentStorage.persistProp('home_page', 'Home');
    const legacy: LegacyPageSettings = {
      order: AppStorage.get<string[]>('pages_order') ?? [],
      hidden: AppStorage.get<string[]>('pages_hidden') ?? [],
      home: AppStorage.get<string>('home_page') ?? 'Home',
    };
    try {
      const settings = await createPageSettingsStore(this.context).load(legacy);
      PersistentStorage.deleteProp('pages_order');
      PersistentStorage.deleteProp('pages_hidden');
      PersistentStorage.deleteProp('home_page');
      applyPageSettings(settings);
    } catch (error) {
      this.logger.error('Failed to load page settings. Cause:', error);
      applyPageSettings(migratePageSettings(legacy));
    }
    AppStorage.setOrCreate(FREE_CLASSROOM_APP_CAMPUS_CODE, DEFAULT_FREE_CLASSROOM_SETTINGS.currentCampusCode);
    AppStorage.setOrCreate(FREE_CLASSROOM_APP_CAMPUS_NAME, DEFAULT_FREE_CLASSROOM_SETTINGS.currentCampusName);
    AppStorage.setOrCreate(FREE_CLASSROOM_APP_HIDE_BUSY, DEFAULT_FREE_CLASSROOM_SETTINGS.hideBusyClassroom);
    AppStorage.setOrCreate(FREE_CLASSROOM_APP_FREE_THRESHOLD, DEFAULT_FREE_CLASSROOM_SETTINGS.freeMinutesThreshold);
  }

  onWindowStageDestroy(): void {
    releaseWindowTheme();
    this.logger.info('Ability onWindowStageDestroy');
  }

  onForeground(): void {
    this.logger.info('Ability onForeground');
  }

  onBackground(): void {
    this.logger.info('Ability onBackground');
  }
}
