# BIT101 HarmonyOS Android Parity Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 以 Android `6d79f18`（1.4.0）为当前产品参考，修复 HarmonyOS 版的错误实现和发布阻断项，再补齐消息、关注、话廊设置、更新与外观等仍有用户价值的差距。

**Architecture:** 保留 HarmonyOS 现有 `BIT101 backend + school inner/webvpn + JXZX` 三域认证、ArkUI 页面和本地 JSON/preferences 存储，不照搬 Android 的 Hilt/Room/Compose 分层。新增能力优先落入现有 `services/<domain>`、`services/storage` 和对应页面；登录恢复必须建立在 HarmonyOS 安全凭据存储上，禁止明文持久化密码。

**Tech Stack:** ArkTS、ArkUI、RCP/现有网络封装、`@ohos.data.preferences`、HarmonyOS HUKS/安全凭据能力、Hypium、`devecocli`、现有 DebugCase 工具箱。

---

## 1. 审计基线

- Android 参考：`BIT101-Android/`，`main@6d79f18`，版本 `1.4.0`，2026-08-06。
- HarmonyOS：主仓库 `main@7f59c96`，另有用户本地 `build-profile.json5` 修改，本计划不得覆盖该修改。
- 本轮对照范围：页面/导航、认证与会话、BIT101 Web、话廊、用户资料、消息、课表/考试/DDL/空教室、地图、设置、版本更新、日志、发布配置和测试。
- 旧结论 `docs/plans/2026-05-29-android-parity-convergence-audit.md` 仅继续作为课表工具证据；其他领域以本文件和最新 Android 源码为准。
- 本轮是静态源码审计。实现各批次后仍需真机验证登录、Web、消息和文件分享。

## 2. 当前差距总表

| 领域 | HarmonyOS 当前状态 | Android 1.4.0 | 结论 |
| --- | --- | --- | --- |
| 学校认证基础 | 已有 inner/WebVPN 自动选择、CAS ticket、Cookie 持久化、Lexue/JXZX 会话 | 统一迁移到 BIT-Login 和 `SchoolCookieStore` | 基础能力已具备，不应整体重写 |
| 短信二次验证 | 只有固定的“WebVPN 验证码”输入框；学校 SSO 没有回调式 SMS challenge | 全局 `SmsCodeRequestHub` + 验证码对话框 | **P0 缺失，开启二次验证的用户可能无法登录** |
| 登录恢复 | 健康检查失败可能直接清空状态；无安全凭据自动修复；缺少并发互斥 | 加密保存凭据、自动刷新、互斥、401 后单次重试、按失败类型保留/清理 | **P0 可靠性差距** |
| 登录原子性 | BIT101 登录成功后学校登录失败时可能遗留部分状态 | 两端都成功后才提交最终状态，失败清理部分状态 | **P0 状态一致性差距** |
| BIT101 Web 登录注入 | `WebPage` 读取从未初始化的 `AppStorage.fakeCookie/studentId/password` | 从真实登录存储读取并注入 WebView | **P0，网页可能仍是未登录状态** |
| 用户资料编辑 | 昵称、签名用 `setTimeout` 模拟成功；头像只换成本地 URI | 上传图片并 `PUT /user/info`，成功后刷新状态 | **P0，当前成功提示会误导用户** |
| 原生消息 | 无消息页、无未读数 | 点赞/评论/关注/系统四类消息，分页、刷新、角标和目标跳转 | **P1 缺失** |
| 关注/粉丝 | 能关注/取关，显示数量；数量不可进入列表 | 我的关注/粉丝分页列表，点击进入用户页 | **P1 缺失** |
| 话廊主流程 | 推荐/关注/最新/最热、搜索、发布/编辑、图片、评论、点赞、删除、举报均已具备 | 同类主流程 | 主链路基本对齐 |
| 话廊个性化 | 无机器人过滤、隐藏用户/匿名用户、严格模式、横滑开关 | 完整本地设置和列表/评论过滤 | **P1 缺失** |
| 课程表/考试/自定义日程 | 原生教务课表、考试、自定义日程、显示设置和系统日历同步均已实现 | 同类能力 | 已对齐；系统日历批量同步部分能力更强 |
| DDL | Lexue 同步、本地 CRUD、完成状态、排序/保留、设置已实现并有设备证据 | 同类能力 | 已对齐，不再追差 |
| 空教室 | 校区、楼宇、实时状态、排序、缓存、隐藏忙碌、阈值均已实现 | 同类能力 | 已对齐，不再追差 |
| 页面设置 | 顺序/隐藏可生效；主页可保存但 `Index` 启动固定进课表 | 同样计算了 `initialPage`，但当前 `NavHost` 仍固定从 Schedule 启动 | **P1 两端共有功能错误；鸿蒙不必继续复制该缺陷** |
| 外观设置 | 开关仅改页面内 `@State`，主题切换处有 TODO，重启丢失 | 动态主题、深浅模式、自动旋转均持久化并应用 | **P1 功能错误** |
| 版本更新 | 1.5 秒后固定提示“最新版本”，自动检查开关不持久化 | `/version`、最低版本、忽略版本、强制更新 | **P1 缺失/误导** |
| 日志反馈 | Logger 白名单 + 多处 `console.*`；无导出入口 | 导出本应用 logcat 并系统分享 | **P1 支持能力差距** |
| 地图 | Web/Leaflet 瓦片图、校区跳转、视口记忆；滑杆直接改地图 zoom | 原生 MapCompose、7 天/10 MB 瓦片缓存、独立渲染倍率 | **P2，主流程可用但语义/缓存不同** |
| Web 容器 | 主 Web 支持 JS、localStorage、文件选择和外链；通用 Web 能力较弱 | 保存 WebView 状态、主题/会话注入、文件选择和外链 | **P2，需统一容器与恢复状态** |
| 发布状态 | Debug 恒为 true，当前自动运行 `SCHOOL_NETWORK_PROBE`；包名仍为 `com.example...`，版本 1.0.0，关于页残留 Android 文案/链接 | 正常发布元数据 | **P0 发布阻断** |
| 自动化测试 | 课表/DDL/空教室/认证纯逻辑覆盖较好；用户、消息、设置、更新几乎无覆盖 | 最新登录恢复有集中回归测试 | 新功能必须补测试，不能回退到只靠 DebugCase |

