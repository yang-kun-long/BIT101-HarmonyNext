# Course Schedule Android Parity Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Bring the HarmonyOS course schedule domain to Android parity: real schedule settings, term/course/exam sync, exam overlay, custom schedule CRUD, and schedule UI behavior controlled by persisted settings.

**Architecture:** Keep HarmonyOS' existing school-auth and WebVPN stack; do not copy Android login plumbing. Add a lightweight local schedule domain under `services/schoolSchedule` that plays the same role as Android `CoursesRepo + Room + CourseScheduleSettings`, backed by JSON files and `preferences` instead of Room/DataStore.

**Tech Stack:** ArkTS, ArkUI, `@ohos.data.preferences`, `@ohos.file.fs`, existing BIT101 backend `TimetableRepository`, existing school-auth services, Hypium local tests, DevEco/hvigor build, optional DevEco MCP integration logs.

---

## Current Baseline

Android reference files:
- `BIT101-Android/features/setting/src/main/java/cn/bit101/android/features/setting/page/CalendarSettingPage.kt`
- `BIT101-Android/features/setting/src/main/java/cn/bit101/android/features/setting/viewmodel/CalendarViewModel.kt`
- `BIT101-Android/features/schedule/src/main/java/cn/bit101/android/features/schedule/course/CourseSchedule.kt`
- `BIT101-Android/features/schedule/src/main/java/cn/bit101/android/features/schedule/course/CourseScheduleViewModel.kt`
- `BIT101-Android/data/src/main/java/cn/bit101/android/data/repo/DefaultCoursesRepo.kt`
- `BIT101-Android/data/src/main/java/cn/bit101/android/data/database/entity/CourseScheduleEntity.kt`
- `BIT101-Android/data/src/main/java/cn/bit101/android/data/database/entity/ExamScheduleEntity.kt`
- `BIT101-Android/data/src/main/java/cn/bit101/android/data/database/entity/CustomScheduleEntity.kt`

HarmonyOS files to integrate:
- `entry/src/main/ets/pages/SchedulePage.ets`
- `entry/src/main/ets/pages/ScheduleShellPage.ets`
- `entry/src/main/ets/pages/settings/CalendarSettingPage.ets`
- `entry/src/main/ets/services/jw/timetableRepository.ts`
- `entry/src/main/ets/services/jw/semesterRepository.ts`
- `entry/src/main/ets/services/storage/semesterStore.ts`
- `entry/src/main/ets/services/jw/periodTimesStore.ts`
- `entry/src/main/ets/components/schedule/ScheduleGrid.ets`
- `entry/src/main/ets/components/schedule/ScheduleHeaderRow.ets`
- `entry/src/main/ets/components/schedule/ScheduleSidebar.ets`
- `entry/src/test/List.test.ets`

## Scope

Port these Android course-schedule behaviors:
- `CalendarSettingPage`: current term, first day, course refresh, exam refresh, timetable edit, custom schedule list, display switches.
- `CourseSchedule`: persisted settings control weekends, border, today highlight, divider, current time line, exam visibility.
- Data repo: local courses, local exams, custom schedules, term and first day settings.
- UI: settings gear opens calendar settings, add custom schedule button, course/exam/custom detail dialogs, exam/custom overlays on the same timetable grid.

Defer or separately track:
- Adding exams/custom schedules to the system calendar. HarmonyOS calendar permission/API needs a separate device-backed spike.
- Replacing the existing BIT101 backend `/courses/schedule` ICS path if school JXZX APIs are unavailable through current auth. First implementation can normalize ICS into the new local course model, then add native school API endpoints as a second source.

## Data Model

Create `entry/src/main/ets/services/schoolSchedule/ScheduleModels.ts`.

Use millisecond timestamps and `YYYY-MM-DD` / `HH:mm` strings to avoid Java/Kotlin date API assumptions:

```ts
export interface CourseScheduleItem {
  id: string;
  term: string;
  name: string;
  teacher: string;
  classroom: string;
  description: string;
  weeks: string;
  weekday: number;
  startSection: number;
  endSection: number;
  campus: string;
  number: string;
  credit: number;
  hour: number;
  type: string;
  category: string;
  department: string;
  rawUid?: string;
}

export interface ExamScheduleItem {
  id: string;
  term: string;
  name: string;
  courseId: string;
  teacher: string;
  classroom: string;
  dateISO: string;
  beginTime: string;
  endTime: string;
  examMode: string;
  seatId: string;
}

export interface CustomScheduleItem {
  id: string;
  title: string;
  subtitle: string;
  description: string;
  dateISO: string;
  beginTime: string;
  endTime: string;
  updatedAt: number;
}

export interface ScheduleDisplaySettings {
  currentTerm: string;
  firstDayISO: string;
  showSaturday: boolean;
  showSunday: boolean;
  showBorder: boolean;
  showHighlightToday: boolean;
  showDivider: boolean;
  showCurrentTime: boolean;
  showExamInfo: boolean;
  periodTimes: PeriodTime[];
}
```

