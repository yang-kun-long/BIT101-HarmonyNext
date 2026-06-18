# Android Parity Convergence Audit

Date: 2026-05-29

Update: 2026-06-18

This document is the stop-condition audit for the current Android parity push. It is not a backlog for open-ended comparison.

## Freeze Rules

The audit scope is fixed to the files listed below. After this document is accepted, new Android parity items may only enter development if they meet at least one rule:

- The main user flow fails.
- Data is wrong, lost, or persisted in a way that changes behavior.
- The app crashes, hangs, or cannot recover from a normal failure state.
- Login, teaching-app, Lexue, or sync status is misleading.
- The user explicitly asks to chase a visual or copy difference.

Otherwise the item is `Won't Chase`. Padding, color, typography, animation, and toast timing differences are not development tasks unless they affect readability, tap targets, overlap, or flow correctness.

## Status Meanings

- `Complete`: Implemented and covered by tests, build, device evidence, or direct code comparison.
- `Verify Once`: Implemented, but one final device pass is still useful before closing the area.
- `Must Fix`: Real remaining parity gap that affects flow correctness.
- `Won't Chase`: Known difference or possible micro-difference that is intentionally not pursued.
- `Out of Scope`: Belongs to a separate product decision or a different parity project.
- `Blocked`: Verification cannot run because the local device/simulator is unavailable.

## Fixed Audit Scope

DDL Android files:

- `BIT101-Android/features/schedule/src/main/java/cn/bit101/android/features/schedule/ddl/DDLSchedule.kt`
- `BIT101-Android/features/schedule/src/main/java/cn/bit101/android/features/schedule/ddl/DDLScheduleViewModel.kt`
- `BIT101-Android/features/schedule/src/main/java/cn/bit101/android/features/schedule/ddl/DDLScheduleEditDialog.kt`
- `BIT101-Android/features/schedule/src/main/java/cn/bit101/android/features/schedule/ddl/DDLScheduleDetailDialog.kt`
- `BIT101-Android/features/setting/src/main/java/cn/bit101/android/features/setting/page/DDLSettingPage.kt`
- `BIT101-Android/features/setting/src/main/java/cn/bit101/android/features/setting/viewmodel/DDLViewModel.kt`
- `BIT101-Android/data/src/main/java/cn/bit101/android/data/database/dao/DDLScheduleDao.kt`
- `BIT101-Android/data/src/main/java/cn/bit101/android/data/repo/DefaultDDLScheduleRepo.kt`
- `BIT101-Android/config/src/main/java/cn/bit101/android/config/setting/DefaultDDLSettings.kt`

Free classroom Android files:

- `BIT101-Android/features/schedule/src/main/java/cn/bit101/android/features/schedule/classroom/FreeClassroomSearch.kt`
- `BIT101-Android/features/schedule/src/main/java/cn/bit101/android/features/schedule/classroom/FreeClassroomSearchViewModel.kt`
- `BIT101-Android/features/setting/src/main/java/cn/bit101/android/features/setting/page/FreeClassroomSettingPage.kt`
- `BIT101-Android/features/setting/src/main/java/cn/bit101/android/features/setting/viewmodel/FreeClassroomViewModel.kt`
- `BIT101-Android/data/src/main/java/cn/bit101/android/data/repo/DefaultFreeClassroomRepo.kt`
- `BIT101-Android/config/src/main/java/cn/bit101/android/config/setting/DefaultFreeClassroomSettings.kt`

HarmonyOS files compared:

- `entry/src/main/ets/components/deadline/*`
- `entry/src/main/ets/pages/settings/DDLSettingPage.ets`
- `entry/src/main/ets/services/deadline/*`
- `entry/src/main/ets/services/storage/DdlStore.ts`
- `entry/src/main/ets/services/storage/DdlSettingsStore.ts`
- `entry/src/main/ets/pages/FreeClassroomPage.ets`
- `entry/src/main/ets/pages/settings/FreeClassroomSettingPage.ets`
- `entry/src/main/ets/components/freeClassroom/freeClassroomUiModel.ts`
- `entry/src/main/ets/services/jw/freeClassroomRepository.ts`
- `entry/src/main/ets/services/storage/FreeClassroomSettingsStore.ts`
- related `entry/src/test/Ddl*` and `entry/src/test/FreeClassroom*`

