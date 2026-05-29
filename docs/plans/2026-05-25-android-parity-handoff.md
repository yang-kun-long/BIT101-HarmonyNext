# Android Parity Handoff: Schedule, DDL, Free Classroom

Date: 2026-05-29

## Current Conclusion

The HarmonyOS `卷` tab is now usable across its main loops, but it is still not fully identical to Android.

Completed or mostly completed:

- Course schedule display and persisted display settings.
- Course refresh through the existing BIT101/ICS normalization path.
- Term discovery and term dropdown in schedule settings.
- Exam refresh through the Android-referenced school exam API.
- Exam persistence, term normalization, week overlay, detail dialog, and best-effort exam name enrichment.
- Course color restoration using the same stable course color key shape as the existing color store.
- Custom schedule add/edit/delete overlay.
- DDL local management plus Lexue sync settings.
- DDL list/card empty state, remaining-time copy, card text layout, detail dialog sections, delete confirmation, edit labels, and picker-based date/time editing.
- Free classroom page and settings page.
- Login health check split into BIT101 backend, school/Lexue, and JXZX teaching-app domains so settings no longer reports a false full success when exam/free-classroom auth is broken.
- Account page now restores nickname, avatar, UID, motto, and persisted username-backed student id instead of showing mock data.
- Free classroom queries now use the course schedule's selected term first, matching Android's `scheduleSettings.term`, and only fall back to a date-guessed term when no schedule term is available.
- Course schedule FAB visual/interaction parity with Android: four 42vp icon FABs, Android order, right-bottom anchor, and vertical drag clamp.

Still not fully aligned:

- Course sync is still BIT101/ICS based, not a complete Android-native school course API implementation.
- DDL still needs a focused Android-by-Android audit for sorting, loading/error states, settings/default behavior, and remaining edge-case interactions.
- Free classroom still needs a full Android-by-Android audit for defaults, sorting, loading/empty/error states, labels, and edge-case interactions.
- Course schedule visual details still need a final side-by-side audit after the data/API work settles.
- Secure credential storage / auto repair is still not implemented. HarmonyOS should not persist plaintext password just to copy Android's auto relogin behavior.
- System calendar insertion remains deferred.

## Recent Commits

- `68f3176 chore(git): ignore local reference artifacts`
- `7ae0854 docs(schedule): document Android parity plan`
- `d77128c test(debug): add integration debug runner cases`
- `8b11fbe feat(auth): improve school login session bootstrap`
- `509f064 feat(ddl): add deadline sync settings`
- `0800668 feat(free-classroom): add classroom availability page`
- `1dc0114 feat(schedule): align course timetable with Android`
- `00f2836 chore(app): wire Android parity features`
- `157521b docs(schedule): add Android parity handoff`
- `b491b2d feat(ddl): align empty state copy with Android`
- `fdcae48 feat(ddl): show Android-style remaining time`
- `7a9d357 feat(ddl): align card text layout with Android`
- `a306b69 feat(ddl): align detail dialog sections`
- `6fbb367 feat(ddl): confirm manual deletion`
- `524a1e8 feat(ddl): align edit dialog labels`
- `01a2175 feat(ddl): add picker overlays for deadline editing`

## Repository State Notes

- Current branch: `main`.
- `BIT101-Android/` is a read-only local Android reference and is ignored by git.
- `screenshot/` and `.mcp.json` are ignored local artifacts.
- `build-profile.json5` contains local signing password changes. Do not commit those unless the user explicitly asks for signing config cleanup.
- `DebugRunner.CURRENT_DEBUG_TARGET` must be restored to `DebugTarget.SCHOOL_NETWORK_PROBE` after temporary debug runs. It is currently expected to stay there for handoff.
- Do not use unrelated MCP servers such as GitHub or CloudBase for this local HarmonyOS parity work. The user explicitly objected to that.
- DevEco MCP is available for `project_sync`, `start_app`, HiLog, screenshot, and UI tree in the latest session. `check_ets_files` still returned "未初始化，请先初始化或更新工程根路径" even after `project_sync`; use hvigor compile as the fallback for ArkTS checking when that specific tool fails.