Storage layout:
- `preferences` file `course_schedule_settings`: term, first day, display switches.
- Existing file `period_times.json`: keep as canonical for timetable because `FreeClassroomPage` already depends on it.
- JSON root `<filesDir>/bit101/school_schedule/`:
  - `courses.json`
  - `exams.json`
  - `custom_schedules.json`

## Tasks

### Task 1: Schedule Settings Pure Helpers

**Files:**
- Create: `entry/src/main/ets/services/schoolSchedule/ScheduleSettingsModels.ts`
- Create: `entry/src/test/CourseScheduleSettings.test.ets`
- Modify: `entry/src/test/List.test.ets`

**Step 1: Write failing tests**

Test:
- Android timetable text `08:00,08:45` parses.
- Existing HarmonyOS placeholder text `08:00-08:45` parses.
- Overlapping or reversed periods reject.
- Normalized settings fill default 13 periods.

Run:

```powershell
$env:DEVECO_SDK_HOME='D:\Software\Huawei\DevEco Studio\sdk'
$env:OHOS_SDK_HOME='D:\Software\Huawei\DevEco Studio\sdk\default\openharmony'
& 'D:\Software\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' test --no-daemon
```

Expected before implementation: compiler error or failing tests for missing helper.

**Step 2: Implement helpers**

Implement:
- `parsePeriodTimesText(text: string): PeriodTime[]`
- `periodTimesToText(periodTimes: PeriodTime[]): string`
- `normalizeScheduleDisplaySettings(settings: Partial<ScheduleDisplaySettings>): ScheduleDisplaySettings`

Rules:
- Accept comma and hyphen separators.
- Require `HH:mm` and strictly increasing non-overlapping periods.
- Return empty array on invalid parse; normalizer falls back to `getDefaultPeriodTimes()`.

**Step 3: Verify green**

Run the same `hvigorw test` command. Expected: new tests pass.

**Step 4: Commit**

```powershell
git add entry/src/main/ets/services/schoolSchedule/ScheduleSettingsModels.ts entry/src/test/CourseScheduleSettings.test.ets entry/src/test/List.test.ets
git commit -m "feat(schedule): add course schedule settings model"
```

### Task 2: Persisted Settings Store

**Files:**
- Create: `entry/src/main/ets/services/storage/CourseScheduleSettingsStore.ts`
- Modify: `entry/src/main/ets/entryability/EntryAbility.ets`
- Test: `entry/src/test/CourseScheduleSettings.test.ets`

**Step 1: Write failing tests**

Add pure tests for key names and normalizer only; do not unit test `preferences` without ability context.

Expected app storage keys:
- `course_schedule_current_term`
- `course_schedule_first_day_iso`
- `course_schedule_show_saturday`
- `course_schedule_show_sunday`
- `course_schedule_show_border`
- `course_schedule_show_highlight_today`
- `course_schedule_show_divider`
- `course_schedule_show_current_time`
- `course_schedule_show_exam_info`

**Step 2: Implement store**

Mirror existing `DdlSettingsStore` pattern:
- static `setAbilityContext(ctx: any)`
- `load(): Promise<ScheduleDisplaySettings>`
- `save(settings: ScheduleDisplaySettings): Promise<void>`
- individual save methods for each switch and term/first day.
- `applyCourseScheduleSettingsToAppStorage(settings)`.
- `initCourseScheduleSettingsStore(ctx)`.

`load()` must also load period times from `PeriodTimesStore` when `filesDir` is present.

**Step 3: Bootstrap**

In `EntryAbility.ets`:
- call `initCourseScheduleSettingsStore(this.context)`
- add `bootstrapCourseScheduleSettings()`
- set default AppStorage values before async load.

**Step 4: Verify**

Run `hvigorw test --no-daemon`, then `assembleHap` if tests compile.

### Task 3: Local Schedule Store

**Files:**
- Create: `entry/src/main/ets/services/schoolSchedule/ScheduleLocalStore.ts`
- Create: `entry/src/test/CourseScheduleLocalStore.test.ets`
- Modify: `entry/src/test/List.test.ets`