## DDL Matrix

| Area | Android behavior | HarmonyOS current behavior | Status | Evidence | Decision |
| --- | --- | --- | --- | --- | --- |
| Entry without subscription URL | Shows centered `获取乐学日程`; during loading shows only spinner in button. | Same when no local DDL exists; HarmonyOS now shows local manual DDL rows if they exist, because the add FAB is available without a Lexue URL. | Complete | `DDLSchedule.kt`; `DdlList.ets`; `getDdlFetchLexueCtaModel()` test; `DDL_MANUAL_CRUD` device evidence. | Closed. |
| First fetch start/success toast | Android main DDL page does not snackbar start/success for first fetch. | Start/success toasts removed; failures still visible. | Complete | `getDdlFetchLexueToastPolicy()` test; commit `5cc3548`. | Closed. |
| Auto sync on list open | Android ViewModel calls `updateLexueCalendar()` during init when URL exists, silently logs errors. | HarmonyOS calls `syncDdlFromLexue()` on appear when URL exists and logs errors. | Complete | `shouldAutoSyncDdlOnAppear()` test; commit `2b104d6`. | Closed. |
| List filtering and sorting | DAO query `WHERE time > now - afterDay ORDER BY time ASC`. | `listVisibleDdlItems()` uses `deadline > now - retentionDays` and sorts ascending. | Complete | `DDLScheduleDao.kt`; `DdlLocal.test.ets` retention and ordering tests. | Closed. |
| Done state | Android checkbox calls `setDone()` and finished future items remain visible. | Checkbox updates store and reloads list; done state is preserved. | Complete | `DDLScheduleViewModel.setDone`; `toggleDdlDone()` tests. | Closed. |
| Lexue sync merge | Android upserts by UID and preserves existing `done`. | HarmonyOS upserts Lexue events by UID and preserves `done`. | Complete | `DDLScheduleViewModel.updateLexueCalendar`; `mergeLexueEventsWithDdlItems()` tests. | Closed. |
| Manual add/edit/delete | Android supports local add, edit, delete. | HarmonyOS supports local add, edit, delete. | Complete | `DdlList.ets`, `DdlStore.ts`; `DDL_MANUAL_CRUD` on Huawei_Phone created, edited, deleted, and restored local DDL data. | Closed. |
| Manual UID uniqueness | Android uses UUID. | HarmonyOS uses timestamp plus sequence; duplicate same-ms bug fixed. | Complete | `createManualDdlUid()` test; commit `9ba98bc`. | Closed. |
| Remaining time text and warning color | Android uses beforeDay ratio and remaining text `剩余/已过 ...`. | HarmonyOS mirrors text and warning ratio. | Complete | `formatDdlRemainText()` and `computeDdlRemainRatio()` tests. | Closed. |
| Empty state copy and layout | Android copy is `怎么会有人没事儿了啊...`; card-like full-width item. | Same copy and layout model. | Complete | `getDdlEmptyText()` and layout tests. | Closed. |
| Card content layout | Android card displays title, detail, remain, checkbox trailing. | HarmonyOS matches this structure. | Complete | `DdlCard.ets`; `buildDdlCardTextLines()` and card layout tests. | Closed. |
| Detail dialog | Android shows DDL time, group, details; manual items show delete/edit actions. | HarmonyOS builds the same sections and action availability. | Complete | `DDLScheduleDetailDialog.kt`; `buildDdlDetailModel()` tests. | Closed. |
| Delete confirmation | Android asks `确认删除吗？`, message `<title> 删除后不可恢复`, success `删除成功OvO`. | Same model and toast. | Complete | `buildDdlDeleteConfirmModel()` test. | Closed. |
| Edit dialog labels and validation | Android labels: `添加DDL/编辑DDL`, `标题`, `请选择日期`, `请选择时间`, `详情`; errors for empty title/time. | Same labels and validation. | Complete | `DDLScheduleEditDialog.kt`; `buildDdlEditDialogModel()` and validation tests. | Closed. |
| Date/time picker behavior | Android date first; time disabled until date exists; date preserves or defaults time; time writes seconds 0. | HarmonyOS date picker writes date and defaults time to `00:00:00`; time picker writes `HH:mm:ss`. | Complete | Tests plus 2026-06-18 Huawei_Phone `uitest` visual smoke: add dialog date/time picker wrote `2026-06-18 00:00:00`, item rendered in the list, edit saved, and delete confirmation removed it. | Closed. |
| Settings data rows | Android has `重新获取订阅链接` and `重新拉取乐学日程`, disabled while loading. | Same rows and enabled policy. | Complete | `buildDdlSettingsDataItems()` test. | Closed. |
| Settings result toasts | Android only snackbars success/failure: `获取成功/获取失败`, `拉取成功/拉取失败`. | HarmonyOS now suppresses start toasts and keeps result toasts. | Complete, device blocked | `getDdlSettingsDataActionToastPolicy()` test; current uncommitted batch. DevEco/hdc unavailable on 2026-05-29. | Close after next device smoke run; no more code unless failure appears. |
| Settings numeric defaults | Android defaults: beforeDay `7`, afterDay `3`. | HarmonyOS defaults: warningDays `7`, retentionDays `3`. | Complete | `SettingDataStore.kt`; `DdlSettingsStore.ts`; tests. | Closed. |
| Settings numeric validation | Android `InputNumberDialog` accepts non-negative integer input. | HarmonyOS validates digits only and non-negative. | Complete | `validateDdlSettingsNumberInput()` test. | Closed. |
| Reminder/system calendar behavior | Not present in fixed DDL files as a DDL feature. | Not implemented. | Out of Scope | No relevant fixed-scope Android implementation. | Do not pursue under DDL parity. |
| Pixel-level visual differences | Compose Material and ArkUI differ. | Some visual differences remain. | Won't Chase | Would require open-ended side-by-side visual polish. | Only fix if text overlaps, tap targets fail, or user requests. |