## 3. 优先级与依赖

执行顺序不是按页面数量，而是按风险和依赖：

1. **P0-A 发布态和真实行为**：关闭启动调试、修复产品元数据、把账号资料编辑从模拟改为真实请求。
2. **P0-B 认证可靠性**：Web 会话桥接、登录事务、短信 challenge、安全凭据和自动修复。
3. **P1-A 社区闭环**：消息中心、未读角标、关注/粉丝列表、话廊屏蔽设置。
4. **P1-B 设置兑现**：更新检查、日志导出、主页设置、主题与旋转真正生效。
5. **P2 体验和维护**：地图缓存/倍率语义、统一 Web 容器、补齐跨域集成与真机回归。

`P0-B` 中的安全凭据设计是自动恢复的前置；在它完成前不得通过普通 preferences 或 AppStorage 保存明文密码。

## 4. Todo

### Task 1 [P0]: 清理发布阻断和产品身份

**Files:**

- Modify: `entry/src/main/ets/debug/DebugRunner.ts`
- Modify: `entry/src/main/ets/entryability/EntryAbility.ets`
- Modify: `entry/src/main/ets/utils/Logger.ts`
- Modify: `AppScope/app.json5`
- Modify: `entry/src/main/ets/pages/settings/Settings.ets`
- Modify: `entry/src/main/ets/pages/settings/AboutPage.ets`
- Test: `entry/src/test/DebugRunnerContract.test.ets`

**Todo:**

- [x] 先在 `DebugRunnerContract.test.ets` 增加失败用例：默认发布配置不得执行任何 DebugCase。
- [x] 导出纯函数 `shouldRunDebugTarget(target, isDebugBuild)`；只有 debug 构建且 target 非 `NONE` 时返回 true。
- [x] 将 `CURRENT_DEBUG_TARGET` 恢复为 `DebugTarget.NONE`，移除 `EntryAbility.isDebugMode(): true` 这一恒真实现。
- [x] 将 Logger 的调试开关和筛选模式与构建类型绑定；生产包保留 error/fatal，禁止 verbose 网络/认证日志。
- [ ] 确认正式 HarmonyOS `bundleName` 后替换 `com.example.bit101harmonyos`；同步真实 `versionCode/versionName`，不直接照抄 Android versionCode。
- [x] 修正设置页“关于BIT101-Android”、Android GitHub 链接和 Android 品牌文案为 HarmonyOS 项目实际信息。
- [x] 运行单测并用 `devecocli build --build-mode release` 验证 release HAP 不触发 `DebugRunner` 日志。

**Progress (2026-08-31):** 门禁测试、本地测试、debug/release 构建已通过；release 产物元数据为 `buildMode=release, debug=false`。已在 `Huawei_Phone (127.0.0.1:5555)` 用 `devecocli run --build-mode release --uninstall --skip-build` 完成冷启动，HiLog 没有 `DebugRunner START`，也没有应用崩溃日志。现有调试签名 profile 明确绑定 `com.example.bit101harmonyos`，正式包名迁移必须先确定目标 bundleName 并重新申请匹配的签名 profile；当前真实鸿蒙版本仍为 `1.0.0`，未照抄 Android 版本号。

**Acceptance:** 冷启动不发起 debug 网络探测；release 日志中没有 `DebugIT_DebugRunner START`；应用包名、版本和关于页都指向 HarmonyOS 产品。

**Commit:** `fix(app): remove release debug behavior`

### Task 2 [P0]: 把账号资料编辑接到真实后端

**Files:**

- Modify: `entry/src/main/ets/services/user/UserModels.ts`
- Modify: `entry/src/main/ets/services/user/userRepository.ts`
- Modify: `entry/src/main/ets/pages/settings/AccountPage.ets`
- Reuse: `entry/src/main/ets/services/gallery/GalleryService.ts`
- Create: `entry/src/test/UserProfile.test.ets`

