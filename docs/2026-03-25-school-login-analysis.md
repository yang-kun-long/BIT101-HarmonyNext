# School Login Analysis

## Goal
This document compares the current HarmonyOS school-login implementation with the newer login flow found in:

- `D:\BIT101\BIT_reserve\bit-reserve-worker\worker.js`
- `D:\BIT101\BIT_reserve\[BIT AutoLogin] 一键登录北理工统一身份认证\[BIT AutoLogin] 一键登录北理工统一身份认证.user.js`
- `D:\BIT101\BIT_reserve\debug_webvpn.py`

The purpose is to align terminology, identify protocol changes, and define a migration baseline before changing ArkTS code.

## Current HarmonyOS Flow
Relevant files:
- `entry/src/main/ets/services/lexue/BitSsoSession.ts`
- `entry/src/main/ets/services/lexue/BitSsoWebvpn.ts`
- `entry/src/main/ets/services/lexue/BitSsoAuto.ts`
- `entry/src/main/ets/pages/LoginPage.ets`

Current school-login behavior is still based on the older form-submit model:

1. Decide mode with `BitSsoAuto`:
   - `inner`: direct campus access
   - `webvpn`: off-campus via WebVPN
2. For `inner`, request `https://sso.bit.edu.cn/cas/login`
3. Parse login page HTML for:
   - `salt`
   - `execution`
4. Encrypt password and submit the login form back to `https://sso.bit.edu.cn/cas/login`
5. For `webvpn`, request a fixed WebVPN CAS URL, parse the same page fields, then submit the login form
6. After that, call Lexue entry URLs to verify whether SSO really worked

This flow assumes the school login page is the primary integration point.

## New School Login Flow
The reserve worker, userscript, and Python script all converge on a newer model:

1. Obtain a `service`
2. Create a TGT with:
   - `POST https://sso.bit.edu.cn/cas/v1/tickets`
3. Exchange TGT for an ST:
   - `POST <tgtUrl>` with `service=<...>`
4. If the target is behind WebVPN, encode the target host with `encodeVpnHost`
5. Construct a WebVPN jump URL and append `ticket=<ST>`
6. Follow redirects until the target system lands successfully

This means the core school-auth protocol is now ticket-based:

- TGT = ticket-granting ticket
- ST = service ticket
- `service` drives where authentication is bound

The userscript is the clearest minimal reference for the new protocol. It logs in by:

1. reading `service` from the current page URL
2. calling `/cas/v1/tickets`
3. requesting an ST for that service
4. redirecting to the final URL with `ticket=...`

## WebVPN-Specific Changes
The new WebVPN flow is more than "submit credentials through a different login page".

From `debug_webvpn.py` and `worker.js`, the actual flow is:

1. Probe `https://webvpn.bit.edu.cn/login?cas_login=true`
2. Read the redirect target and extract the WebVPN portal `service`
3. Get TGT from CAS REST API
4. Get ST for the WebVPN portal service
5. Build a WebVPN jump URL
6. Encrypt the destination hostname with `encodeVpnHost`
7. Land on the WebVPN portal and confirm WebVPN cookies are established

Important observation:
- the hostname encryption step is part of the real login path now
- the encrypted host is not static for every target system
- different business systems can require different encoded hosts

This is a protocol-level difference from the current ArkTS implementation, which still hardcodes one WebVPN CAS login URL and submits an HTML form.

## Second-Level Login for Business Systems
The reserve scripts show another important behavior: logging into WebVPN is not always enough.

For the `stu.bit.edu.cn` reservation system:

1. Enter the target business path under WebVPN
2. Get redirected again to a CAS login URL
3. Extract a second `service`
4. Reuse the same TGT to exchange a second ST
5. Build a second WebVPN jump URL
6. Land in the target system

This means the login chain is now:

- CAS auth
- WebVPN portal auth
- target business-system auth

The target system is not always covered by the first successful WebVPN landing.

## Session Warm-Up Requirement
`debug_webvpn.py` and `worker.js` both show that a "successful login" still may not mean the business API is ready.

For the reservation system, these warm-up requests are required after landing:

- `.../sys/swpubapp/indexmenu/getAppConfig.do`
- `.../sys/funauthapp/api/changeAppRole/...`
- `.../sys/swpubapp/userinfo/setXgCommonAppRole.do`
- `.../i18n.do`

Without these steps, the system may still respond with messages like:
- `会话已经过期`

This is the strongest evidence that the new school-login model is now:

1. authenticate
2. land
3. warm up session
4. then call business APIs

## What Has Changed vs Current ArkTS Code
The current ArkTS school-login implementation lags behind in several ways.

### 1. Old form-submit model vs new ticket model
Current ArkTS:
- GET login page
- parse `salt` / `execution`
- POST login form