DDL closure judgment: functionally complete for local CRUD, date/time picker interaction, and source-level parity. Settings sync result was exercised as far as the current login/network state allowed; no more source-level parity hunting remains in this module.

## Free Classroom Matrix

| Area | Android behavior | HarmonyOS current behavior | Status | Evidence | Decision |
| --- | --- | --- | --- | --- | --- |
| Page exists in schedule tools | Android schedule has free-classroom search page. | HarmonyOS has `FreeClassroomPage` and settings route. | Complete | `FreeClassroomSearch.kt`; `FreeClassroomPage.ets`; commits from `0800668` onward. | Closed. |
| Campus settings | Android stores current campus code/name and uses it for building query. | HarmonyOS stores campus code/name and syncs to AppStorage. | Complete | `FreeClassroomSettingsStore.ts`; `selectCampus()`; tests. | Closed. |
| Campus defaults | Android default campus is empty display/code. | HarmonyOS default campus is empty display/code. | Complete | `FreeClassroomSettingData.default`; `DEFAULT_FREE_CLASSROOM_SETTINGS`. | Closed. |
| Campus list loading dialog | Android loading branch shows spinner only. | HarmonyOS loading branch shows spinner only. | Complete | `shouldShowFreeClassroomCampusLoadingText()` test; screenshot evidence in handoff. | Closed. |
| Campus dialog empty/error | Android has no explicit empty/error branch, which can render blank. | HarmonyOS intentionally shows empty/error text instead of blank. | Complete | `resolveFreeClassroomCampusDialogState()` tests. | Accepted improvement, not a parity defect. |
| Campus selection propagation | Android Flow updates collectors immediately after setting write. | HarmonyOS updates AppStorage before persistence and rolls back on failure. | Complete | `shouldSyncFreeClassroomCampusSelectionBeforePersist()` tests; device evidence. | Closed. |
| Main page reacts to campus changes | Android `LaunchedEffect(currentCampusCode)` reloads buildings and clears selection. | HarmonyOS watches AppStorage and reloads buildings/clears selection. | Complete | `shouldReloadFreeClassroomBuildingsAfterCampusStorageChange()` test; device evidence. | Closed. |
| Building API filtering | Android requests buildings for selected campus and displays returned rows directly. | HarmonyOS no longer double-filters returned buildings by campus code. | Complete | `visibleFreeClassroomBuildingsForSelectedCampus()` test; device evidence showed Zhongguancun buildings. | Closed. |
| No-building copy | Android shows `没有获取到<校区>的教学楼QwQ\n(请尝试在设置中切换校区)`. | HarmonyOS uses the same copy. | Complete | `formatNoBuildingTip()`; screenshots. | Closed. |
| Building row display | Android shows building name, campus name, chevron, expandable. | HarmonyOS shows building name, campus name, chevron, expandable. | Complete | `FreeClassroomPage.ets`; UI tree evidence in handoff. | Closed. |
| Classroom API term source | Android uses `scheduleSettings.term`. | HarmonyOS uses `COURSE_SCHEDULE_APP_CURRENT_TERM`, fallback guess only when empty. | Complete | `resolveFreeClassroomTermCode()` test; term-source device evidence. | Closed. |
| Classroom query date/periods | Android classroom API uses current date and term; no user-facing period selector in fixed scope. | HarmonyOS queries current date and full day `[1, periodCount]`. | Complete | `getClassroomInfos()` paths and tests. | Closed. |
| Free-period text | Android merges free periods as `1~3, 6`. | HarmonyOS uses same formatting. | Complete | `formatFreePeriods()` test. | Closed. |
| Live free/busy status | Android computes current free, next busy, next free, and `空闲到明天/还会空闲/后空闲/使用中`. | HarmonyOS computes equivalent status from period times and busy periods. | Complete | `computeClassroomBusyStatus()` tests. | Closed. |
| Busy/free ordering | Android sorts free rooms ahead, longer available first, busy rooms by recovery, then name. | HarmonyOS mirrors sort keys and name fallback. | Complete | `sortFreeClassroomRowsForAndroidDisplay()` tests. | Closed. |
| Hide busy setting | Android `hideBusyClassroomFlow` filters currently not-free classrooms live. | HarmonyOS AppStorage link filters display and setting syncs before persistence. | Complete | `FREE_CLASSROOM` on Huawei_Phone found mixed rows in 3号教学楼: all=38, freeOnly=34; hidden busy samples included 3号楼311/312/318/330. | Closed. |
| Free threshold setting | Android default `5`, input dialog text includes unit, refreshes classroom info on change. | HarmonyOS default `5`, same text, validates integer, syncs AppStorage; threshold dialog crash fixed. | Complete | `FreeClassroomSettingsStore.ts`; threshold tests; device evidence. | Closed. |
| Building/classroom loading | Android shows `正在拉取教学楼列表...` and `正在获取教室列表...` with progress. | HarmonyOS shows equivalent loading tips. | Complete | `FreeClassroomPage.ets`; screenshots. | Closed. |
| Building/classroom errors | Android shows snackbar on failed building/classroom fetch; no inline classroom error card. | HarmonyOS shows toast on failed building/classroom fetch; no inline classroom error card. | Complete | `FreeClassroomPage.ets`; Android `LaunchedEffect` snackbar. | Toast vs snackbar is not a task. |
| Empty classroom after filter | Android shows `未找到教室 :(` when expanded list is empty. | HarmonyOS shows same copy. | Complete | `resolveExpandedClassroomState()` and UI code. | Closed. |
| Cache invalidation | Android caches classroom data until next timetable boundary, reuses same-day data. | HarmonyOS caches expanded rows until next timetable boundary and refreshes invalid rows. | Complete | `nextCacheDeadlineMs()`, `refreshInvalidExpandedBuildings()`. | Closed. |
| Back-to-top FAB | Android shows back-to-top FAB after list scroll index > 0. | HarmonyOS same condition. | Complete | `shouldShowFreeClassroomBackToTop()` test. | Closed. |
| Settings FAB | Android has settings FAB; 42dp size. | HarmonyOS has settings FAB; 42vp size. | Complete | UI model constants. | Closed. |
| Item spacing and colors | Android uses Material surfaces and specific padding/color mixes. | HarmonyOS uses close ArkUI styling and aligned padding constants. | Won't Chase | Padding/color micro-differences do not affect flow. | No more padding/color-only tasks. |