**Todo:**

- [x] 为 `PUT /user/info` 定义 `nickname`、`motto`、`avatar_mid` 请求模型和严格响应处理。
- [x] 为 `UserRepository` 增加可注入 HTTP 依赖，先写请求路径、方法、snake_case body 的失败测试。
- [x] 实现 `updateUserInfo()`；非 2xx 和网络错误抛出可展示错误；按 Android `Response<Unit>` 契约接受 2xx 空正文。
- [x] 头像沿用 `GalleryService.uploadImage()` 获取 `mid`，上传成功后再调用 `updateUserInfo()`。
- [x] 删除昵称/签名中的 `setTimeout` 模拟逻辑；只有服务器确认成功后才更新页面和 `TokenStore.user_info`。
- [x] 失败时保持旧头像/昵称/签名，显示“更新失败”并允许重试。
- [x] 把 `handlePickAvatar()` 的 `console.error` 改成已注册的 `Logger` 模块。
- [ ] 真机修改三项资料，重新进入“我”和账号页确认服务端值一致。

**Progress (2026-08-27):** Android 参考目录已快进到 `main@6d79f18`。已新增 `UserProfile.test.ets`，覆盖 `PUT /user/info` 路径、方法、三项 snake_case body、`fake-cookie`、2xx 空响应、非 2xx、断网和缺登录态；完整本地测试、debug/release 构建均通过。头像上传现在接受完整 2xx 并销毁请求对象。当前 `devecocli device list` 无活动设备，三项资料和杀进程后的服务端一致性仍待真机验收。

**Acceptance:** 杀进程重启后资料仍为新值；断网修改不会提示成功；头像上传失败不会把本地 URI 当成远端头像持久化。

**Commit:** `fix(account): persist profile edits to backend`

### Task 3 [P0]: 修复 BIT101 Web 会话桥接和注入安全

**Files:**

- Modify: `entry/src/main/ets/components/web/WebPage.ets`
- Modify: `entry/src/main/ets/pages/ForumPage.ets`
- Modify: `entry/src/main/ets/pages/WebBrowserPage.ets`
- Modify: `entry/src/main/ets/services/storage/tokenStore.ts`
- Create: `entry/src/main/ets/components/web/WebSessionModel.ts`
- Create: `entry/src/test/WebSessionModel.test.ets`

**Todo:**

- [x] 写失败测试证明 `fake_cookie` 必须来自 `TokenStore`，不能依赖未初始化的 `AppStorage.fakeCookie`。
- [x] 新增 `WebSessionModel`，从真实 TokenStore 加载用户名、fake cookie 和可选安全凭据状态。
- [x] 使用 `JSON.stringify`/结构化参数生成注入脚本，禁止把 cookie、学号或密码直接拼进 JavaScript 字符串。
- [x] 页面开始加载前准备会话，页面完成后注入 `localStorage.store.fake_cookie`，再触发一次受控 reload 或站内状态刷新。
- [x] 无安全凭据时禁用成绩页密码自动填充，不使用空的 `AppStorage.password` 伪装此能力。
- [x] 合并 `WebPage` 与 `WebBrowserPage` 的公共能力：文件选择、外链判定、后退、加载/错误状态和统一域名策略。
- [ ] 真机验证 `https://bit101.cn` 登录态、发帖文件选择、外链打开和成绩页行为。

**Progress (2026-08-27):** 已新增 `WebSessionModel.test.ets`，覆盖 TokenStore 会话来源、恶意特殊字符安全编码、登出清理、无密码注入、可信域名防 substring 绕过和通用浏览器同源策略。`WebPage` 在会话准备后才创建 WebView，仅向 HTTPS `bit101.cn` 注入并受控刷新一次；`WebBrowserPage` 已复用相同容器。完整本地测试、debug/release 构建通过；当前无活动设备，登录态、文件选择、外链与成绩页仍待真机验收。

**Acceptance:** 登录后首次打开“网”即为已登录状态；特殊字符不会破坏注入脚本；登出后 Web localStorage/cookie 同步清理。

**Commit:** `fix(web): bridge persisted login into web sessions`

### Task 4 [P0]: 让登录成为原子事务并区分失败类型

**Files:**

- Modify: `entry/src/main/ets/services/auth/LoginCoordinator.ts`
- Modify: `entry/src/main/ets/services/auth/bit101LoginFlow.ts`
- Modify: `entry/src/main/ets/services/auth/authRepository.ts`
- Modify: `entry/src/main/ets/services/auth/LoginHealthService.ts`
- Modify: `entry/src/main/ets/services/storage/tokenStore.ts`
- Modify: `entry/src/main/ets/services/storage/LexueCookieStore.ts`
- Modify: `entry/src/main/ets/services/storage/SchoolCookieStore.ts`
- Test: `entry/src/test/LoginCoordinator.test.ets`
- Test: `entry/src/test/LoginHealth.test.ets`