## Current Uncommitted Work Summary

As of the latest handoff update, the working tree is intentionally dirty. Do not assume only `build-profile.json5` is modified.

- `build-profile.json5`
  - Local signing password changes only. Do not commit or revert unless explicitly requested.
- Handoff doc:
  - `docs/plans/2026-05-25-android-parity-handoff.md`
- Current free-classroom hide-busy Android-parity audit batch:
  - `entry/src/main/ets/components/freeClassroom/freeClassroomUiModel.ts`
  - `entry/src/main/ets/pages/settings/FreeClassroomSettingPage.ets`
  - `entry/src/test/FreeClassroom.test.ets`
  - Behavior: `隐藏当前不空闲的教室` now syncs `AppStorage` before persistence, matching Android Flow-style immediate settings propagation. Persistence failure rolls state and `AppStorage` back.

The previous DDL audit batch, login-health/account-profile batch, and free-classroom term-source/campus/threshold batches have been committed in the current repository history. Confirm with `git status --short` before committing.

Always confirm with `git status --short` before continuing, and do not include `build-profile.json5`, `screenshot/`, `.mcp.json`, or `BIT101-Android/` in any commit unless the user explicitly asks.

## Login Health / Account Status

Implemented and committed in the current repository history:

- `LoginHealthService` now checks three domains:
  - BIT101 backend via `/user/check`.
  - School/Lexue via restored `BitSsoSession`.
  - JXZX teaching app via `FreeClassroomRepository.getCampusInfos()`.
- Summary behavior:
  - All three healthy: `已登录`, toast `登录状态检查成功`.
  - BIT101 or school fail: `未登录`, toast `登录状态检查失败`, and clears stored login state.
  - Only JXZX fail: `部分异常`, toast `部分登录态异常，请重新登录后再试考试/空教室`, and does not clear BIT101/Lexue state.
- Operation requirements now distinguish:
  - `core`: BIT101 + school/Lexue. Used by DDL/Lexue and course refresh.
  - `jxzx`: BIT101 + school/Lexue + JXZX. Used by exam, term, and free-classroom operations.
  - `all`: full health summary.
- Account page no longer invents mock `1120202222`.
  - It loads `sid`, `nickname`, `avatar`, `UID`, and `motto` from `TokenStore.user_info`.
  - If local profile is incomplete, it falls back to BIT101 `/user/info/0` and stores the profile back.
  - Login persists the submitted username through `TokenStore.saveUsername()`.
  - Existing old sessions cannot recover a missing student id unless the username key exists or the backend profile contains `sid`; after the next real login the sid is persisted.
- Account actions:
  - `已登录`: `退出登录` and `清除所有登录状态`.
  - `部分异常`: `重新登录` with subtext for rebuilding teaching-app state.
  - `未登录`: `登录`.

Important decision:

- Do not store plaintext password for Android-style auto repair. A future auto-repair design should use a secure credential storage spike.

## Course Schedule Status

Implemented:

- Course schedule settings model and persisted settings store.
- Settings page controls for current term, first day, period times, weekend visibility, border, today highlight, divider, current time line, and exam visibility.
- Term fetching from school-side data and dropdown selection in the settings page.
- Local schedule domain under `services/schoolSchedule`.
- JSON-backed local storage for courses, exams, and custom schedules.
- ICS course events normalized into local `CourseScheduleItem`.
- Schedule grid consumes local settings and dynamic period count.
- Exam and custom schedule overlay plumbing.
- Custom schedule add/edit/delete dialogs.
- Course, exam, and custom detail dialogs.
- Exam refresh implemented from the Android reference endpoint:
  - POST `/jwapp/sys/wdksapMobile/modules/ksap/cxxsksap.do`
  - params include `XNXQDM` and `*order=-KSRQ`
- Exam term normalization fixed so API terms like `2025-2026学年 2学期` match local settings like `2025-2026-2`.
- Exam names are enriched when the API returns only course-code-like names:
  - first by `course.number`
  - then by unique teacher match for current ICS-derived courses
  - ambiguous matches are ignored