Free classroom closure judgment: functionally complete and device-verified on Huawei_Phone.

## Cross-Cutting Items

| Area | Android behavior | HarmonyOS current behavior | Status | Evidence | Decision |
| --- | --- | --- | --- | --- | --- |
| Login requirements | Android operations require login through repo wrappers. | HarmonyOS split login health into BIT101, school/Lexue, and JXZX teaching-app domains. | Complete | `LoginHealthService`; `LOGIN_HEALTH` debug evidence. | Closed. |
| Course schedule data source | Android has native school course repo/data model. | HarmonyOS course refresh now uses the JXZX `wdkbby` native school course API and maps rows into local schedule items. | Complete | Commit `faf8cf3`; `COURSE_SCHEDULE_SYNC` on Huawei_Phone returned 18 native courses and `failed=0`. | Closed. |
| Secure credential repair | Android may auto repair via saved credentials. | HarmonyOS does not store plaintext password. | Out of Scope | Security decision in handoff. | Requires secure credential storage design, not parity tail work. |
| System calendar insertion | Android has or implies calendar-related flows outside current DDL/free-classroom fixed scope. | HarmonyOS deferred. | Out of Scope | Course schedule plan. | Separate HarmonyOS permission/API spike. |
| Full visual pixel parity | Android Compose Material vs HarmonyOS ArkUI. | Similar but not pixel-identical. | Won't Chase | Current screenshots and UI trees. | Only fix visual issues that impair use. |