**Todo:**

- [x] 写失败测试：学校登录失败、BIT101 登录失败、日历同步失败、教务预热失败分别应留下什么状态。
- [x] 将认证结果先保存在内存 staging object；BIT101 和 school 核心域均成功后一次性提交 Token/Cookie/username。
- [x] 核心域失败时回滚本次新增状态，但不误删登录前已有且经验证有效的会话。
- [x] 为错误增加 `invalid_credentials`、`sms_required`、`captcha_required`、`rate_limited`、`network_transient`、`server_transient` 分类。
- [x] 修改 `LoginHealthService.checkLogin()`：临时网络/DNS/5xx 只能报告 unknown/degraded，不能清空登录态。
- [x] 只有明确的 401/凭据失效或用户主动登出才清理对应域；JXZX 异常不得连带清空 BIT101/Lexue。
- [x] 给登录、健康检查和刷新增加单实例互斥，防止页面并发触发重复登录和状态覆盖。
- [x] 保留当前“日历同步/教务预热失败不阻断核心登录”的产品策略，并在测试中固化。

**Progress (2026-08-27):** 已完成 staging 登录结果、核心会话一次性提交与回滚、失败类型分类、保守健康检查清理和登录/健康检查 single-flight；`LoginPage` 现在只显示安全失败文案并按失败类型记录日志，不再展示原始异常或响应内容。新增/更新登录回归测试、完整本地测试、debug/release 构建均通过。当前无活动设备，真实账号登录、断网保留会话和跨存储故障回滚仍待真机/故障注入验收。

**Acceptance:** 任一登录步骤失败后不存在半登录假状态；断网点“检查登录状态”不会把用户登出；并发检查只发起一次恢复流程。

**Commit:** `fix(auth): make multi-domain login transactional`

### Task 5 [P0]: 支持学校短信二次验证

**Files:**

- Modify: `entry/src/main/ets/services/school/SchoolAuthService.ts`
- Modify: `entry/src/main/ets/services/lexue/BitSsoSession.ts`
- Modify: `entry/src/main/ets/services/lexue/BitSsoAuto.ts`
- Modify: `entry/src/main/ets/pages/LoginPage.ets`
- Modify: `entry/src/main/ets/pages/Index.ets`
- Create: `entry/src/main/ets/services/auth/SmsChallengeCoordinator.ts`
- Create: `entry/src/main/ets/services/school/SchoolSmsProtocol.ts`
- Create: `entry/src/main/ets/components/auth/SmsVerificationDialog.ets`
- Create: `entry/src/test/SmsChallengeCoordinator.test.ets`
- Create: `entry/src/test/SchoolSmsProtocol.test.ets`
- Extend debug: `entry/src/main/ets/debug/LoginCoordinatorCase.ts`

**Todo:**

- [x] 先对照 Android `SchoolLoginService.kt` 和 BIT-Login v4 行为，记录学校 SSO 触发 SMS 时的请求、掩码手机号、purpose、提交与取消协议；没有抓到协议证据前不猜接口。
- [x] 用可挂起的 `SmsChallengeCoordinator` 建立单个 pending request，写提交、取消、重复提交和并发请求测试。
- [x] 学校浏览器式 CAS 登录遇到 SMS challenge 时上抛结构化请求并等待输入，而不是要求用户预先填写固定验证码字段；inner 与 WebVPN 共用该协议。
- [x] 在应用根层挂载全局验证码对话框，使前台登录和后台恢复共用同一交互。
- [x] 区分 WebVPN 图片验证码与学校 SMS 验证码，重命名当前 LoginPage 字段和提示，避免概念混淆。
- [x] 后台静默恢复遇到 SMS 时返回 `interaction_required`，只在前台允许弹窗。
- [x] 用测试账号完成一次需要 SMS 的 WebVPN 设备登录，并验证 Lexue 日历导出可用。
- [ ] 验证取消短信对话框后不留下 BIT101、学校或 Lexue 部分会话。
- [ ] 验证错误短信验证码有明确反馈且允许安全重试。

**Acceptance:** 需要二次验证的账号可完成登录；取消、安全超时和错误验证码都有明确反馈；后台任务不会无界等待 UI。