**Step 1: Write pure tests**

Extract pure JSON parse/merge helpers so tests do not need filesystem:
- `parseCourseScheduleJson`
- `parseExamScheduleJson`
- `parseCustomScheduleJson`
- `upsertCustomSchedule`
- `deleteCustomSchedule`

Test malformed JSON returns `[]`, custom upsert preserves id when editing, delete removes only target id.

**Step 2: Implement file store**

Use `@ohos.file.fs` like `SemesterStore`:
- root `<filesDir>/bit101/school_schedule`
- atomic-ish write via open/truncate/write/fsync/close
- `loadCourses/saveCourses`
- `loadExams/saveExams`
- `loadCustomSchedules/saveCustomSchedules`

**Step 3: Verify**

Run local tests.

### Task 4: Course Data Repository

**Files:**
- Create: `entry/src/main/ets/services/schoolSchedule/CourseScheduleRepository.ts`
- Modify: `entry/src/main/ets/services/jw/semesterRepository.ts` only if normalization reuse is needed.
- Test: `entry/src/test/CourseScheduleRepository.test.ets`

**Step 1: Test repository helpers**

Test:
- current week from `firstDayISO`.
- filter courses by `[week]` string.
- convert exams/custom schedule clock times to fractional sections using current `PeriodTime[]`.
- merge course, exam, custom items into day arrays without overlap.

**Step 2: Implement repository**

Initial source strategy:
- Courses: reuse current `TimetableRepository.getScheduleEvents()` + current normalization to build `CourseScheduleItem[]`.
- Exams: add API path only after confirming available endpoint. If endpoint unavailable, keep `refreshExams()` returning a clear `NotImplemented` error and UI toast "考试安排接口暂不可用".
- Custom schedules: local only.

Follow-up school API source:
- Add `SchoolCourseApiClient` only if current school-auth session can call JXZX endpoints.
- Map Android fields from `CourseForSchedule` and `ExamInfo`.

**Step 3: Verify**

Run tests. For network source, add a debug case in Task 9 before claiming device success.

### Task 5: Calendar Settings Page Replacement

**Files:**
- Replace logic in: `entry/src/main/ets/pages/settings/CalendarSettingPage.ets`
- Use: `CourseScheduleSettingsStore`, `CourseScheduleRepository`, `ScheduleLocalStore`

**Step 1: Write behavior checklist**

Manual checklist:
- Page loads persisted term, first day, switches, and period times.
- Tapping current term opens editable dialog or term list.
- Tapping first day refresh calls repository.
- Tapping course data refresh updates local course store.
- Tapping exam refresh attempts exam sync and reports unsupported/fail/success.
- Time table validates input and shows format error on failure.
- Switches persist immediately.

**Step 2: Implement page state**

Remove hard-coded `setTimeout` behavior. Replace with async calls:
- `loadSettings()`
- `saveDisplaySetting()`
- `refreshFirstDay()`
- `refreshCourses()`
- `refreshExams()`
- `saveTimeTableText()`

**Step 3: Add custom schedule list entry**

Open a dialog listing `CustomScheduleItem[]`, with edit/delete entry points. Reuse the custom schedule dialog built in Task 7 when available.

**Step 4: Verify**

Run `check_ets_files` on `CalendarSettingPage.ets` and related store files, then build.

### Task 6: Schedule Page Settings Consumption

**Files:**
- Modify: `entry/src/main/ets/pages/SchedulePage.ets`
- Modify: `entry/src/main/ets/components/schedule/ScheduleHeaderRow.ets`
- Modify: `entry/src/main/ets/components/schedule/ScheduleGrid.ets`
- Modify: `entry/src/main/ets/components/schedule/ScheduleSidebar.ets`
- Modify: `entry/src/main/ets/components/schedule/CourseCard.ets` if border support is missing.

**Step 1: Add settings route**

`SchedulePage.onSettings()` should call:

```ts
uiPushUrl(this.getUIContext(), { url: 'pages/settings/CalendarSettingPage' })
```

**Step 2: Consume settings**

Add AppStorage links or async store load:
- show/hide Saturday and Sunday.
- show/hide divider lines.
- show/hide current time line.
- show/hide card borders.
- highlight today.
- use persisted period times.

Use a computed visible day list instead of hard-coded 7 columns. Width metrics must divide by visible day count.

**Step 3: Verify**

Manual UI checks on emulator:
- hide Sunday -> six columns.
- hide Saturday/Sunday -> five columns.
- time table edit changes sidebar times.
- gear opens settings page.

### Task 7: Exam and Custom Schedule Overlays