## Remaining Action List

Only these items remain from this audit:

1. Closed on 2026-06-18: DDL visual device smoke pass.
   - Open DDL list.
   - Added manual DDL `DDLVisualSmoke` using the date/time pickers; the form showed `2026-06-18` and `00:00:00`.
   - Confirmed the item rendered in the list without a Lexue subscription URL.
   - Opened the detail dialog, verified title/detail/date/group sections and delete/edit/close actions.
   - Edited the title through the detail dialog and confirmed the list refreshed.
   - Deleted it through the confirmation dialog and confirmed the list returned to the no-local-item CTA state.
   - DDL settings action behavior remains limited by login/network state as documented below; no code change is indicated.

2. Closed on 2026-06-18: free classroom hide-busy live pass.
   - `FREE_CLASSROOM` on Huawei_Phone selected `inner` mode and passed.
   - Device evidence: `SUMMARY target=FREE_CLASSROOM total=1 passed=1 failed=0 duration=37362ms`.
   - Mixed sample: `3号教学楼 all=38 freeOnly=34`; hidden busy samples included `3号楼311`, `3号楼312`, `3号楼318`, and `3号楼330`.

3. Closed on 2026-06-18: full Android-native school course API sync.
   - Commit `faf8cf3` added `CourseScheduleApiRepository` for `/jwapp/sys/wdkbby/modules/xskcb/cxxszhxqkb.do`.
   - Device evidence on Huawei_Phone: `SUMMARY target=COURSE_SCHEDULE_SYNC total=1 passed=1 failed=0 duration=5429ms`, with 18 native courses and 6 exams.

4. Closed on 2026-06-18: DDL manual CRUD storage and local-list visibility.
   - Fixed `resolveDdlContentState(false, false, visibleItemCount)` so local DDL rows show even without a cached Lexue subscription URL.
   - Device evidence on Huawei_Phone: `SUMMARY target=DDL_MANUAL_CRUD total=1 passed=1 failed=0 duration=710ms`.
   - The debug case created `manual-1000-1`, verified content state `list`, edited the title, deleted the item, and restored previous DDL data.

## Current Verification Blocker

On 2026-05-29, DevEco MCP could list simulator profiles but could not start them, and local `hdc list targets` returned `[Empty]`. Device-side smoke verification for the current DDL settings toast-policy batch is therefore `Blocked`, not failed.

Latest retry on 2026-05-29 19:25-19:28:

- `hvigorw.bat test --no-daemon`: `BUILD SUCCESSFUL`.
- Debug `assembleHap`: `BUILD SUCCESSFUL`; existing `ImageViewer.ets` `WRITE_IMAGEVIDEO` warning remains.
- `hdc list targets`: `[Empty]`.
- DevEco MCP `start_app` for `Mate 70 Pro`: timed out waiting for emulator startup.
- DevEco MCP `start_app` for `Huawei_Phone`: timed out waiting for emulator startup.
- DevEco MCP HiLog reported no running device and listed `Huawei_Phone`, `Mate 70 Pro`, and `Pura 90 Pro Max` as stopped emulator profiles.

Later retry on 2026-05-29 23:18-23:31:

- DevEco MCP `start_app` on `Pura 90 Pro Max`: installed and started successfully.
- HiLog `DebugIT_DebugRunner`: `SUMMARY target=SCHOOL_NETWORK_PROBE total=1 passed=1 failed=0 duration=636ms`.
- DDL page smoke:
  - `添加DDL` dialog opened from the add FAB.
  - Date picker opened and confirmed, writing `2026-05-29`.
  - Time picker opened and confirmed, writing `00:00:00`.
  - The page then returned to the no-subscription CTA state. This was the old `resolveDdlContentState(false, false, visibleItemCount) -> fetch-lexue` behavior and was superseded by the 2026-06-18 DDL manual CRUD fix below.
- DDL manual CRUD smoke:
  - 2026-06-18 `DDL_MANUAL_CRUD` on Huawei_Phone created `manual-1000-1`.
  - It verified `resolveDdlContentState(false, false, 1) -> list`, so local manual DDL rows are no longer hidden behind the no-subscription CTA.
  - It edited the title to `Debug manual DDL edited`, deleted the item, and restored previous DDL data.
  - Summary: `SUMMARY target=DDL_MANUAL_CRUD total=1 passed=1 failed=0 duration=710ms`.
- DDL visual `uitest` smoke:
  - 2026-06-18 on Huawei_Phone, the DDL tab was driven through `hdc shell uitest`.
  - Add dialog accepted title `DDLVisualSmoke`, detail `VisualFlowDetail`, date `2026-06-18`, and time `00:00:00`.
  - After confirmation, the DDL list rendered the local row instead of only the `获取乐学日程` CTA.
  - Detail dialog showed the DDL time, group `自定义`, details, and `删除/编辑/关闭` actions.
  - Edit saved an updated title and refreshed the list.
  - Delete confirmation removed the row and returned the page to the no-local-item CTA state.
- DDL settings smoke:
  - `DDL设置` rendered `重新获取订阅链接`, `重新拉取乐学日程`, `变色天数 = 7`, and `滞留天数 = 3`.
  - `重新获取订阅链接` was tapped; the row returned to enabled state and the failure path was reached.
  - HiLog showed WebVPN DNS failure (`Couldn't resolve host name` for `https://webvpn.bit.edu.cn/login?cas_login=true`) and `refresh DDL subscribe URL failed Error: 学校登录态不可用，请重新登录后再试`.
  - `重新拉取乐学日程` remained gated by missing subscribe URL (`请先获取订阅链接哦`), so result behavior for that action could not be exercised in this environment.
- Free classroom smoke:
  - 2026-06-18 `FREE_CLASSROOM` on Huawei_Phone selected `inner` mode.
  - It fetched 8 campuses, 20 Zhongguancun buildings, and sample classroom `1号楼127`.
  - Hide-busy mixed sample found at simulated class-time clock `08:30`: `3号教学楼 all=38 freeOnly=34`.
  - Hidden busy samples included `3号楼311`, `3号楼312`, `3号楼318`, and `3号楼330`.
  - Summary: `SUMMARY target=FREE_CLASSROOM total=1 passed=1 failed=0 duration=37362ms`.

DDL add/edit/delete visual pass is now successful on Huawei_Phone. The remaining DDL settings sync-result limitation is environmental: the current login/network state cannot obtain a Lexue subscribe URL, so `重新拉取乐学日程` stays correctly gated by `请先获取订阅链接哦`.
