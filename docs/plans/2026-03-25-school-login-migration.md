# School Login Migration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the old school-login HTML form flow with the newer service-driven CAS ticket flow while keeping BIT101 backend login separate.

**Architecture:** Introduce a new school-auth core that handles TGT/ST exchange, WebVPN host encoding, service resolution, and target bootstrap. Keep target-specific bootstrap logic outside the generic auth layer, then adapt existing Lexue login/session code to use the new core.

**Tech Stack:** HarmonyOS NEXT, ArkTS, existing `RcpSession`, manual debug cases under `entry/src/main/ets/debug/`

---

## Preconditions

- Read `docs/2026-03-25-school-login-analysis.md` before changing code.
- Treat `BIT101` backend auth and school auth as separate domains.
- Do not patch `BitSsoSession.ts` directly until the new auth core exists.

## Status Snapshot

Completed or largely completed:

- Task 1: school-auth shared types and error types
- Task 2: CAS ticket parsing and request layer
- Task 3: WebVPN host encoding and jump URL building
- Task 4: service resolution and network probing extraction
- Task 5: generic school-auth orchestration (`SchoolAuthService`)
- Task 7: `BitSsoSession` WebVPN path now delegates to the new school-auth core
- Task 8: debug coverage for:
  - WebVPN portal login
  - Lexue target login
  - business-level Lexue export verification

Partially completed:

- Task 9: `LoginPage` has been updated to use the new school-login success path for WebVPN and is temporarily forced to `webvpn` mode

Still pending:

- Task 6: formal target bootstrap abstraction is not fully extracted yet
- Task 8: timetable / backend-dependent school flows still need targeted verification
- Task 10: final verification and cleanup

### Task 1: Add school-auth core interfaces

**Files:**
- Create: `entry/src/main/ets/services/school/SchoolAuthTypes.ts`
- Create: `entry/src/main/ets/services/school/SchoolAuthErrors.ts`
- Modify: `AGENTS.md`

**Step 1: Define shared types**

Create:
- `SchoolLoginMode = 'inner' | 'webvpn'`
- `SchoolServiceTarget`
- `SchoolTicketGrant`
- `SchoolLoginResult`
- `SchoolBootstrapResult`

**Step 2: Define explicit error categories**

Add typed errors for:
- TGT failure
- ST failure
- service resolution failure
- WebVPN landing failure
- bootstrap failure

**Step 3: Document the new module**

Add one short note in `AGENTS.md` that future school-auth work belongs under `services/school/`.

**Step 4: Verify**

Read the new files and confirm the type names are consistent with `docs/2026-03-25-school-login-analysis.md`.

### Task 2: Implement CAS ticket flow

**Files:**
- Create: `entry/src/main/ets/services/school/SchoolCasClient.ts`
- Test: `entry/src/test/SchoolCasClient.test.ets`

**Step 1: Write pure helpers first**

Implement:
- TGT response parsing from `Location` header or HTML fallback
- ST response normalization

**Step 2: Add tests for parsing logic**

Cover:
- `201 + Location` header
- `201 + action="..."` HTML fallback
- invalid / missing TGT response

**Step 3: Implement CAS requests**

Add methods:
- `getTgt(username, password)`
- `getSt(tgtUrl, service)`

Use `https://sso.bit.edu.cn/cas/v1/tickets`.

**Step 4: Verify**

Run the relevant local tests. If local test execution is not available, at minimum run type/lint checks and inspect the code path manually.

### Task 3: Implement WebVPN host encoding and jump URL building

**Files:**
- Create: `entry/src/main/ets/services/school/WebvpnCodec.ts`
- Create: `entry/src/main/ets/services/school/WebvpnJumpBuilder.ts`
- Test: `entry/src/test/WebvpnCodec.test.ets`

**Step 1: Port `encodeVpnHost`**

Base it on the proven logic from:
- `D:\BIT101\BIT_reserve\bit-reserve-worker\worker.js`
- `D:\BIT101\BIT_reserve\debug_webvpn.py`

**Step 2: Build jump URL helpers**

Implement:
- portal jump URL
- target-service jump URL

**Step 3: Add unit coverage**

Test:
- host encoding output shape
- URL composition with existing query string
- URL composition without query string

**Step 4: Verify**

Cross-check encoded-host behavior against the reserve references.

### Task 4: Implement service resolution

**Files:**
- Create: `entry/src/main/ets/services/school/SchoolServiceResolver.ts`
- Create: `entry/src/main/ets/services/school/SchoolNetworkProbe.ts`
- Modify: `entry/src/main/ets/services/lexue/BitSsoAuto.ts`

**Step 1: Separate network probing from login**

Move `inner` vs `webvpn` detection into `SchoolNetworkProbe.ts`.

**Step 2: Resolve services dynamically**

Implement methods for:
- resolving WebVPN portal service from `/login?cas_login=true`
- resolving target-system service from redirect chains

**Step 3: Make `BitSsoAuto` depend on the new probe layer**

Keep its public API stable if possible:
- `createBitSsoSessionAuto(...)`

**Step 4: Verify**

Use logging or a debug case to confirm that resolved services are dynamic and not hardcoded.

### Task 5: Add generic school-login orchestrator

**Files:**
- Create: `entry/src/main/ets/services/school/SchoolAuthService.ts`
- Create: `entry/src/main/ets/services/school/SchoolSessionState.ts`