New logic:
- obtain `service`
- `POST /cas/v1/tickets`
- exchange TGT -> ST
- jump using `ticket`

### 2. Fixed WebVPN login URL vs dynamic service extraction
Current ArkTS uses a fixed WebVPN CAS entry URL.

New logic derives the target service dynamically from redirect responses and current targets.

### 3. Single-stage login assumption vs multi-stage service login
Current ArkTS mainly assumes:
- school login succeeded
- then Lexue can be accessed

New logic shows:
- portal service may succeed
- target system may still require another CAS/ST exchange

### 4. Minimal post-login verification vs explicit warm-up
Current ArkTS verifies mainly by fetching Lexue entry pages or export endpoints.

New logic explicitly warms up the target system session before calling business APIs.

## Progress Update
As of March 25, 2026, the repository has already migrated a meaningful part of the WebVPN + Lexue path to the newer ticket flow.

Implemented and verified:

- CAS ticket exchange via `SchoolCasClient`
- WebVPN host encoding via `WebvpnCodec`
- WebVPN jump URL building via `WebvpnJumpBuilder`
- dynamic portal and target-service resolution
- `SchoolAuthService` orchestration for:
  - WebVPN portal login
  - Lexue target login
- `BitSsoSession` WebVPN mode now delegates to the new school-auth core instead of the old fixed WebVPN form flow
- business-level Lexue validation:
  - `calendar/export.php`
  - `generateurl`
  - `subscribeUrl`
  - ICS fetch returning valid `BEGIN:VCALENDAR`

Current known state:

- `webvpn` mode for Lexue is working and business-validated
- `inner` mode is still using the older implementation and should be considered pending migration
- `LoginPage` has been temporarily forced to `webvpn` mode for school login to avoid false `inner` detection in off-campus environments
- timetable verification is not complete yet because `TimetableRepository` still has its own local bug in debug logging

## Likely Impact on This Repository
The affected area is not all auth code equally. The highest-risk files are:

- `entry/src/main/ets/services/lexue/BitSsoSession.ts`
- `entry/src/main/ets/services/lexue/BitSsoWebvpn.ts`
- `entry/src/main/ets/services/lexue/BitSsoAuto.ts`
- any future school-business modules that depend on direct SSO assumptions

The BIT101 backend login flow is a separate auth domain and is not directly replaced by this change.

The parts most likely to break or become flaky are:

- off-campus school login
- WebVPN-based Lexue access
- any new school business system integration that needs ticket-based access

In practice, the highest remaining risk is now:

- features that still depend on `webvpn_cookie` and older backend expectations, especially timetable-related flows
- `inner` auto-detection and direct-login behavior

## Recommended Migration Strategy
Do not patch the current ArkTS code incrementally without first refactoring the mental model.

Recommended migration order:

1. Extract a separate "school ticket auth" design
   - TGT creation
   - ST exchange
   - service discovery
   - WebVPN jump URL building
   - encoded host generation

2. Separate "authentication" from "business-system bootstrap"
   - auth = get valid school session
   - bootstrap = make target system actually usable

3. Keep target-specific warm-up outside the generic auth core
   - Lexue bootstrap should be one module
   - reservation-system bootstrap should be another

4. Preserve mode abstraction
   - `inner`
   - `webvpn`
   but implement both on top of the newer ticket-based model where needed

5. Add debug cases before replacing production code
   - one case for TGT/ST only
   - one case for WebVPN portal landing
   - one case for target-system second-stage login
   - one case for warm-up verification

## Suggested New Architecture
At a high level, the future structure should look like this:

- `SchoolAuthService`
  - `getTgt(username, password)`
  - `getSt(tgtUrl, service)`
  - `buildJumpUrl(service, ticket)`
  - `encodeVpnHost(host)`

- `SchoolTargetResolver`
  - resolve WebVPN portal service
  - resolve target-system service
  - resolve direct vs WebVPN mode

- `SchoolSessionBootstrap`
  - Lexue bootstrap
  - reservation bootstrap
  - other school-business bootstrap

- `LoginCoordinator`
  - orchestrates `BIT101` auth
  - orchestrates school auth
  - keeps UI-level success/failure state simple

## Bottom Line
The current HarmonyOS implementation is still centered on the old CAS HTML form flow. The newer reserve scripts show that the real school-login protocol has moved to:

- service-driven CAS REST ticket exchange
- WebVPN host encoding
- target-system second-stage service login
- explicit post-login session warm-up

This should be treated as a protocol update, not just a bugfix.

For this repository specifically, the WebVPN + Lexue path is already partially migrated and validated. The next engineering step is to finish application-level adoption and then validate downstream consumers such as timetable fetching.
