# 2026-06-09 School Login Migration Worklog

## Scope

This worklog records the school-login migration work completed on 2026-06-09, especially application-level login orchestration, Lexue target bootstrap extraction, and HarmonyOS DebugCase preparation.

## Completed

### 1. Extracted application login orchestration

Created:

- `entry/src/main/ets/services/auth/LoginCoordinator.ts`
- `entry/src/test/LoginCoordinator.test.ets`

Updated:

- `entry/src/main/ets/pages/LoginPage.ets`
- `entry/src/test/List.test.ets`
- `entry/src/main/ets/utils/Logger.ts`

`LoginCoordinator` now owns the login orchestration previously embedded in `LoginPage`:

- BIT101 backend login + WebVPN verify
- school SSO / Lexue login
- WebVPN cookie write-back
- free-classroom school session preparation
- Lexue calendar sync
- username persistence

`LoginPage` now focuses on UI state, invoking `LoginCoordinator.login()`, error display, and post-login navigation.

### 2. Extracted WebVPN Lexue bootstrap

Created:

- `entry/src/main/ets/services/school/SchoolBootstrap.ts`
- `entry/src/main/ets/services/school/bootstrap/LexueBootstrap.ts`
- `entry/src/test/LexueBootstrap.test.ets`

Updated:

- `entry/src/main/ets/services/lexue/BitSsoSession.ts`
- `entry/src/test/List.test.ets`
- `entry/src/main/ets/utils/Logger.ts`

The WebVPN Lexue target bootstrap logic was moved out of `BitSsoSession.ensureLexueSession()` and into `LexueBootstrap`.

`LexueBootstrap` is responsible for:

- logging into the WebVPN Lexue target via `loginWebvpnTarget()`
- requesting `calendar/export.php`
- rejecting failed status codes
- rejecting pages that are still school login pages
- parsing `sesskey`
- returning a structured `SchoolBootstrapResult`

`BitSsoSession` now delegates the WebVPN Lexue branch to `LexueBootstrap`. The inner-mode legacy path was left unchanged.

### 3. Added HarmonyOS DebugCase coverage for the new bootstrap abstraction

Created:

- `entry/src/main/ets/debug/LexueBootstrapCase.ts`

Updated:

- `entry/src/main/ets/debug/DebugRunner.ts`
- `entry/src/test/DebugRunnerContract.test.ets`

Added `DebugTarget.LEXUE_BOOTSTRAP` and registered `LexueBootstrapCase`.

The current debug target was switched to:

```ts
DebugTarget.LEXUE_BOOTSTRAP
```

The case performs:

1. WebVPN portal login through `SchoolAuthService`
2. Lexue target bootstrap through `LexueBootstrap`
3. assertions for success, `targetName === 'lexue'`, and parsed `sesskey`

## Verification Performed

### Unit tests

Command:

```powershell
$env:DEVECO_SDK_HOME='D:\Software\Huawei\DevEco Studio\sdk'
& 'D:\Software\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' test -p module=entry --no-daemon
```

Result:

- `BUILD SUCCESSFUL`

### Debug HAP build

Command:

```powershell
$env:DEVECO_SDK_HOME='D:\Software\Huawei\DevEco Studio\sdk'
$env:OHOS_SDK_HOME='D:\Software\Huawei\DevEco Studio\sdk\default\openharmony'
& 'D:\Software\Huawei\DevEco Studio\tools\node\node.exe' `
  'D:\Software\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.js' `
  --mode module -p module=entry@default assembleHap `
  -p buildMode=debug -p debuggable=true -p debugLine=false --no-daemon
```

Result:

- `BUILD SUCCESSFUL`

### Release app build

Command:

```powershell
$env:DEVECO_SDK_HOME='D:\Software\Huawei\DevEco Studio\sdk'
& 'D:\Software\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' assembleApp --mode project -p product=default -p buildMode=release --no-daemon
```

Result:

- `BUILD SUCCESSFUL`

Known warnings are unrelated to this migration:

- `ImageViewer.ets` permission warning for `WRITE_IMAGEVIDEO`
- existing `@Entry` export warnings in widget/map pages during release build

## Integration Verification Status

HarmonyOS DebugCase was added and the debug HAP builds successfully, but device-side execution was not completed.

Reason:

```powershell
& 'D:\Software\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe' list targets
```

Output:

```text
[Empty]
```

No emulator or device was visible to `hdc`, and DevEco MCP tools were not available in the current tool environment. Therefore the following closed-loop verification remains pending:

1. install/start app on device or emulator
2. run `DebugTarget.LEXUE_BOOTSTRAP`
3. read HiLog tag `DebugIT_DebugRunner`
4. confirm summary has `failed=0`

Expected pass signal:

```text
[DebugRunner] SUMMARY target=LEXUE_BOOTSTRAP total=1 passed=1 failed=0 ...
```

## Open Items

- Run `LEXUE_BOOTSTRAP` DebugCase on a real device/emulator and confirm HiLog summary.
- Decide whether `CURRENT_DEBUG_TARGET` should remain `LEXUE_BOOTSTRAP` for the next debug session or be reset to `NONE` / `SCHOOL_NETWORK_PROBE`.
- Add `StuReserveBootstrap.ts` skeleton if continuing Task 6.
- Record residual risks for Task 10:
  - inner-mode path still uses the old HTML form flow
  - WebVPN behavior depends on BIT school infrastructure and target-specific redirects
  - DebugCase depends on credentials in `debug/local.secret.ts`