**Progress (2026-08-31):** 已按 Android 与 BIT-Login 最新源码实现 `getPhoneNumberByUserId -> sendSmsCode -> checkToken -> 二次 CAS 表单`，混合加密使用 HarmonyOS `CryptoArchitectureKit` 的 `RSA2048|PKCS1` 与现有 AES/ECB/PKCS7；inner 和 WebVPN 首登均改走可识别 challenge 的浏览器式 CAS 协议。新增 coordinator 与协议测试，覆盖安全字段、提交、取消、空值、重复结算、并发拒绝、host 栈、超时、非交互快速失败、HTML 解析、相对 WebVPN callback、旧验证码仍有效响应、payload/form 构造和 CAS 401 失败分类；`Index` 根页和 `LoginPage` 均挂载全局宿主，UI 只接收掩码手机号，`LoginCoordinatorCase` 也会安全提示当前待输入的 purpose/掩码手机号。本地 `hvigorw test --no-daemon`、`devecocli build --build-mode debug`、`devecocli build --build-mode release` 均通过。2026-08-31 在 `Huawei_Phone (127.0.0.1:5555)` 运行普通 `LOGIN_COORDINATOR`，结果为 `bit101Ok=true`、`schoolOk=true`、`mode=inner`；随后在设备通过代理访问 WebVPN，并用启用 SMS 的测试账号完成真实短信输入，`BIT_SSO_LEXUE_WEBVPN` 日志为 `SUMMARY ... passed=1 failed=0 duration=6178ms`，`isFullyLoggedIn=true`，且成功导出以 `BEGIN:VCALENDAR` 开头的日历。另一次不输入验证码的运行在 120 秒后返回 `SmsChallengeTimeoutError`，验证了安全超时。验收中发现 `0x0 Blank` 宿主会被 ArkUI 裁掉，已改为透明、不可命中的稳定挂载节点。当前仍缺取消后无部分会话以及错误验证码的设备证据，因此 Task 5 尚不能整体勾选。

**Commit:** `feat(auth): support school sms verification`

### Task 6 [P0/P1]: 安全凭据与过期会话自动恢复

**Files:**

- Create: `entry/src/main/ets/services/storage/SchoolCredentialStore.ts`
- Create: `entry/src/main/ets/services/auth/LoginRefreshCoordinator.ts`
- Modify: `entry/src/main/ets/services/auth/LoginCoordinator.ts`
- Modify: `entry/src/main/ets/services/auth/LoginHealthService.ts`
- Modify: `entry/src/main/ets/core/network/bit101Session.ts`
- Modify: `entry/src/main/ets/pages/settings/AccountPage.ets`
- Create: `entry/src/test/LoginRefreshCoordinator.test.ets`
- Create: `entry/src/test/SchoolCredentialStoreContract.test.ets`

**Todo:**

- [ ] 先用 HarmonyOS 官方安全存储/HUKS 能力完成最小 spike：密钥不可导出，preferences 中只保存密文、IV/nonce 和版本。
- [ ] 实现 `save/get/clear`；凭据不得进入 AppStorage、普通 preferences、日志、dumpSnapshot 或备份。
- [ ] 登录页明确告知并提供“安全保存用于自动恢复”开关；默认策略由产品确认，不能隐式降级成明文。
- [ ] `LoginRefreshCoordinator` 实现 `SUCCESS/FAILED/INTERACTION_REQUIRED/BUSY`，并发时复用或快速返回。
- [ ] 网络层仅在明确认证失败时触发一次刷新并重试一次，禁止无限重试。
- [ ] 错误密码清凭据；网络超时、限流、服务端临时错误和 SMS 需求保留凭据。
- [ ] 登出同时清理凭据、BIT101 token、学校 Cookie 和 Web 会话数据。
- [ ] 将 `debug/local.secret.ts` 及其 DebugCase 依赖移入真正的 debug-only source set 或构建期生成流程，确保 Release HAP 不包含测试凭据字面量（本轮已完成 Release 运行时门禁验证，凭据隔离实现延期）。

**Acceptance:** 会话过期后普通 API 操作最多自动修复一次；设备存储中搜不到明文密码；登出后无法恢复旧凭据。

**Commit:** `feat(auth): securely restore expired sessions`

### Task 7 [P1]: 实现原生消息中心和未读角标

**Files:**

- Create: `entry/src/main/ets/services/message/MessageModels.ts`
- Create: `entry/src/main/ets/services/message/MessageRepository.ts`
- Create: `entry/src/main/ets/pages/MessagePage.ets`
- Create: `entry/src/main/ets/components/message/MessageList.ets`
- Modify: `entry/src/main/ets/pages/MePage.ets`
- Modify: `entry/src/main/resources/base/profile/main_pages.json`
- Create: `entry/src/test/MessageModels.test.ets`
- Create: `entry/src/test/MessageRepository.test.ets`

**Todo:**

- [ ] 为 `/messages/unread_num`、`/messages/unread_nums`、`/messages?type=&last_id=` 建立严格模型和分页游标测试。
- [ ] 实现点赞、评论、关注、系统四个 tab，每类独立缓存、刷新、加载更多和错误状态。
- [ ] 复刻 Android 的目标解析规则：`poster{id}` 进入帖子，`user{id}` 进入用户，关注消息 fallback 到来源用户。
- [ ] 在“我”页增加消息入口和总未读角标；0 不显示，超过展示上限时使用 `99+`。
- [ ] 打开/刷新消息后重新拉取分类型和总未读数，避免角标停留旧值。
- [ ] 为 loading、空列表、失败、分页末尾分别实现稳定状态，不把单条消息垂直居中。
- [ ] 真机覆盖四类消息至少各一条；无法构造的类型保留 API fixture 测试证据。

**Acceptance:** 四类消息可分页浏览并跳到正确对象；“我”页角标与服务端一致；切 tab 不重复丢失已加载数据。

