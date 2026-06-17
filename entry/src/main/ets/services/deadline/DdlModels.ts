import type { LexueCalendarEvent } from '../lexue/LexueCalendarParser';

export type DdlSource = 'lexue' | 'manual';

export interface DdlItem {
  uid: string;
  source: DdlSource;
  title: string;
  courseName: string;
  startTime: number;
  endTime: number;
  description: string;
  location: string;
  done: boolean;
  updatedAt: number;
}

export interface ManualDdlInput {
  title: string;
  courseName: string;
  time: number;
  description: string;
  location: string;
  done?: boolean;
}

function textOrEmpty(value: string | undefined): string {
  return value ? value : '';
}

function endTimeOrStart(event: LexueCalendarEvent): number {
  if (event.endTime !== undefined && Number.isFinite(event.endTime)) {
    return event.endTime;
  }
  return event.startTime;
}

export function isDdlLikeLexueEvent(event: LexueCalendarEvent): boolean {
  const text = `${event.title ?? ''}${event.description ?? ''}${event.location ?? ''}`;
  const lower = text.toLowerCase();
  return text.includes('作业') ||
    text.includes('考试') ||
    text.includes('测验') ||
    text.includes('实验') ||
    lower.includes('assignment') ||
    lower.includes('homework') ||
    lower.includes('quiz') ||
    lower.includes('exam') ||
    lower.includes('ddl') ||
    lower.includes('deadline');
}

export function buildDdlItemFromLexueEvent(
  event: LexueCalendarEvent,
  done: boolean,
  updatedAt: number,
): DdlItem {
  return {
    uid: event.uid,
    source: 'lexue',
    title: textOrEmpty(event.title),
    courseName: textOrEmpty(event.courseName),
    startTime: event.startTime,
    endTime: endTimeOrStart(event),
    description: textOrEmpty(event.description),
    location: textOrEmpty(event.location),
    done,
    updatedAt,
  };
}

export function buildDdlItemFromManualInput(
  input: ManualDdlInput,
  uid: string,
  updatedAt: number,
): DdlItem {
  return {
    uid,
    source: 'manual',
    title: input.title.trim(),
    courseName: input.courseName.trim(),
    startTime: input.time,
    endTime: input.time,
    description: input.description.trim(),
    location: input.location.trim(),
    done: input.done === true,
    updatedAt,
  };
}

export function createManualDdlUid(updatedAt: number, sequence: number = 0): string {
  const safeUpdatedAt = Number.isFinite(updatedAt) ? Math.floor(updatedAt) : Date.now();
  const safeSequence = Number.isFinite(sequence) ? Math.max(0, Math.floor(sequence)) : 0;
  return `manual-${safeUpdatedAt}-${safeSequence}`;
}

export function mergeLexueEventsWithDdlItems(
  existingItems: DdlItem[],
  incomingEvents: LexueCalendarEvent[],
  updatedAt: number,
): DdlItem[] {
  const doneByUid: Record<string, boolean> = {};
  const merged: DdlItem[] = [];

  for (let i = 0; i < existingItems.length; i++) {
    const item = existingItems[i];
    if (item.source === 'manual') {
      merged.push(item);
    } else {
      doneByUid[item.uid] = item.done;
    }
  }

  for (let i = 0; i < incomingEvents.length; i++) {
    const event = incomingEvents[i];
    if (!isDdlLikeLexueEvent(event)) {
      continue;
    }
    const done = doneByUid[event.uid] === true;
    merged.push(buildDdlItemFromLexueEvent(event, done, updatedAt));
  }

  return sortDdlItemsByTime(merged);
}

export function sortDdlItemsByTime(items: DdlItem[]): DdlItem[] {
  const out: DdlItem[] = [];
  for (let i = 0; i < items.length; i++) {
    out.push(items[i]);
  }
  out.sort((a: DdlItem, b: DdlItem): number => {
    const at = a.startTime;
    const bt = b.startTime;
    if (at !== bt) return at - bt;
    return a.uid.localeCompare(b.uid);
  });
  return out;
}

export function listVisibleDdlItems(items: DdlItem[], nowMs: number, retentionDays?: number): DdlItem[] {
  const visible: DdlItem[] = [];
  const normalizedRetentionDays: number = retentionDays === undefined ? 0 : retentionDays;
  const retentionMs: number = Math.max(0, Math.floor(normalizedRetentionDays)) * 24 * 60 * 60 * 1000;
  const earliestVisibleDeadline: number = nowMs - retentionMs;
  for (let i = 0; i < items.length; i++) {
    const item = items[i];
    const deadline = item.startTime;
    if (deadline > earliestVisibleDeadline) {
      visible.push(item);
    }
  }
  return sortDdlItemsByTime(visible);
}