- Course colors restored by using stable `title|teacher` style color keys.
- Schedule FAB aligned with Android:
  - four actions only: next week, previous week, add custom schedule, settings
  - no refresh FAB
  - SVG icons instead of text labels
  - 42vp button size, 24vp icon size, 10vp gap
  - right-bottom anchored transparent overlay
  - vertical drag clamp matching Android's safe range

Known gaps:

- Full Android-native school course sync is not implemented. Current course refresh still uses existing BIT101/ICS normalization.
- Exact visual parity still needs side-by-side screenshots against Android after DDL/free classroom audits.
- System calendar insertion remains deferred.

## DDL Status

Implemented:

- DDL models and local store.
- Lexue calendar sync writes parsed events into the DDL store.
- DDL settings store and settings page.
- DDL list/detail display behavior updates.
- Android-style empty-state copy.
- Android-style empty-state container layout.
- Android-style remaining-time copy.
- Android-aligned card title/body layout.
- Android-aligned retention boundary filtering (`time > now - afterDay`) and trailing checkbox placement inside the card.
- Android-aligned first-run Lexue fetch CTA loading content: spinner only, no extra `获取中...` text.
- Android-aligned detail dialog sections.
- Manual DDL delete confirmation.
- Edit/add dialog labels.
- Date/time picker editing:
  - Date chip opens an inline `DatePicker` overlay with `取消` / `确定`.
  - Time chip is disabled until a date is selected.
  - Confirming the date writes `yyyy-MM-dd` and defaults time to `00:00:00`.
  - Time chip opens a `TimePicker` overlay and confirms `HH:mm:ss`.
  - Important root cause from the last session: ArkUI `@Builder` parameters did not re-render when `@State` changed, so the date/time chips must read `this.dateText` / `this.timeText` directly inside their builders.
- Unit tests:
  - `DdlLocal.test.ets`
  - `DdlSync.test.ets`
  - `DdlListModel.test.ets`

Known gaps / audit items:

- Compare Android sorting, warning threshold, and filtering behavior one by one. Retention boundary and empty-state container layout are now covered by tests.
- Confirm whether Android has additional reminder/system-calendar behavior that HarmonyOS should mirror.
- Confirm FAB/default setting styling against Android DDL after the course schedule FAB change.
- Confirm loading/error states and Lexue sync failure UX against Android.
- Confirm successful add/edit flow end-to-end after picker changes, including toast/snackbar copy and list refresh.

## Free Classroom Status

Implemented:

- Free classroom page.
- Free classroom settings page.
- Campus/building/query repository.
- Login/session preparation hook.
- Settings store for campus, hide busy classrooms, and free threshold.
- Unit test:
  - `FreeClassroom.test.ets`
- DevEco MCP debug case:
  - `FREE_CLASSROOM`
- Free classroom term source now follows Android:
  - Android uses `scheduleSettings.term` when calling `getClassroomData`.
  - HarmonyOS now uses `COURSE_SCHEDULE_APP_CURRENT_TERM` via `resolveFreeClassroomTermCode()`.
  - It falls back to `guessCurrentSchoolTermCode()` only when the schedule term is empty.
- Free classroom campus selection dialog loading state now follows Android:
  - Android shows only the spinner in the loading branch.
  - HarmonyOS no longer renders the extra `正在拉取校区列表...` helper text.
- Free classroom list item spacing now follows Android constants:
  - Building and classroom rows use 10vp horizontal / 5vp vertical outer padding.
  - Building and classroom content uses 15vp / 15vp / 5vp / 15vp inner padding.
- Free classroom building display no longer double-filters the building API result by `campusCode`:
  - Android requests buildings for the selected campus and displays the returned list directly.
  - HarmonyOS previously requested by campus, then filtered the returned rows again by `building.campusCode`, which could incorrectly produce an empty page even when the API returned buildings.
  - Device debug evidence showed `campus count = 7`, `building count = 20` for `中关村校区`, and a sample classroom `1号楼127`.