**Commit:** `feat(message): add native message center`

### Task 8 [P1]: 实现关注/粉丝列表并补齐用户页动作

**Files:**

- Modify: `entry/src/main/ets/services/user/userRepository.ts`
- Create: `entry/src/main/ets/pages/FollowListPage.ets`
- Modify: `entry/src/main/ets/pages/MePage.ets`
- Modify: `entry/src/main/ets/pages/UserDetailPage.ets`
- Modify: `entry/src/main/resources/base/profile/main_pages.json`
- Create: `entry/src/test/FollowList.test.ets`

**Todo:**

- [ ] 增加 `/user/followers?page=` 和 `/user/followings?page=` repository 方法与分页去重测试。
- [ ] 将“我的粉丝”和“我的关注”做成同一页面的两种 mode，支持刷新、加载更多、空态和失败重试。
- [ ] “我”页的关注/粉丝计数可点击进入对应列表；列表项进入用户详情。
- [ ] 从用户详情返回后刷新关注关系和数量，避免取关后旧值残留。
- [ ] 消息任务完成后，在“我”页一起验证设置、消息、关注/粉丝三个入口不会互相遮挡。

**Acceptance:** 关注/取关后计数与列表一致；分页无重复；未登录访问时进入统一登录流程。

**Commit:** `feat(user): add follower and following lists`

### Task 9 [P1]: 补齐话廊设置和本地内容屏蔽

**Files:**

- Create: `entry/src/main/ets/services/storage/GallerySettingsStore.ts`
- Create: `entry/src/main/ets/services/gallery/GalleryFilter.ts`
- Create: `entry/src/main/ets/pages/settings/GallerySettingPage.ets`
- Modify: `entry/src/main/ets/pages/settings/Settings.ets`
- Modify: `entry/src/main/ets/pages/PostPage.ets`
- Modify: `entry/src/main/ets/pages/SearchPage.ets`
- Modify: `entry/src/main/ets/pages/PosterDetailPage.ets`
- Modify: `entry/src/main/ets/pages/UserDetailPage.ets`
- Modify: `entry/src/main/ets/components/gallery/CommentInputDialog.ets`
- Modify: `entry/src/main/ets/services/gallery/PosterRepository.ts`
- Modify: `entry/src/main/ets/services/gallery/ReactionService.ts`
- Modify: `entry/src/main/resources/base/profile/main_pages.json`
- Create: `entry/src/test/GalleryFilter.test.ets`
- Create: `entry/src/test/GallerySettings.test.ets`
- Create: `entry/src/test/GalleryComments.test.ets`

**Todo:**

- [ ] 建立默认值：隐藏机器人 false、搜索隐藏机器人 false、隐藏 UID 列表空、隐藏匿名 false、严格模式 false、允许横滑 true。
- [ ] 列表请求按 Android 语义传 `hide_bot`：推荐/热门/最新受总开关控制，搜索还需搜索子开关，关注流不做本地用户屏蔽。
- [ ] 对推荐/热门/最新/搜索做本地 UID/匿名过滤；加载更多必须继续请求直到填充页面或服务端结束，避免“过滤后看似到底”。
- [ ] 详情评论过滤被隐藏用户；严格模式同时过滤其他人对被隐藏用户的回复。
- [ ] 为帖子详情主评论增加独立的 page、加载中和结束状态；首次和切换排序时从第 0 页重置，滚动到底继续分页并按评论 ID 去重，失败后可重试，不能请求一页就固定显示“没有更多评论了”。
- [ ] 评论发送条件改为“有非空文字或至少一张上传成功的图片”；允许发送空文字的纯图片评论，并在图片仍上传中或全部失败时给出明确状态。
- [ ] 用户详情增加隐藏/取消隐藏动作；设置页能查看并移除隐藏用户。
- [ ] `PostPage` 横滑手势由设置控制，但 tab 点击始终可用。
- [ ] 设置变更立即刷新当前列表，不要求重启。

**Acceptance:** 隐藏用户后其内容从指定流和评论中消失；关注流仍按 Android 策略显示；清除屏蔽后内容可恢复；主评论可完整分页加载；纯图片评论可成功发送。

**Commit:** `feat(gallery): add filtering preferences`

### Task 10 [P1]: 实现真实版本更新和日志反馈

**Files:**

- Create: `entry/src/main/ets/services/version/VersionModels.ts`
- Create: `entry/src/main/ets/services/version/VersionService.ts`
- Create: `entry/src/main/ets/services/storage/AboutSettingsStore.ts`
- Create: `entry/src/main/ets/services/log/LogExportService.ts`
- Modify: `entry/src/main/ets/pages/settings/AboutPage.ets`
- Modify: `entry/src/main/ets/entryability/EntryAbility.ets`
- Modify: `entry/src/main/ets/utils/Logger.ts`
- Modify: all production files reported by `rg -n "console\\." entry/src/main/ets --glob '!**/debug/**'`
- Create: `entry/src/test/VersionModels.test.ets`
- Create: `entry/src/test/AboutSettings.test.ets`

