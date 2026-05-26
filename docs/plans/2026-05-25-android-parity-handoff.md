# Android Parity Handoff: Schedule, DDL, Free Classroom

Date: 2026-05-26

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
- Course schedule FAB visual/interaction parity with Android: four 42vp icon FABs, Android order, right-bottom anchor, and vertical drag clamp.

Still not fully aligned:

- Course sync is still BIT101/ICS based, not a complete Android-native school course API implementation.
- DDL still needs a focused Android-by-Android audit for sorting, loading/error states, settings/default behavior, and remaining edge-case interactions.
- Free classroom still needs a full Android-by-Android audit for defaults, sorting, loading/empty/error states, labels, and edge-case interactions.
- Course schedule visual details still need a final side-by-side audit after the data/API work settles.
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
- DevEco MCP was unavailable in the last active tool set. Device-side validation was still performed with local `hdc`, `uitest`, screenshots, UI tree dumps, and HiLog. If DevEco MCP is available in the next session, prefer it; if it is not available, use this hdc fallback and state that clearly.

## Current Uncommitted Work Summary

As of the latest handoff update, the only tracked dirty file should be:

- `build-profile.json5`

That file contains local signing password changes and must remain uncommitted unless the user explicitly asks for signing config cleanup.

The previously listed schedule/exam/FAB and DDL batches have been committed. Always confirm with `git status --short` before continuing.

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
- Android-style remaining-time copy.
- Android-aligned card title/body layout.
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

- Compare Android sorting, retention, warning threshold, empty states, and filtering behavior one by one.
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

Known gaps / audit items:

- Need side-by-side UI comparison against Android for defaults, labels, loading/empty/error states, and edge cases.
- Confirm exact query defaults and period-selection behavior.
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
- Device install/start on `127.0.0.1:5555` via `hdc`: installed and started successfully
- HiLog `DebugIT_DebugRunner`:
  - latest observed: `SUMMARY target=SCHOOL_NETWORK_PROBE total=1 passed=1 failed=0 duration=739ms`
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

3. Decide whether full Android-native school course API sync is required.
   - Exams now use the Android-referenced school endpoint.
   - Courses still do not.
   - If required, start from Android `DefaultCoursesRepo` and school course API references, then use TDD and a DevEco debug case.

4. Defer system calendar integration unless explicitly requested.
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

当前结论：`卷` 这个大 tab 的主要可用闭环已经完成不少，但仍未完全 Android 对齐。课表、考试刷新/显示、学期下拉、课程颜色、课表 FAB、DDL、空教室都已有主要实现；考试刷新已经接入 Android 参考的学校考试 API，并已在设备侧看到 `2025-2026-2` 返回 4 条考试。课程刷新仍是 BIT101/ICS 归一化，不是完整 Android 原生教务课程 API。DDL 和空教室还需要逐项对照 Android 的默认值、排序、空态、错误态和交互细节。

本地 BIT101-Android/ 是只读参考代码，不要提交它；screenshot/ 和 .mcp.json 是本地产物。不要提交 build-profile.json5 里的本机签名密码变化，除非我明确要求。DebugRunner.CURRENT_DEBUG_TARGET 跑完必须恢复为 DebugTarget.SCHOOL_NETWORK_PROBE。

当前 git 状态预期：
- 只剩 build-profile.json5 的本机签名脏改，不要提交。
- 最近 DDL 对齐提交已经完成到 `01a2175 feat(ddl): add picker overlays for deadline editing`。

最新 DDL 状态：
- 已完成 Android 风格空态、剩余时间文案、卡片布局、详情弹窗、手动删除确认、编辑弹窗标签。
- 已完成 DDL 新增/编辑日期/时间 picker：日期 chip 打开 DatePicker，时间 chip 未选日期时禁用；确认日期后显示 `yyyy-MM-dd` 并默认 `00:00:00`；时间 picker 确认 `HH:mm:ss`。
- 上轮重要根因：ArkUI `@Builder` 参数不会可靠跟踪 `@State` 更新，date/time chip builder 必须直接读取 `this.dateText` / `this.timeText`，不要再改回传参模式。

最近验证证据：
- hvigorw.bat test --no-daemon：BUILD SUCCESSFUL
- debug assembleHap：BUILD SUCCESSFUL
- hdc install/start app on 127.0.0.1:5555：安装并启动成功
- HiLog DebugIT_DebugRunner：SUMMARY target=SCHOOL_NETWORK_PROBE total=1 passed=1 failed=0 duration=739ms
- 截图：screenshot/schedule-fab-android-aligned-right.png 和 screenshot/schedule-fab-next-week-click.png，确认课表 FAB 右下角 4 按钮且右箭头可切到下一周
- 截图：screenshot/ddl-date-selected-final.png、screenshot/ddl-time-picker-final.png、screenshot/ddl-time-confirmed-final.png，确认 DDL 日期/时间 picker 可打开并写回
- UI tree：screenshot/ddl-time-confirmed-final-layout.json，确认 `添加DDL`、`2026-05-26`、`00:00:00` 可见

请从“继续 DDL 剩余 Android 细节审计，然后进入空教室 Android 细节对齐”开始：
1. 先读 Android 参考实现和当前 HarmonyOS diff。
2. 保护 build-profile.json5 的本机签名脏改，不要提交。
3. 对任何继续修改的行为先写/跑失败测试。
4. 涉及 UI 细节必须用 DevEco MCP 截图/UI tree/HiLog 验证。
5. 临时切 DebugRunner.CURRENT_DEBUG_TARGET 运行目标 debug case 后，必须恢复为 DebugTarget.SCHOOL_NETWORK_PROBE。
6. 最终至少跑 hvigor test 和 assembleHap；如果使用 debug case，HiLog DebugIT_DebugRunner 的 SUMMARY 必须 failed=0。

下一步建议优先级：
1. DDL：对照 Android 检查排序、loading/error、Lexue sync 失败、设置默认值/保留天数/提醒阈值、新增编辑成功后的 toast 和列表刷新。
2. 空教室：对照 Android 检查默认校区/楼宇/日期/节次、空闲/占用排序、空态/错误态、设置标签和持久化。
3. 课程：若用户要求，再实现完整 Android 原生教务课程 API；目前课程刷新仍是 BIT101/ICS 归一化。
```