- Free classroom campus selection now syncs the selected campus to app storage before persistence finishes:
  - This avoids returning quickly from settings to the main free-classroom page with the old campus still active.
  - Persistence failure still rolls the state and app storage back.
- Free classroom threshold dialog now avoids relying on `@CustomDialog` controller injection:
  - Device verification found `Cannot read property close of undefined` when confirming the threshold dialog.
  - The dialog now asks the owning page to close it, and threshold success toast text follows Android `InputNumberDialog` copy: `设置成功OvO`.
- Free classroom hide-busy setting now syncs to app storage before persistence finishes:
  - Android collects `hideBusyClassroomFlow` directly in the free-classroom page and filters expanded classrooms live.
  - HarmonyOS now updates `AppStorage` immediately when `隐藏当前不空闲的教室` changes, so the main free-classroom page can observe the new value before the preferences write completes.
  - Persistence failure rolls back the page state and `AppStorage`.

Known gaps / audit items:

- Need side-by-side UI comparison against Android for remaining defaults, labels, loading/empty/error states, and edge cases.
- Confirm exact query defaults and period-selection behavior beyond term source.
- Continue device-side hide-busy verification with a campus/building that has both currently free and currently busy classrooms; current code path is covered by tests and app-storage propagation, but the last device state was on `良乡校区` with no building rows.
- Confirm FAB/default setting styling against Android free classroom after the course schedule FAB change.

## Verification Evidence From Latest Work

Latest verified commands:

```powershell
$env:DEVECO_SDK_HOME='D:\Software\Huawei\DevEco Studio\sdk'
$env:OHOS_SDK_HOME='D:\Software\Huawei\DevEco Studio\sdk\default\openharmony'
& 'D:\Software\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' test --no-daemon
& 'D:\Software\Huawei\DevEco Studio\tools\node\node.exe' `
  'D:\Software\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.js' `
  --mode module -p module=entry@default assembleHap `
  -p buildMode=debug -p debuggable=true -p debugLine=false --no-daemon