export function computeDdlRemainRatio(deadlineMs: number, nowMs: number, warningDays: number): number {
  const warningMs: number = Math.max(0, Math.floor(warningDays)) * 24 * 60 * 60 * 1000;
  const diff: number = deadlineMs - nowMs;
  if (diff <= 0) {
    return 0;
  }
  if (warningMs <= 0 || diff >= warningMs) {
    return 1;
  }
  return diff / warningMs;
}

export function formatDdlRemainText(deadlineMs: number, nowMs: number): string {
  let diffMinutes: number = Math.trunc((deadlineMs - nowMs) / (60 * 1000));
  let prefix = '剩余 ';
  if (diffMinutes < 0) {
    prefix = '已过 ';
    diffMinutes = Math.abs(diffMinutes);
  }

  const day: number = Math.trunc(diffMinutes / 1440);
  const hour: number = Math.trunc((diffMinutes % 1440) / 60);
  const minute: number = diffMinutes % 60;
  if (day > 0) {
    return `${prefix}${day}天 ${hour}小时 ${minute}分钟`;
  }
  if (hour > 0) {
    return `${prefix}${hour}小时 ${minute}分钟`;
  }
  return `${prefix}${minute}分钟`;
}

function cloneDdlItem(item: DdlItem): DdlItem {
  return {
    uid: item.uid,
    source: item.source,
    title: item.title,
    courseName: item.courseName,
    startTime: item.startTime,
    endTime: item.endTime,
    description: item.description,
    location: item.location,
    done: item.done,
    updatedAt: item.updatedAt,
  };
}

export function toggleDdlDone(
  items: DdlItem[],
  uid: string,
  done: boolean,
  updatedAt: number,
): DdlItem[] {
  const out: DdlItem[] = [];
  for (let i = 0; i < items.length; i++) {
    const item = cloneDdlItem(items[i]);
    if (item.uid === uid) {
      item.done = done;
      item.updatedAt = updatedAt;
    }
    out.push(item);
  }
  return sortDdlItemsByTime(out);
}

export function deleteDdlItem(items: DdlItem[], uid: string): DdlItem[] {
  const out: DdlItem[] = [];
  for (let i = 0; i < items.length; i++) {
    if (items[i].uid !== uid) {
      out.push(cloneDdlItem(items[i]));
    }
  }
  return sortDdlItemsByTime(out);
}

export function upsertManualDdlItem(
  items: DdlItem[],
  input: ManualDdlInput,
  uid: string,
  updatedAt: number,
): DdlItem[] {
  const out: DdlItem[] = [];
  let replaced = false;
  for (let i = 0; i < items.length; i++) {
    if (items[i].uid === uid) {
      const nextInput: ManualDdlInput = {
        title: input.title,
        courseName: input.courseName,
        time: input.time,
        description: input.description,
        location: input.location,
        done: input.done === undefined ? items[i].done : input.done,
      };
      out.push(buildDdlItemFromManualInput(nextInput, uid, updatedAt));
      replaced = true;
    } else {
      out.push(cloneDdlItem(items[i]));
    }
  }
  if (!replaced) {
    out.push(buildDdlItemFromManualInput(input, uid, updatedAt));
  }
  return sortDdlItemsByTime(out);
}

function normalizeParsedDdlItem(item: DdlItem): DdlItem | null {
  if (!item || !item.uid || (item.source !== 'lexue' && item.source !== 'manual')) {
    return null;
  }
  if (!Number.isFinite(item.startTime) || !Number.isFinite(item.endTime)) {
    return null;
  }
  return {
    uid: String(item.uid),
    source: item.source,
    title: textOrEmpty(item.title),
    courseName: textOrEmpty(item.courseName),
    startTime: Number(item.startTime),
    endTime: Number(item.endTime),
    description: textOrEmpty(item.description),
    location: textOrEmpty(item.location),
    done: item.done === true,
    updatedAt: Number.isFinite(item.updatedAt) ? Number(item.updatedAt) : 0,
  };
}

export function parseDdlItemsJson(raw: string): DdlItem[] {
  if (!raw || raw.length === 0) {
    return [];
  }
  try {
    const parsed = JSON.parse(raw) as DdlItem[];
    if (!Array.isArray(parsed)) {
      return [];
    }
    const out: DdlItem[] = [];
    for (let i = 0; i < parsed.length; i++) {
      const item = normalizeParsedDdlItem(parsed[i]);
      if (item) {
        out.push(item);
      }
    }
    return sortDdlItemsByTime(out);
  } catch (e) {
    return [];
  }
}