**Step 1: Build the orchestration layer**

Implement a top-level service that coordinates:
- mode detection
- TGT acquisition
- ST exchange
- jump URL creation
- initial landing

**Step 2: Return structured state**

Return a result that clearly distinguishes:
- `mode`
- portal login status
- target login status
- cookie/session snapshot

**Step 3: Keep business bootstrap out of this layer**

Do not embed Lexue-specific or reservation-specific warm-up here.

**Step 4: Verify**

Review public method signatures and ensure no Lexue-only assumptions remain.

### Task 6: Add target bootstrap abstraction

**Files:**
- Create: `entry/src/main/ets/services/school/SchoolBootstrap.ts`
- Create: `entry/src/main/ets/services/school/bootstrap/LexueBootstrap.ts`
- Create: `entry/src/main/ets/services/school/bootstrap/StuReserveBootstrap.ts`

**Step 1: Define bootstrap contract**

Each target bootstrap should:
- accept an authenticated school session
- perform target-specific landing / warm-up
- return structured verification data

**Step 2: Implement Lexue bootstrap**

Replace the current `ensureLexueSession()` assumption with a target bootstrap implementation.

**Step 3: Implement reservation bootstrap skeleton**

Even if unused in the app today, encode the warm-up steps documented in the reserve references:
- `getAppConfig`
- `changeAppRole`
- `setXgCommonAppRole`
- `i18n`

**Step 4: Verify**

Make sure target warm-up is no longer mixed into generic login code.

**Current note:**

Lexue bootstrap behavior now effectively exists inside the new WebVPN path, but it still lives partly in `BitSsoSession.ensureLexueSession()`. This should still be extracted cleanly later.

### Task 7: Refactor `BitSsoSession`

**Files:**
- Modify: `entry/src/main/ets/services/lexue/BitSsoSession.ts`
- Modify: `entry/src/main/ets/services/lexue/BitSsoWebvpn.ts`
- Modify: `entry/src/main/ets/services/storage/LexueCookieStore.ts`

**Step 1: Reduce `BitSsoSession` responsibility**

Refactor it into a Lexue-facing adapter over the new school-auth core.

**Step 2: Remove direct dependence on old HTML form parsing**

Any remaining `salt` / `execution` parsing should be justified and isolated. It should not remain the primary login path.

**Step 3: Preserve cookie persistence behavior**

Keep `restoreFromStorage()` and cookie dump persistence working across:
- `inner`
- `webvpn`

**Step 4: Verify**

Run the Lexue debug cases and confirm they still validate login and persistence behavior.

### Task 8: Add debug coverage for the new flow

**Files:**
- Create: `entry/src/main/ets/debug/SchoolCasTicketCase.ts`
- Create: `entry/src/main/ets/debug/WebvpnPortalLoginCase.ts`
- Create: `entry/src/main/ets/debug/SchoolTargetServiceCase.ts`
- Modify: `entry/src/main/ets/debug/DebugRunner.ts`

**Step 1: Add CAS ticket debug case**

Validate:
- TGT acquisition
- ST exchange

**Step 2: Add WebVPN portal login case**

Validate:
- service extraction
- encoded jump
- portal landing

**Step 3: Add target-system service case**

Validate second-stage service discovery and target landing.

**Step 4: Verify**

Run each case independently by switching `CURRENT_DEBUG_TARGET`.

### Task 9: Refactor login-page orchestration

**Files:**
- Modify: `entry/src/main/ets/pages/LoginPage.ets`
- Create: `entry/src/main/ets/services/auth/LoginCoordinator.ts`

**Step 1: Move orchestration out of the page**

Create a coordinator that:
- logs in to BIT101
- logs in to school auth
- optionally performs Lexue bootstrap

**Step 2: Return structured UI-friendly state**

Expose one result object instead of making `LoginPage` reason about multiple low-level session pieces.

**Step 3: Keep post-login sync separate**

Do not make calendar sync part of the core login contract. Treat it as post-login initialization.

**Step 4: Verify**

Manually test the login page and confirm error messages map cleanly to the new structured states.

**Current note:**

`LoginPage` has already been updated so that:
- BIT101 login stays separate
- school-login success is determined by the new `BitSsoSession` path
- WebVPN cookie is written back to `TokenStore`

Temporary constraint:
- `forceMode: 'webvpn'` is enabled in `LoginPage` because current `inner/webvpn` auto-detection is too weak for off-campus use

### Task 10: Final verification and documentation update

**Files:**
- Modify: `docs/2026-03-25-school-login-analysis.md`
- Modify: `AGENTS.md`

**Step 1: Update docs to reflect final architecture**

Document:
- current auth entrypoints
- debug cases
- migration completion status

**Step 2: Run verification**

At minimum:
- relevant local tests for pure helpers
- selected debug cases for ticket flow and Lexue login
- one end-to-end build

**Step 3: Record residual risks**

Explicitly note:
- campus-network assumptions
- WebVPN variability
- target-system-specific warm-up behavior

**Step 4: Commit**

Use small, scoped commits aligned to the task boundaries above.

---

Plan complete and saved to `docs/plans/2026-03-25-school-login-migration.md`. Two execution options:

**1. Subagent-Driven (this session)** - I dispatch fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** - Open new session with executing-plans, batch execution with checkpoints