```

Latest results observed in this session:

- `hvigorw.bat test --no-daemon`: `BUILD SUCCESSFUL`
- debug `assembleHap`: `BUILD SUCCESSFUL`
- DevEco MCP `start_app` on `Mate 70 Pro`: installed and started successfully
- HiLog `DebugIT_DebugRunner`:
  - latest observed: `SUMMARY target=SCHOOL_NETWORK_PROBE total=1 passed=1 failed=0 duration=480ms`
- Current free classroom hide-busy sync audit:
  - TDD RED: `hvigorw.bat test --no-daemon` failed because `shouldSyncFreeClassroomHideBusyBeforePersist` did not exist.
  - GREEN: `FreeClassroom.test.ets` passes after adding the helper and immediate `AppStorage` sync/rollback behavior.
  - `mcp__deveco__.check_ets_files` returned stale/incorrect missing-export diagnostics for already compiled free-classroom helpers; `CompileArkTS` in debug `assembleHap` passed, so hvigor compile is the practical source of truth for this check.
  - `screenshot/free-classroom-hide-busy-sync-after-build-20260529.png`
  - `screenshot/full_dump_bit101harmonyos_20260529173922687.json`
  - UI tree confirmed the `空教室` tab rendered and current device state showed `没有获取到良乡校区的教学楼QwQ\n(请尝试在设置中切换校区)`.
- Current free classroom settings audit screenshot/UI tree:
  - `screenshot/free-classroom-campus-dialog-android-loading-text-removed-20260529.png`
  - `screenshot/simple_dump_bit101harmonyos_20260529155337839.txt`
  - UI tree confirmed settings page and `切换校区` dialog rendered, with no `正在拉取校区列表...` node present.
- Current free classroom list spacing audit screenshot/UI tree:
  - `screenshot/free-classroom-item-padding-android-aligned-20260529.png`
  - `screenshot/simple_dump_bit101harmonyos_20260529160246219.txt`
  - UI tree confirmed the `空教室` tab rendered without layout breakage; current device state showed the Android-style empty-building tip for `中关村校区`.
- Current free classroom real-list / expanded-building verification:
  - `FREE_CLASSROOM` debug case during root-cause investigation:
    - `SUMMARY target=FREE_CLASSROOM total=1 passed=1 failed=0 duration=1844ms`
    - case logs showed `campus count = 7`, `building count = 20 campus = 中关村校区`, and sample `1号楼127`.
  - `screenshot/free-classroom-building-list-after-filter-fix-20260529.png`
  - `screenshot/simple_dump_bit101harmonyos_20260529162453268.txt`
  - UI tree confirmed `1号教学楼`, `3号教学楼`, `6号教学楼`, and `8号教学楼` rendered for `中关村校区`.
  - `screenshot/free-classroom-expanded-building-after-filter-fix-20260529.png`
  - `screenshot/simple_dump_bit101harmonyos_20260529162522364.txt`
  - UI tree confirmed expanded `1号教学楼` shows `1号楼127`, `空闲时段: 1~13`, and `空闲到明天`.
- Current free classroom campus-switch verification:
  - `screenshot/free-classroom-campus-dialog-repro-20260529.png`
  - `screenshot/simple_dump_bit101harmonyos_20260529163116873.txt`
  - UI tree confirmed the campus dialog renders 7 selectable campus radio rows.
  - `screenshot/free-classroom-campus-sync-liangxiang-final-20260529.png`
  - `screenshot/simple_dump_bit101harmonyos_20260529163928284.txt`
  - UI tree confirmed returning to the free-classroom tab after selecting `良乡校区` renders building rows tagged `良乡校区`.
- Current free classroom threshold-dialog verification:
  - `screenshot/simple_dump_bit101harmonyos_20260529165738694.txt`
  - UI tree confirmed the threshold dialog renders `空闲时段阈值`, `不大于此值的空闲时段将被忽略 (单位: 分钟)`, input value `5`, `取消`, and `确定`.
  - `screenshot/free-classroom-threshold-confirmed-no-crash-20260529.png`
  - `screenshot/simple_dump_bit101harmonyos_20260529165815778.txt`
  - Screenshot/UI tree confirmed confirming the dialog returns to `空教室设置` with `空闲时段阈值` and `5 分钟` still visible instead of crashing back to launcher.
- Current DDL settings number-dialog verification:
  - `screenshot/ddl-settings-number-dialog-open-20260529.png`
  - `screenshot/simple_dump_bit101harmonyos_20260529171445910.txt`
  - UI tree confirmed the dialog renders `变色天数`, `临近日程会改变颜色`, value `7`, `取消`, and `确定`.
  - `screenshot/ddl-settings-number-dialog-confirmed-no-crash-20260529.png`
  - `screenshot/simple_dump_bit101harmonyos_20260529171536881.txt`
  - Screenshot/UI tree confirmed confirming the dialog returns to `DDL设置` with `变色天数` and value `7` still visible instead of crashing back to launcher.
- Recent DDL audit screenshots/UI tree:
  - `screenshot/ddl-after-empty-layout-card-20260529.png`
  - `screenshot/simple_dump_bit101harmonyos_20260529152134478.txt`
  - UI tree confirmed DDL tab rendered, item `测试` visible, and card trailing `Toggle` is `checkable: 1`, `checked: 1`.
- Earlier login-health debug run:
  - `SUMMARY target=LOGIN_HEALTH total=1 passed=1 failed=0`
  - case logs showed `bit101=true`, `school=true`, `jxzx=true` on the current device state.
- Account profile screenshot after persisted profile repair:
  - `screenshot/account-profile-fields-restored-after-persist-key-20260526.png`
  - UI tree confirmed `账号设置`, nickname `BIT101-732f57d6`, `UID 13482`, `登录状态检查 已登录`, `退出登录`, and `清除所有登录状态`.
- Free classroom term-source screenshot / UI tree after latest fix:
  - `screenshot/free-classroom-term-source-verification-20260526.png`
  - `screenshot/simple_dump_bit101harmonyos_20260526232050598.txt`
- Device screenshot after FAB alignment:
  - `screenshot/schedule-fab-android-aligned-right.png`
- Device screenshot after clicking next-week FAB:
  - `screenshot/schedule-fab-next-week-click.png`
  - confirmed week changed from 13 to 14
- UI tree dump:
  - `screenshot/simple_dump_bit101harmonyos_20260525231648379.txt`
  - confirmed four right-side circular FAB buttons
- Device screenshots after DDL picker alignment:
  - `screenshot/ddl-date-selected-final.png`
  - `screenshot/ddl-time-picker-final.png`
  - `screenshot/ddl-time-confirmed-final.png`
- UI tree dump after DDL picker alignment:
  - `screenshot/ddl-time-confirmed-final-layout.json`
  - confirmed `添加DDL`, `2026-05-26`, and `00:00:00` are visible in the editor after picker confirmation.

Existing warnings:

- hvigor dependency metadata warning.
- `ImageViewer.ets` warning for `ohos.permission.WRITE_IMAGEVIDEO`.
- DevEco MCP `check_ets_files` can fail with "未初始化"; use hvigor `CompileArkTS` / `assembleHap` as the practical compile check if that tool remains unavailable.

## Integration Debug Workflow

Relevant skill: `$harmonyos-integration-debug`.

To run a debug case:

1. Temporarily change `CURRENT_DEBUG_TARGET` in `entry/src/main/ets/debug/DebugRunner.ts`.
2. Build HAP.
3. Start app with DevEco MCP on `Mate 70 Pro` or the available emulator.
4. Read HiLog with tag `DebugIT_DebugRunner`.
5. Success requires a `SUMMARY ... failed=0`.
6. Restore `CURRENT_DEBUG_TARGET` to `DebugTarget.SCHOOL_NETWORK_PROBE` before committing or handing off.

Useful MCP values:

- HVD: `Mate 70 Pro`
- Bundle: `com.example.bit101harmonyos`
- Module: `entry`
- Target: `default`
- Ability: `EntryAbility`
- Runner tag: `DebugIT_DebugRunner`

## Recommended Next Work

1. Continue detailed Android parity audit for DDL.
   - Defaults.
   - Sort order.
   - Loading/error states.
   - Add/edit success flow after picker changes.
   - Lexue sync failure UX.
   - Settings retention/warning behavior.
   - FAB styling and placement.

2. Continue detailed Android parity audit for free classroom.
   - Default campus/building/date/period behavior.
   - Busy/free display and ordering.
   - Empty/loading/error states.
   - Settings labels and persistence.
   - Re-run hide-busy interaction on `中关村校区` or another campus with real building/classroom rows, then capture before/after screenshot and UI tree.
   - The selected-term source is already aligned; do not redo it unless regression evidence appears.

3. Commit or checkpoint the current free-classroom hide-busy audit batch when the user asks for a commit.
   - Exclude `build-profile.json5`.
   - Include only source/test files relevant to this work.
   - Keep `DebugRunner.CURRENT_DEBUG_TARGET = DebugTarget.SCHOOL_NETWORK_PROBE`.

4. Decide whether full Android-native school course API sync is required.
   - Exams now use the Android-referenced school endpoint.
   - Courses still do not.
   - If required, start from Android `DefaultCoursesRepo` and school course API references, then use TDD and a DevEco debug case.

5. Defer system calendar integration unless explicitly requested.
   - It needs a separate HarmonyOS permission/API spike and device verification.

## New Conversation Prompt

Copy this into a new chat:

```text
继续 D:\BIT101\BIT101HarmonyOS 的 HarmonyOS 安卓对齐工作。请先使用并遵守相关 skills 再动代码：必须使用 arkts-development、test-driven-development、systematic-debugging、harmonyos-integration-debug、verification-before-completion；如果涉及 UI 细节核对，也使用 frontend/UI 相关 skill。需要 HarmonyOS Integration Debug 时必须用 DevEco MCP 做设备侧验证，包括 build/start app/HiLog/UI tree/screenshot。不要只靠静态代码判断或只跑单元测试就声称完成。

