# Repository Guidelines

## Project Structure & Module Organization
This repository is a HarmonyOS app with a single application module, `entry`. App-level metadata and resources live in `AppScope/`. Project and module build settings are defined in `build-profile.json5`, `hvigorfile.ts`, `entry/build-profile.json5`, and `entry/hvigorfile.ts`.

Main source code is under `entry/src/main/ets/`:
- `pages/`: top-level ArkUI screens such as login, schedule, map, post, report, and settings.
- `components/`: reusable UI blocks grouped by feature (`gallery`, `schedule`, `deadline`, `map`, `web`, `settings`, `user`).
- `services/`: business logic for auth, BIT101 backend access, gallery, timetable, Lexue calendar, map, and storage.
  - `services/school/`: new shared school-auth protocol code such as CAS tickets, WebVPN encoding, service resolution, and future bootstrap logic.
- `core/`: lower-level network/session infrastructure such as `rcpSession`, cookie handling, and `bit101Session`.
- `utils/`: shared helpers and logging.
- `debug/`: manual integration debug cases for login, calendar sync, gallery API checks, and other network flows.

Resources are in `entry/src/main/resources/`. Local tests live in `entry/src/test/`, device tests in `entry/src/ohosTest/`, and mock files in `entry/src/mock/`.

## Architecture Notes
There are two major auth domains in this app:
- `BIT101` backend auth: used by community and backend-owned features. It stores `fake_cookie` and optional business token/user info in `TokenStore`.
- `School auth`: one school identity system with two access modes, not two separate business systems.
  - `inner`: direct campus-network SSO access.
  - `webvpn`: off-campus access via WebVPN.

`LoginPage.ets` currently orchestrates both domains. `AuthRepository` handles BIT101 login and WebVPN verification. `BitSsoAuto` + `BitSsoSession` handle school-side SSO / Lexue session establishment and auto-select `inner` vs `webvpn`.

For current WebVPN + Lexue behavior:
- successful business recovery is validated by `calendar/export.php` usability plus parsed `sesskey`
- WebVPN Lexue recovery does not currently rely on `MoodleSession` being present in the persisted cookie dump

For school-auth protocol changes and migration work, read:
- `docs/2026-03-25-school-login-analysis.md`
- `docs/plans/2026-03-25-school-login-migration.md`

## Build, Test, and Development Commands
Run commands from the repository root in a DevEco Studio terminal or a shell that has HarmonyOS tools available.

- `ohpm install`
  Installs dependencies from `oh-package.json5`.
- `hvigor assembleHap`
  Builds the `entry` module HAP.
- `hvigor clean`
  Clears generated outputs before a fresh rebuild.
- `hvigor test`
  Runs Hypium-based tests when the local Harmony toolchain is configured.

On this machine, `hvigor` may not be on `PATH`. The working fallback is the DevEco wrapper:

```powershell
& 'D:\Software\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' assembleApp --mode project -p product=default -p buildMode=release --no-daemon
```

If the wrapper reports `DEVECO_SDK_HOME` issues, set the SDK path explicitly for the current shell before building.

## Coding Style & Naming Conventions
Use 2-space indentation in `.ets`, `.ts`, and `.json5` files. Follow existing naming patterns:
- pages and components: `PascalCase` (`LoginPage.ets`, `PosterCard.ets`)
- services and utilities: `camelCase` or descriptive domain names (`authRepository.ts`, `tokenStore.ts`, `BitSsoSession.ts`)
- enums and shared types: `PascalCase`

Keep feature code close to its domain instead of creating large generic utility folders. Prefer extending existing service groups (`services/auth`, `services/lexue`, `services/gallery`, `services/jw`) over adding cross-cutting abstractions too early.

Linting is configured in `code-linter.json5` with `@typescript-eslint/recommended` plus performance and security rules. Avoid unsafe crypto primitives and keep an eye on ArkTS deprecation warnings during builds.

Logging must use `entry/src/main/ets/utils/Logger.ts` for app code, services, auth, networking, and debug flows. Do not introduce long-lived `console.log` style logging in production modules. Because `Logger` currently runs in `ALLOW_LIST` mode, any new module that needs visible logs must also be added to both `Logger.TARGET_MODULES` and `Logger.ALL_MODULES`.

## Testing Guidelines
Tests use `@ohos/hypium`. Use `*.test.ets` naming and place tests in:
- `entry/src/test/` for local tests
- `entry/src/ohosTest/` for device/integration-side tests

Automated tests cover only a small part of this codebase. For changes to login, calendar sync, cookies, or backend parsing, add regression coverage where possible and use the manual debug cases described below when full automation is impractical.

## Debug Workflow
`entry/src/main/ets/debug/` is a manual integration test toolbox. It is useful for login flows, cookie persistence, calendar export, and backend connectivity when unit tests are not enough.

How it works:
- Extend `DebugCase` and implement `readonly name` plus `run(): Promise<void>`.
- Use `logDebug()`, `logInfo()`, `logWarn()`, and `logError()` instead of ad-hoc `console` output.
- Register the case in `DebugRunner.ts`.
- Add a `DebugTarget` enum entry and a `createCase()` branch.
- Set `CURRENT_DEBUG_TARGET` to the case you want to run.
- Launch the app. `EntryAbility.onCreate()` calls `runCurrentDebugCase()` when debug mode is enabled.

Useful templates:
- `BitSsoSessionCase.ts`: school SSO session/login verification.
- `BitSsoLexueWebvpnCase.ts`: off-campus WebVPN + Lexue path.
- `LexueCookiePersistCase.ts`: cookie persistence and restore.
- `LexueCalendarSyncCase.ts`: full export -> parse -> persist pipeline.
- `GalleryServiceCase.ts`: BIT101 backend/gallery connectivity.

Secrets for debug cases belong in `debug/local.secret.ts` only. Never move test credentials into production pages, services, or committed config. Before shipping, set `CURRENT_DEBUG_TARGET` back to `DebugTarget.NONE`.

Starter template:

```ts
import { DebugCase } from './DebugCase';

export class MyFeatureCase extends DebugCase {
  readonly name = 'My feature debug';

  async run(): Promise<void> {
    this.logInfo('START');
    try {
      // arrange -> act -> verify
      this.logInfo('SUCCESS');
    } catch (e) {
      this.logError('FAILED', e);
    }
  }
}
```

## Commit & Pull Request Guidelines
Recent history follows Conventional Commit style with scopes, for example:
- `feat(gallery): 实现帖子和评论点赞功能`
- `feat(settings): 添加关于页面和账号设置页面`

Keep the format `<type>(<scope>): <summary>`. Common scopes in this repo include `gallery`, `settings`, `me`, `comments`, and `poster`.

Pull requests should include:
- a short description of user-visible behavior changes
- affected pages/services
- test or debug evidence
- screenshots or recordings for UI work
- linked issue/task when available

## Security & Configuration Tips
Do not commit real signing material, test credentials, cookies, or local environment overrides. Treat `local.properties` and signing entries in `build-profile.json5` as machine-specific.

For local build troubleshooting:
- verify `sdk.dir` in `local.properties`
- verify `DEVECO_SDK_HOME` / Harmony SDK paths if `hvigorw` fails
- keep `debug/local.secret.ts` out of shared or production-facing flows
