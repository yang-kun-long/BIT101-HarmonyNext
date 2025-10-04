import { TimetableRepository, CalendarEvent } from './timetableRepository'
import { SemesterStore, SemesterSnapshot, CourseInstance, FilesCtx } from '../storage/semesterStore'
import { eventsToInstances, ToInstancesDeps } from './normalize'

/** 你可以按业务自己定义学期ID，如 "2025-fall" 或从教务接口拿 */
export interface SemesterId {
  id: string;         // "2025-fall"
  startISO?: string;  // 可选
  endISO?: string;    // 可选
}

export interface SemesterLoadResult {
  fromCache: boolean;
  semester: SemesterSnapshot;
}

export class SemesterRepository {
  private readonly repo: TimetableRepository;
  private readonly store: SemesterStore;
  private readonly deps: ToInstancesDeps;

  constructor(repo: TimetableRepository, filesCtx: FilesCtx, deps: ToInstancesDeps) {
    this.repo = repo;
    this.store = new SemesterStore(filesCtx);
    this.deps = deps;
  }

  /** 读取整学期（优先本地；forceRefresh 时强制打后端） */
  async getSemester(sem: SemesterId, forceRefresh: boolean = false): Promise<SemesterLoadResult> {
    if (!forceRefresh) {
      const cached = await this.store.loadSemester(sem.id);
      if (cached) {
        return { fromCache: true, semester: cached };
      }
    }

    // 拉后端：TimetableRepository.getScheduleEvents() 当前一般返回全学期的 .ics 事件
    const ret = await this.repo.getScheduleEvents();
    const events: CalendarEvent[] = ret.events;

    const instances: CourseInstance[] = eventsToInstances(events, this.deps);

    const snapshot: SemesterSnapshot = {
      semesterId: sem.id,
      startISO: sem.startISO ? sem.startISO : (instances.length > 0 ? instances[0].dateISO : ''),
      endISO: sem.endISO ? sem.endISO : (instances.length > 0 ? instances[instances.length - 1].dateISO : ''),
      updatedAt: Date.now(),
      version: 1,
      instances: instances
    };

    await this.store.saveSemester(snapshot);
    return { fromCache: false, semester: snapshot };
  }

  /** 提供“按周筛选”的便捷函数，喂给 UI 即可 */
  filterWeekInstances(snapshot: SemesterSnapshot, weekStartISO: string): CourseInstance[] {
    const out: CourseInstance[] = [];
    for (let i = 0; i < snapshot.instances.length; i++) {
      const it = snapshot.instances[i];
      if (it.weekStartISO === weekStartISO) out.push(it);
    }
    // 已按日期+节次排序，通常无需再排；如需，再按 startPeriod 做次排序
    return out;
  }
}