注意：不要使用 GitHub/CloudBase 等无关 MCP。这个任务是本地 HarmonyOS 工程对齐。若 DevEco MCP 工具在当前会话不可用，必须使用本机 hdc/uitest/hilog 做等价设备侧验证，并在交付时明确说明 fallback。

请先阅读：
- AGENTS.md
- docs/plans/2026-05-24-android-parity-analysis.md
- docs/plans/2026-05-25-course-schedule-android-parity.md
- docs/plans/2026-05-25-android-parity-handoff.md

当前结论：`卷` 这个大 tab 的主要可用闭环已经完成不少，但仍未完全 Android 对齐。课表、考试刷新/显示、学期下拉、课程颜色、课表 FAB、DDL、空教室都已有主要实现；考试刷新已经接入 Android 参考的学校考试 API，并已在设备侧看到 `2025-2026-2` 返回 4 条考试。课程刷新仍是 BIT101/ICS 归一化，不是完整 Android 原生教务课程 API。登录健康检查已拆成 BIT101、学校/Lexue、JXZX 教务应用三域，账号页不再显示 mock 学号；空教室查询学期来源已对齐 Android，优先使用课表设置当前学期。DDL 和空教室仍需逐项对照 Android 的默认值、排序、空态、错误态和交互细节。

本地 BIT101-Android/ 是只读参考代码，不要提交它；screenshot/ 和 .mcp.json 是本地产物。不要提交 build-profile.json5 里的本机签名密码变化，除非我明确要求。DebugRunner.CURRENT_DEBUG_TARGET 跑完必须恢复为 DebugTarget.SCHOOL_NETWORK_PROBE。