**Todo:**

- [ ] 对 `/version` 响应建立 `min_version_code/name`、`version_code/name`、`url`、`msg` 解析测试，并确认后端是否提供 HarmonyOS 独立版本通道；不能直接把 Android APK 更新信息展示给鸿蒙用户。
- [ ] 实现手动检查、启动自动检查、忽略普通版本和最低版本强制更新策略。
- [ ] 持久化 `autoDetectUpgrade`、`ignoredVersion` 和最后检查时间；失败时显示真实失败，不提示“已是最新”。
- [ ] 通过系统浏览器/应用市场打开更新 URL；强制更新对话框不可被普通忽略，但必须处理无可用 URL。
- [ ] 设计 HarmonyOS 可获得的应用日志导出方式；导出前对 cookie、token、学号、手机号和 URL query 中敏感字段脱敏。
- [ ] 通过系统分享发送文本日志；失败时提示用户并保留可重试入口。
- [ ] 将生产模块中的 `console.*` 迁移到 Logger，并把新模块同时注册到 `TARGET_MODULES`/`ALL_MODULES` 或完成 Logger 配置重构。

**Acceptance:** 后端返回新版本时展示真实版本/说明/链接；自动检查开关重启后保留；分享出的日志不含凭据。

**Commit:** `feat(settings): add updates and log export`

### Task 11 [P1]: 让主页、主题和旋转设置真正生效

**Files:**

- Create: `entry/src/main/ets/services/storage/PageSettingsStore.ts`
- Create: `entry/src/main/ets/services/storage/ThemeSettingsStore.ts`
- Modify: `entry/src/main/ets/pages/PageEnum.ets`
- Modify: `entry/src/main/ets/pages/Index.ets`
- Modify: `entry/src/main/ets/pages/settings/PagesSettingPage.ets`
- Modify: `entry/src/main/ets/pages/settings/ThemeSettingPage.ets`
- Modify: `entry/src/main/ets/entryability/EntryAbility.ets`
- Create: `entry/src/test/PageSettings.test.ets`
- Create: `entry/src/test/ThemeSettings.test.ets`

**Todo:**

- [ ] 将页面枚举收敛为 Android 对应的 5 个真实入口：Schedule、Map、BIT101Web、Gallery、Mine；移除 Home/Schedule/DDL 映射到同一 tab 的历史兼容混乱，必要时写迁移函数。
- [ ] 写失败测试：保存的 `home_page` 必须成为冷启动选中 tab；隐藏主页和隐藏 Mine 必须拒绝。
- [ ] `Index.aboutToAppear()` 无显式 route 参数时读取 home page，而不是固定 `Schedule`。
- [ ] 页面顺序/隐藏/主页统一改用 store，避免页面自己反复调用 `PersistentStorage.persistProp()`。
- [ ] 持久化 `dynamicTheme`、`darkThemeMode(system/light/dark)` 和 `autoRotate`。
- [ ] 在 `EntryAbility`/窗口阶段应用 color mode 和方向策略；系统模式变化时实时响应。
- [ ] 清除大量固定 `#FFFFFF/#F7F7F7/#2563EB` 对主题的硬编码阻断点，优先处理 Index、设置、消息、用户和话廊主页面。

**Acceptance:** 将“图”设为主页后冷启动进入地图；主题和旋转设置重启后保留并真正改变窗口行为；现有页面配置可迁移不丢失。

**Commit:** `fix(settings): apply page and theme preferences`

### Task 12 [P2]: 收敛地图和 Web 容器体验差距

**Files:**

- Modify: `entry/src/main/ets/components/map/MapCanvas.ets`
- Modify: `entry/src/main/ets/services/map/TileCacheService.ts`
- Modify: `entry/src/main/resources/rawfile/map.html`
- Modify: `entry/src/main/ets/components/web/WebPage.ets`
- Modify: `entry/src/main/ets/pages/WebBrowserPage.ets`
- Create: `entry/src/test/MapSettings.test.ets`
- Extend debug: `entry/src/main/ets/debug/MapDebugCase.ts`

**Todo:**

- [ ] 明确地图设置是“地图 zoom”还是 Android 的“渲染倍率”；修改标题和值域，禁止当前 1..19 zoom 冒充 1..5 缩放倍率。
- [ ] 为瓦片增加明确的缓存容量和过期策略；网络失败时优先展示有效缓存。
- [ ] 保留 HarmonyOS 已有的视口记忆优势，并测试异常/旧值归一化。
- [ ] Web 容器保存 URL、历史和滚动状态；进程内 tab 切换不得重新加载主论坛页。
- [ ] 统一页面加载、错误、后退、文件选择、外链和下载策略。
- [ ] 仅修复影响使用的布局/主题问题，不追 Compose 动画、圆角、颜色的逐像素一致。

**Acceptance:** 地图设置文案与真实行为一致；离线可复用近期瓦片；Web 返回/切 tab 后保留合理浏览状态。

