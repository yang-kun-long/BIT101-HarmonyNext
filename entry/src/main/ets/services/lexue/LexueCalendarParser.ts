// entry/src/main/ets/services/lexue/LexueCalendarParser.ts

export interface LexueCalendarEvent {
  uid: string;
  title: string;
  startTime: number;
  endTime?: number;
  description?: string;
  location?: string;
  courseName?: string;     // ← 新增：课程名
  raw?: Record<string, string>;
}


function unfoldIcsLines(ics: string): string[] {
  const lines = ics.split(/\r?\n/);
  const result: string[] = [];
  for (const line of lines) {
    if (!line) continue;
    // 以空格或 tab 开头的是上一行的延续（ICS 折行规则）
    if ((line.startsWith(' ') || line.startsWith('\t')) && result.length > 0) {
      result[result.length - 1] += line.slice(1);
    } else {
      result.push(line);
    }
  }
  return result;
}

function parseIcsDateTime(value: string): number | undefined {
  // 支持：
  //  - 20250301T083000Z
  //  - 20250301T083000
  //  - 20250301（全天）
  const m = value.match(
    /^(\d{4})(\d{2})(\d{2})(T(\d{2})(\d{2})(\d{2})(Z)?)?$/,
  );
  if (!m) return undefined;

  const year = parseInt(m[1], 10);
  const month = parseInt(m[2], 10) - 1;
  const day = parseInt(m[3], 10);
  const hasTime = !!m[4];
  const hour = hasTime ? parseInt(m[5], 10) : 0;
  const minute = hasTime ? parseInt(m[6], 10) : 0;
  const second = hasTime ? parseInt(m[7], 10) : 0;
  const isUtc = m[8] === 'Z';

  if (isUtc) {
    return Date.UTC(year, month, day, hour, minute, second);
  }
  // 当成本地时间（设备一般是 Asia/Shanghai）
  return new Date(year, month, day, hour, minute, second).getTime();
}

export function parseLexueIcs(icsText: string): LexueCalendarEvent[] {
  const lines = unfoldIcsLines(icsText);
  const events: LexueCalendarEvent[] = [];

  let inEvent = false;
  let current: Record<string, string> = {};

  for (const line of lines) {
    if (line === 'BEGIN:VEVENT') {
      inEvent = true;
      current = {};
      continue;
    }
    if (line === 'END:VEVENT') {
      if (inEvent) {
        const uid = current['UID'] ?? '';
        const title = current['SUMMARY'] ?? '';
        const startRaw = current['DTSTART'];
        const endRaw = current['DTEND'];

        const startTime = startRaw ? parseIcsDateTime(startRaw) : undefined;
        const endTime = endRaw ? parseIcsDateTime(endRaw) : undefined;

        if (uid && startTime != null) {
          events.push({
            uid,
            title,
            startTime,
            endTime,
            description: current['DESCRIPTION'],
            location: current['LOCATION'],
            courseName: current['CATEGORIES'],   // ★★★
            raw: current,
          });
        }
      }
      inEvent = false;
      current = {};
      continue;
    }

    if (!inEvent) continue;

    // 解析类似：KEY;PARAM=xx;PARAM=yy:VALUE
    const colonIdx = line.indexOf(':');
    if (colonIdx <= 0) continue;

    const keyPart = line.slice(0, colonIdx);
    const valuePart = line.slice(colonIdx + 1);

    const semicolonIdx = keyPart.indexOf(';');
    const key = (semicolonIdx >= 0 ? keyPart.slice(0, semicolonIdx) : keyPart).toUpperCase();

    // 对于 DTSTART;TZID=... 这种，把纯时间部分作为值存进去
    if (key === 'DTSTART' || key === 'DTEND') {
      current[key] = valuePart.trim();
    } else {
      current[key] = valuePart.trim();
    }
  }

  return events;
}