当前 git 状态预期：
- `build-profile.json5` 有本机签名脏改，不要提交。
- 当前空教室 hide-busy Android 细节审计批次未提交：`freeClassroomUiModel.ts`、`FreeClassroomSettingPage.ets`、`FreeClassroom.test.ets`。
- `docs/plans/2026-05-25-android-parity-handoff.md` 已更新到当前会话状态。
- 之前的 DDL 审计批次、登录健康/账号资料恢复、空教室学期来源、校区同步、阈值弹窗和 DDL 设置弹窗批次在当前仓库历史中已经提交，不要按旧交接当成未提交批次。

最新 DDL 状态：
- 已完成 Android 风格空态、剩余时间文案、卡片布局、详情弹窗、手动删除确认、编辑弹窗标签。
- 已完成 DDL 新增/编辑日期/时间 picker：日期 chip 打开 DatePicker，时间 chip 未选日期时禁用；确认日期后显示 `yyyy-MM-dd` 并默认 `00:00:00`；时间 picker 确认 `HH:mm:ss`。
- 已完成 Android retention 边界 `time > now - afterDay`、卡片右侧 checkbox 内置，以及空态容器布局 model/ArkUI 对齐。
- 已完成无订阅链接首次获取乐学日程按钮 loading 态对齐：只显示 spinner，不显示额外文字。
- 上轮重要根因：ArkUI `@Builder` 参数不会可靠跟踪 `@State` 更新，date/time chip builder 必须直接读取 `this.dateText` / `this.timeText`，不要再改回传参模式。

最新空教室状态：
- 已完成学期来源对齐、校区列表 loading 文案、列表 padding、建筑 API 二次过滤移除、校区选择即时同步、阈值弹窗稳定性。
- 刚完成但未提交：`隐藏当前不空闲的教室` 开关现在先同步 `AppStorage` 再持久化，失败时回滚状态和 `AppStorage`，用于对齐 Android `hideBusyClassroomFlow` 的即时传播。
- 当前设备状态停在 `良乡校区`，UI tree 显示 `没有获取到良乡校区的教学楼QwQ\n(请尝试在设置中切换校区)`；下一轮若继续 hide-busy 设备交互验证，建议先切回 `中关村校区` 或其他有真实楼宇/教室的校区。