**Commit:** `feat(map): align cache and scale behavior`

### Task 13 [P2]: 建立跨域回归门禁

**Files:**

- Modify: `entry/src/test/List.test.ets`
- Modify: `entry/src/ohosTest/ets/test/List.test.ets`
- Create/modify: 本计划各 Task 列出的测试文件
- Extend: `entry/src/main/ets/debug/LoginCoordinatorCase.ts`
- Create: `entry/src/main/ets/debug/MessageServiceCase.ts`
- Modify: `entry/src/main/ets/debug/DebugRunner.ts`
- Modify: `docs/plans/2026-08-27-android-parity-todolist.md`

**Todo:**

- [ ] 每个 repository 先用 fixture 覆盖字段映射、分页、空响应和非 2xx，再接 UI。
- [ ] 运行本地测试：`& 'D:\Software\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' test --no-daemon`。
- [ ] 运行构建：`devecocli build`；P0 合并前再运行 `devecocli build --build-mode release`。
- [ ] 用 `devecocli run --module entry --device <serial>` 做登录、Web、资料修改、消息、关注、话廊设置、更新和日志分享冒烟。
- [ ] 用 `devecocli log --device <serial> --bundle-name <official-bundle-name> --level E --from 10m --tail 300` 检查异常。
- [ ] 每个 DebugCase 结束后恢复 `CURRENT_DEBUG_TARGET = NONE`；在测试中把该要求变成硬门禁。
- [ ] 在本文件维护完成证据：commit、测试结果、设备型号、日期和关键日志，不再维护第二份平行 Todo。

**Acceptance:** 本地测试、debug/release 构建通过；P0/P1 主路径至少有一台真机证据；release 冷启动无 DebugCase。

**Commit:** `test(app): add parity regression coverage`

## 5. 明确不做

- 不重新实现已经闭环的课程表、考试、自定义日程、DDL 和空教室，只修回归。
- 不照搬 Android 的 Hilt、Room、DataStore、Compose 模块结构；这是平台实现差异，不是产品差距。
- 不因 Android API 模块存在 `/scores`、`/papers`、课程资料接口就立刻原生化；当前 Android 主导航也没有这些完整用户入口，需单独产品立项。
- 不用普通 preferences/AppStorage 保存明文密码来换取自动登录。
- 不追逐 Material Shared Axis、padding、颜色、圆角和 toast/snackbar 的逐像素一致，除非影响可读性、点击、重叠或流程正确性。
- 不移植 Android 已删除的 `features:mine` 模块；只对齐当前 `features:user` 行为。

## 6. 建议里程碑

### Milestone A: 可发布且不误导（P0-A）

- [ ] Task 1 发布态清理
- [ ] Task 2 真实资料编辑
- [ ] Task 3 Web 会话桥接
- [ ] Task 4 登录事务与失败分类

### Milestone B: 认证可恢复（P0-B）

- [ ] Task 5 SMS 二次验证
- [ ] Task 6 安全凭据与自动恢复

### Milestone C: 社区闭环（P1-A）

- [ ] Task 7 消息中心
- [ ] Task 8 关注/粉丝列表
- [ ] Task 9 话廊设置

### Milestone D: 设置兑现（P1-B）

- [ ] Task 10 更新与日志反馈
- [ ] Task 11 主页、主题和旋转

### Milestone E: 收尾（P2）

- [ ] Task 12 地图/Web 体验
- [ ] Task 13 回归门禁

完成 Milestone D 后，HarmonyOS 与 Android 的主要用户可见功能可视为基本对齐；Milestone E 是平台质量收敛，不应阻塞前四个里程碑按批发布。

## 7. 二次查漏结论

- **数量口径：** 当前仍是 13 个任务簇，不是 13 个原子 Todo。任务簇按可独立交付的功能域和依赖关系归并，每个 Task 下还有多条实现、测试和真机验证项。
- **审计基线：** 结论对应 Android `main@6d79f18`（1.4.0）；Android 参考目录已更新到该提交。
- **覆盖范围：** 已复核 Android 全部导航路由和底部 Tab，以及设置、关于、登录、Web、话廊列表/搜索/发布/详情、用户页、消息、关注/粉丝、举报、图片查看/下载；同时追踪 Android API 声明的实际调用点，并与 HarmonyOS 对应页面、服务、存储、发布配置和测试入口交叉核对。
- **二次发现：** 没有发现需要新增 Task 14 的独立产品模块；新发现的“帖子主评论未分页”和“不能发送纯图片评论”已经归入 Task 9。
- **不计入项：** `/reaction/stay` 只有接口声明、没有实际调用；`/scores`、`/papers`、`/courses`、`/variables` 以及管理端 reports/bans 在当前 Android 版没有普通用户入口，因此不作为本轮鸿蒙对齐任务。
- **残余风险：** 静态源码无法证明后端动态开关、短信 challenge、系统权限、Web 登录态和真机交互在所有环境下绝对无遗漏；这些只能通过 Task 13 的接口 fixture、debug/release 构建和设备回归继续收口。
