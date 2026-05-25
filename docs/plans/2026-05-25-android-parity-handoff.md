# Android Parity Handoff: Schedule, DDL, Free Classroom

Date: 2026-05-25

## Current Conclusion

The HarmonyOS implementation is not yet fully identical to Android. It has completed the main usable feature loop for course schedule, DDL, and free classroom, with tests, build verification, and selected DevEco MCP integration checks. Remaining work is mostly hard parity gaps and detailed Android behavior audit.

## Recent Commits

- `68f3176 chore(git): ignore local reference artifacts`
- `7ae0854 docs(schedule): document Android parity plan`
- `d77128c test(debug): add integration debug runner cases`
- `8b11fbe feat(auth): improve school login session bootstrap`
- `509f064 feat(ddl): add deadline sync settings`
- `0800668 feat(free-classroom): add classroom availability page`
- `1dc0114 feat(schedule): align course timetable with Android`
- `00f2836 chore(app): wire Android parity features`

## Repository State Notes

- Current branch: `main`.
- `BIT101-Android/` is a read-only local Android reference and is ignored by git.
- `screenshot/` and `.mcp.json` are ignored local artifacts.
- The only intentionally uncommitted tracked file after the commits was `build-profile.json5`, containing local signing password changes. Do not commit that unless the user explicitly requests signing config cleanup.

## Course Schedule Status

Implemented:

- Course schedule settings model and persisted settings store.
- Settings page controls for current term, first day, period times, weekend visibility, border, today highlight, divider, current time line, and exam visibility.
- Local schedule domain under `services/schoolSchedule`:
  - `ScheduleModels.ts`
  - `ScheduleSettingsModels.ts`
  - `ScheduleLocalStore.ts`
  - `CourseScheduleRepository.ts`
  - `ScheduleDetailModels.ts`
- JSON-backed local storage for courses, exams, and custom schedules.
- ICS course events can be normalized into local `CourseScheduleItem`.
- Schedule grid consumes local settings and dynamic period count.
- Exam and custom schedule overlay plumbing.
- Custom schedule add/edit/delete dialogs.
- Course, exam, and custom detail dialogs.
- DevEco MCP integration debug cases:
  - `COURSE_SCHEDULE_SETTINGS`
  - `COURSE_SCHEDULE_SYNC`

Known gaps:

- `CourseScheduleRepository.refreshExams()` is still not implemented. This is the clearest hard gap versus Android.
- Native school course/exam API parity is not complete; course sync currently relies on existing BIT101/ICS flow normalized into the local model.
- System calendar insertion remains deferred.
- Some exact Android UI/interaction details still need side-by-side review.

## DDL Status

Implemented:

- DDL models and local store.
- Lexue calendar sync writes parsed events into the DDL store.
- DDL settings store and settings page.
- DDL list/detail display behavior updates.
- Unit tests:
  - `DdlLocal.test.ets`
  - `DdlSync.test.ets`

Known gaps / audit items:

- Compare Android sorting, retention, warning threshold, empty states, and filtering behavior one by one.
- Confirm whether Android has additional reminder/system-calendar behavior that HarmonyOS should mirror.

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

## Integration Debug Workflow

Relevant skill: `$harmonyos-integration-debug`.

Useful commands:

```powershell
$env:DEVECO_SDK_HOME='D:\Software\Huawei\DevEco Studio\sdk'
$env:OHOS_SDK_HOME='D:\Software\Huawei\DevEco Studio\sdk\default\openharmony'
& 'D:\Software\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' test --no-daemon
& 'D:\Software\Huawei\DevEco Studio\tools\node\node.exe' `
  'D:\Software\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.js' `
  --mode module -p module=entry@default assembleHap `
  -p buildMode=debug -p debuggable=true -p debugLine=false --no-daemon
```

To run a debug case:

1. Temporarily change `CURRENT_DEBUG_TARGET` in `entry/src/main/ets/debug/DebugRunner.ts`.
2. Build HAP.
3. Start app with DevEco MCP on `Mate 70 Pro` or the available emulator.
4. Read HiLog with tag `DebugIT_DebugRunner`.
5. Success requires a `SUMMARY ... failed=0`.
6. Restore `CURRENT_DEBUG_TARGET` to `DebugTarget.SCHOOL_NETWORK_PROBE` before committing or handing off.

Already verified during this work:

- `COURSE_SCHEDULE_SETTINGS`: `passed=1 failed=0`
- `COURSE_SCHEDULE_SYNC`: `passed=1 failed=0`
- `hvigorw.bat test --no-daemon`: passed
- debug `assembleHap`: passed

Existing warnings:

- Dependency metadata warning from hvigor.
- `ImageViewer.ets` warning for `ohos.permission.WRITE_IMAGEVIDEO`.

## Recommended Next Work

1. Implement real exam refresh parity.
   - Start from Android exam schedule repository/API/entity behavior.
   - Add TDD around parsing, persistence, and week overlay.
   - Add or extend DevEco debug case for exam refresh.

2. Perform detailed Android parity audit.
   - Course schedule settings defaults and UI text.
   - DDL sorting/filtering/warning behavior.
   - Free classroom default campus/building/date/period behavior.

3. Decide whether system calendar integration is in scope.
   - It was explicitly deferred in the plan because HarmonyOS calendar permission/API needs a separate device-backed spike.

## New Conversation Prompt

Copy this into a new chat:

```text
继续 D:\BIT101\BIT101HarmonyOS 的 HarmonyOS 安卓对齐工作。请先用相关 skills 再动代码：至少读取/遵守 arkts-development、test-driven-development、systematic-debugging、harmonyos-integration-debug、verification-before-completion；如果要做 UI 细节核对也用 frontend/UI 相关 skill。需要设备验证时用 DevEco MCP（build/start app/HiLog/UI tree/screenshot），不要只靠静态判断。

请先阅读：
- AGENTS.md
- docs/plans/2026-05-24-android-parity-analysis.md
- docs/plans/2026-05-25-course-schedule-android-parity.md
- docs/plans/2026-05-25-android-parity-handoff.md

当前结论：课表、DDL、空教室已经完成主要可用闭环，但不是完全对齐。最明确的硬缺口是课表考试刷新：CourseScheduleRepository.refreshExams() 仍未实现；课程同步目前是 BIT101/ICS 归一化，不是完整 Android 原生教务课程/考试 API。DDL 和空教室还需要逐项对照 Android 的默认值、排序、空态、错误态和交互细节。

本地 BIT101-Android/ 是只读参考代码，不要提交它；screenshot/ 和 .mcp.json 是本地产物。不要提交 build-profile.json5 里的本机签名密码变化，除非我明确要求。

最近提交：
- 68f3176 chore(git): ignore local reference artifacts
- 7ae0854 docs(schedule): document Android parity plan
- d77128c test(debug): add integration debug runner cases
- 8b11fbe feat(auth): improve school login session bootstrap
- 509f064 feat(ddl): add deadline sync settings
- 0800668 feat(free-classroom): add classroom availability page
- 1dc0114 feat(schedule): align course timetable with Android
- 00f2836 chore(app): wire Android parity features

请从“实现课表考试刷新与 Android 对齐”开始：先读 Android 参考实现，写/跑失败测试，再实现 HarmonyOS 解析、持久化、设置开关和课表 overlay。需要集成验证时临时切 DebugRunner.CURRENT_DEBUG_TARGET，跑完必须恢复为 DebugTarget.SCHOOL_NETWORK_PROBE。最终必须跑 hvigor test 和 assembleHap；如果使用 MCP debug case，HiLog DebugIT_DebugRunner 的 SUMMARY 必须 failed=0。
```