最近验证证据：
- hvigorw.bat test --no-daemon：BUILD SUCCESSFUL
- debug assembleHap：BUILD SUCCESSFUL
- DevEco MCP start_app on Mate 70 Pro：安装并启动成功
- HiLog DebugIT_DebugRunner：SUMMARY target=SCHOOL_NETWORK_PROBE total=1 passed=1 failed=0 duration=480ms
- TDD RED：新增 `shouldSyncFreeClassroomHideBusyBeforePersist` 测试后，`hvigorw.bat test --no-daemon` 因缺少导出失败。
- TDD GREEN：加入 helper 和 hide-busy 立即同步/失败回滚后，`hvigorw.bat test --no-daemon` 成功。
- 当前 hide-busy 设备侧截图/UI tree：`screenshot/free-classroom-hide-busy-sync-after-build-20260529.png`、`screenshot/full_dump_bit101harmonyos_20260529173922687.json`。
- DevEco MCP `check_ets_files` 对已存在导出返回过陈旧/错误诊断；以本轮 `CompileArkTS`/`assembleHap` 成功作为 ArkTS 编译依据。
- 截图/UI tree：screenshot/ddl-after-empty-layout-card-20260529.png、screenshot/simple_dump_bit101harmonyos_20260529152134478.txt，确认 DDL 页渲染、测试项可见、卡片 trailing Toggle checkable/checked。
- 早前 LOGIN_HEALTH debug case：SUMMARY target=LOGIN_HEALTH total=1 passed=1 failed=0；日志显示 bit101=true、school=true、jxzx=true
- 截图/UI tree：screenshot/account-profile-fields-restored-after-persist-key-20260526.png，确认账号页昵称/UID/motto/登录状态恢复；旧会话缺失 sid 时不会再显示 mock 学号，重新登录后会持久化 username
- 截图/UI tree：screenshot/free-classroom-term-source-verification-20260526.png、screenshot/simple_dump_bit101harmonyos_20260526232050598.txt，确认空教室批次已设备侧启动验证
- 截图：screenshot/schedule-fab-android-aligned-right.png 和 screenshot/schedule-fab-next-week-click.png，确认课表 FAB 右下角 4 按钮且右箭头可切到下一周
- 截图：screenshot/ddl-date-selected-final.png、screenshot/ddl-time-picker-final.png、screenshot/ddl-time-confirmed-final.png，确认 DDL 日期/时间 picker 可打开并写回
- UI tree：screenshot/ddl-time-confirmed-final-layout.json，确认 `添加DDL`、`2026-05-26`、`00:00:00` 可见

请从“提交/继续当前空教室 hide-busy 审计批次，然后继续 DDL 和空教室 Android 细节审计”开始：
1. 先读 Android 参考实现和当前 HarmonyOS diff。
2. 保护 build-profile.json5 的本机签名脏改，不要提交。
3. 对任何继续修改的行为先写/跑失败测试。
4. 涉及 UI 细节必须用 DevEco MCP 截图/UI tree/HiLog 验证。
5. 临时切 DebugRunner.CURRENT_DEBUG_TARGET 运行目标 debug case 后，必须恢复为 DebugTarget.SCHOOL_NETWORK_PROBE。
6. 最终至少跑 hvigor test 和 assembleHap；如果使用 debug case，HiLog DebugIT_DebugRunner 的 SUMMARY 必须 failed=0。

下一步建议优先级：
1. 若用户要求提交，先提交当前空教室 hide-busy 审计批次，排除 build-profile.json5 和截图/.mcp.json。
2. DDL：对照 Android 检查排序、loading/error、Lexue sync 失败、设置默认值/保留天数/提醒阈值、新增编辑成功后的 toast 和列表刷新。
3. 空教室：先补 hide-busy 在真实楼宇/教室列表上的设备侧 before/after 截图/UI tree；再继续对照 Android 检查默认校区/楼宇/日期/节次、空闲/占用排序、空态/错误态、设置标签和持久化；学期来源已对齐，不要重复做。
4. 课程：若用户要求，再实现完整 Android 原生教务课程 API；目前课程刷新仍是 BIT101/ICS 归一化。
```