**Files:**
- Modify: `entry/src/main/ets/services/schoolSchedule/CourseScheduleRepository.ts`
- Modify: `entry/src/main/ets/pages/SchedulePage.ets`
- Create: `entry/src/main/ets/components/schedule/ExamDetailDialog.ets`
- Create: `entry/src/main/ets/components/schedule/CustomScheduleDetailDialog.ets`
- Create: `entry/src/main/ets/components/schedule/AddEditCustomScheduleDialog.ets`

**Step 1: Extend layout type**

Introduce `ScheduleBlockKind = 'course' | 'exam' | 'custom'` and a unified display item:

```ts
export interface ScheduleDisplayItem {
  kind: ScheduleBlockKind;
  id: string;
  title: string;
  subtitle: string;
  dateISO: string;
  weekday: number;
  startSection: number;
  endSection: number;
  colorKey: string;
  rawCourse?: CourseScheduleItem;
  rawExam?: ExamScheduleItem;
  rawCustom?: CustomScheduleItem;
}
```

**Step 2: Overlay behavior**

Match Android:
- exams render as exam-tinted cards and respect `showExamInfo`.
- custom schedules render as custom-tinted cards.
- overlapping items are trimmed so later cards do not cover earlier cards.

**Step 3: Custom CRUD**

Add floating action button for custom schedule creation. Dialog fields:
- title
- subtitle
- description
- date
- begin time
- end time

Validate begin < end. Save through local store.

**Step 4: Verify**

Tests for overlap conversion. Manual UI for add/edit/delete.

### Task 8: Course Detail Parity

**Files:**
- Modify: `entry/src/main/ets/components/schedule/CourseDetailDialog.ets`
- Create/modify exam and custom dialogs from Task 7.

**Step 1: Course details**

Show Android-equivalent course fields when the source is local course model:
- name
- teacher
- classroom
- description
- weeks
- campus
- number
- credit/hour/type/category/department when available

Keep current raw ICS display as fallback.

**Step 2: Exam details**

Show:
- name
- teacher
- classroom
- date
- begin/end
- exam mode
- seat id

**Step 3: Custom details**

Show edit/delete buttons.

### Task 9: Integration Debug Cases

Use `$harmonyos-integration-debug`.

**Files:**
- Create: `entry/src/main/ets/debug/CourseScheduleSettingsCase.ts`
- Create: `entry/src/main/ets/debug/CourseScheduleSyncCase.ts`
- Modify: `entry/src/main/ets/debug/DebugRunner.ts`

**Cases:**
- `COURSE_SCHEDULE_SETTINGS`: save settings, reload store, assert values and period times.
- `COURSE_SCHEDULE_SYNC`: with login state, refresh courses, assert local courses non-empty; if exam API implemented, assert exam call behavior.

Build/run:

```powershell
$env:DEVECO_SDK_HOME='D:\Software\Huawei\DevEco Studio\sdk'
$env:OHOS_SDK_HOME='D:\Software\Huawei\DevEco Studio\sdk\default\openharmony'
& 'D:\Software\Huawei\DevEco Studio\tools\node\node.exe' `
  'D:\Software\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.js' `
  --mode module -p module=entry@default assembleHap `
  -p buildMode=debug -p debuggable=true -p debugLine=false --no-daemon
```

Start app with DevEco MCP, then read `DebugIT_DebugRunner`. Success requires `SUMMARY ... failed=0`.

### Task 10: Final Verification and Cleanup

**Commands:**

```powershell
$env:DEVECO_SDK_HOME='D:\Software\Huawei\DevEco Studio\sdk'
$env:OHOS_SDK_HOME='D:\Software\Huawei\DevEco Studio\sdk\default\openharmony'
& 'D:\Software\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' test --no-daemon
& 'D:\Software\Huawei\DevEco Studio\tools\node\node.exe' `
  'D:\Software\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.js' `
  --mode module -p module=entry@default assembleHap `
  -p buildMode=debug -p debuggable=true -p debugLine=false --no-daemon
```

**Manual checks:**
- First launch with no schedule data shows fetch button or clear empty state.
- Refresh courses populates week view.
- Gear opens course schedule settings.
- Display switches survive app restart.
- Time table edit changes sidebar and free classroom status computation.
- Custom schedule add/edit/delete survives app restart.
- Exam cards appear only when exam sync exists and `showExamInfo` is enabled.

**Do not claim parity unless:**
- Unit tests pass.
- Debug runner summary has `failed=0` for schedule cases.
- Device UI checks cover settings navigation and at least one display setting.

