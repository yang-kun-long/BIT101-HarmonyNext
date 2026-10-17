import { DebugCase } from './DebugCase';
import { loadDebugCredentials } from './DebugCredentials';
import { createBitSsoSessionAuto } from '../services/lexue/BitSsoAuto';
import LexueCalendarClient from '../services/lexue/LexueCalendarClient';
import { parseLexueIcs, LexueCalendarEvent } from '../services/lexue/LexueCalendarParser';

const WEBVPN_LEXUE_BASE =
  'https://webvpn.bit.edu.cn/https/77726476706e69737468656265737421fcf25989227e6a596a468ca88d1b203b';

const ANDROID_DEFAULT_AFTER_DAY = 3;

interface DdlExtractionSample {
  uid: string;
  title: string;
  courseName: string;
  start: string;
  end: string;
  reason: string;
}

export class LexueDdlExtractionCase extends DebugCase {
  readonly name = 'Lexue DDL extraction parity diagnosis';

  async run(): Promise<void> {
    const { TEST_USERNAME, TEST_PASSWORD } = loadDebugCredentials();
    this.logInfo('START');

    if (!TEST_USERNAME || !TEST_PASSWORD) {
      this.fail('Missing TEST_USERNAME / TEST_PASSWORD in debug-credentials.json');
    }

    const sessionData = await createBitSsoSessionAuto({
      debug: true,
      webvpnLexueBase: WEBVPN_LEXUE_BASE,
    });
    const mode = sessionData.mode;
    const sso = sessionData.sso;
    const baseUrl = mode === 'inner' ? 'https://lexue.bit.edu.cn' : WEBVPN_LEXUE_BASE;

    this.logInfo('mode =', mode, 'baseUrl =', baseUrl);
    await sso.restoreFromStorage();
    this.logInfo('after restore isFullyLoggedIn =', sso.isFullyLoggedIn());

    if (!sso.isFullyLoggedIn()) {
      await sso.loginToLexue(TEST_USERNAME, TEST_PASSWORD);
      this.logInfo('after login isFullyLoggedIn =', sso.isFullyLoggedIn());
    }

    const client = new LexueCalendarClient(sso, {
      debug: true,
      baseUrl,
      username: TEST_USERNAME,
    });

    const result = await client.exportCalendar({
      what: 'all',
      time: 'recentupcoming',
    });

    this.logInfo('subscribeUrl =', this.maskSubscribeUrl(result.subscribeUrl));
    this.logInfo('icsLength =', result.icsText.length);
    this.logInfo('icsPreview =', this.previewIcs(result.icsText));

    const events = parseLexueIcs(result.icsText);
    const now = Date.now();
    const androidThreshold = now - ANDROID_DEFAULT_AFTER_DAY * 24 * 60 * 60 * 1000;

    let androidEquivalentCount = 0;
    let harmonyCurrentCount = 0;
    let futureTimeOnlyCount = 0;
    let parseMissingTitleCount = 0;
    let parseMissingCourseCount = 0;
    const filteredSamples: DdlExtractionSample[] = [];
    const androidSamples: DdlExtractionSample[] = [];

    for (const event of events) {
      const time = this.eventTime(event);
      const keywordMatch = this.matchesCurrentHarmonyKeyword(event);

      if (!event.title) {
        parseMissingTitleCount += 1;
      }
      if (!event.courseName) {
        parseMissingCourseCount += 1;
      }

      if (time >= androidThreshold) {
        androidEquivalentCount += 1;
        if (androidSamples.length < 5) {
          androidSamples.push(this.toSample(event, 'android-equivalent'));
        }
      }

      if (time >= now) {
        futureTimeOnlyCount += 1;
        if (keywordMatch) {
          harmonyCurrentCount += 1;
        } else if (filteredSamples.length < 8) {
          filteredSamples.push(this.toSample(event, 'future-but-no-keyword'));
        }
      }
    }

    this.logInfo(
      'counts',
      {
        parsedTotal: events.length,
        androidEquivalentAfterDay3: androidEquivalentCount,
        harmonyFutureTimeOnly: futureTimeOnlyCount,
        harmonyCurrentKeywordFiltered: harmonyCurrentCount,
        parseMissingTitle: parseMissingTitleCount,
        parseMissingCourse: parseMissingCourseCount,
      },
    );

    this.logInfo('androidEquivalentSamples =', androidSamples);
    this.logInfo('filteredByHarmonyKeywordSamples =', filteredSamples);

    this.logInfo(events.length === 0 ? 'CONCLUSION no VEVENT in exported ICS' : 'CONCLUSION events exported');

    this.logInfo('END');
  }

  private maskSubscribeUrl(url: string): string {
    return url.replace(/([?&]authtoken=)[^&]+/i, '$1***');
  }

  private previewIcs(icsText: string): string {
    return icsText.replace(/\s+/g, ' ').slice(0, 300);
  }

  private matchesCurrentHarmonyKeyword(event: LexueCalendarEvent): boolean {
    const text = `${event.title ?? ''}${event.description ?? ''}${event.location ?? ''}`;
    const lower = text.toLowerCase();
    return (
      text.includes('作业') ||
      text.includes('考试') ||
      text.includes('测验') ||
      text.includes('实验') ||
      lower.includes('assignment') ||
      lower.includes('homework') ||
      lower.includes('quiz') ||
      lower.includes('exam') ||
      lower.includes('ddl') ||
      lower.includes('deadline')
    );
  }

  private eventTime(event: LexueCalendarEvent): number {
    return event.endTime ?? event.startTime;
  }

  private toSample(event: LexueCalendarEvent, reason: string): DdlExtractionSample {
    return {
      uid: event.uid,
      title: event.title,
      courseName: event.courseName ?? '',
      start: new Date(event.startTime).toISOString(),
      end: event.endTime ? new Date(event.endTime).toISOString() : '',
      reason,
    };
  }
}
