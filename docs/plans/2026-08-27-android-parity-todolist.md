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
- 本轮是静态源码审计。设备验收采用“模拟器优先、真机后置”的统一口径，真机由后续集中回归完成。

### 验收口径（2026-10-17）

- 先以 Android 1.4.0 的源码、请求契约和状态行为为对照，完成 HarmonyOS 的功能实现与可自动化验证；不能因暂时没有签名包或真机排期而回退已完成的代码状态。
- 有设备交互的功能优先使用 HarmonyOS 模拟器验证：冷启动、页面导航、主题/旋转、WebView 状态、文件选择、系统分享、外链跳转、缓存恢复和错误提示都应尽量建立模拟器证据。
- 模拟器无法覆盖的账号、短信、校园网络、传感器、系统权限和真实后端场景，统一标记为“真机后置”；这类项目不阻塞代码实现、单元测试、fixture 测试和构建检查。
- 真机验证集中在后续回归批次执行。Todo 中的“设备验收”表示模拟器优先的设备验证；只有明确写有“真机后置”的项目才要求用户后续统一补做。
- 构建验证必须区分 ArkTS 编译/打包/包检查与签名/安装：签名配置问题只能阻止设备运行，不能把已经通过的编译、测试和行为对齐标记为失败。
- 状态标记中，功能清单全部为 `[x]` 且本地测试/构建门禁已通过，即表示“实现完成”；模拟器和真机属于独立的设备验收状态，不因设备尚未运行而回退实现状态。

**签名恢复验证（2026-10-17）:** 用户在 DevEco Studio 重新签名后，`devecocli build` 和 `devecocli build --build-mode release` 均完整成功（含 SignHap）；先前 Task 9/12 中记录的 keystore 密码错误已解除，历史失败证据保留。Release 新包通过 `devecocli run --module entry --device 127.0.0.1:5555 --build-mode release --skip-build` 成功覆盖安装并启动到 Huawei_Phone 模拟器（HarmonyOS 5.1.1 API 19），未卸载旧应用；按包名查询未发现崩溃日志。构建、运行与日志证据为 `entry/build/signing-recheck-debug.log`、`signing-recheck-release.log`、`signing-recheck-run.log`、`signing-recheck-device.log`、`signing-recheck-crash.log`。本次仅验证签名构建和安装启动，Task 9/12 的功能交互验收仍待模拟器回归，真实账号和系统联动真机后置。

### Android 更新复核（2026-10-17）

本次使用 `git -c http.proxy= fetch origin main` 直连复核了 `BIT101-Android` 的远端分支（本机原代理端口不可用）、提交历史和工作区：当前 `origin/main` 仍为 `6d79f18`（2026-08-06，1.4.0），没有比本计划基线更新的安卓版提交，工作区也没有未提交改动。因此本轮没有新增独立的 Android 功能域或 Task 14，但把最近一批提交逐项映射到现有 Todo，后续实现以这些行为为准：

| Android 提交/更新 | 已确认的产品行为 | 鸿蒙 Todo 落点 |
| --- | --- | --- |
| `4bbae89`、`fa2d6cc`、`90b6fc3` | BIT-Login v4 迁移完成；乐学日历订阅改走 SSO，使用 BIT-Login 4.0.2 | Task 5、Task 6；不得回退到旧的独立登录协议 |
| `a910e33`、`86736e8`、`69e0921`、`f975d5d`、`5320289`、`38a040d` | 图片验证码/短信验证码共享请求总线；会话过期刷新，401 最多重试一次；刷新锁忙时返回 `BUSY`，不清理有效登录态 | Task 5、Task 6 |
| `f471136`、`7528bdb`、`7ef2658`、`b18ab0f`、`2f031fe` | 原生消息中心支持点赞、评论、关注、系统四类消息；横向分页；用户页入口和未读角标；通知顺序及角标显示规则 | Task 7 |
| `1d5fd50`、`9f7ee1f` | “我的关注/粉丝”列表；用户页收起时显示头像和昵称 | Task 8 |
| `e23711a` | 话廊横向滑动默认开启 | Task 9 的默认值与运行时设置 |
| `d1a776f` | 关于页导出应用日志，通过系统分享发送 | Task 10；同时落实敏感字段脱敏 |
| `6d79f18` | Android 版本升级至 1.4.0（`versionCode=6`） | Task 1/10 仅作为对照；鸿蒙必须使用自己的版本号和更新通道 |

复核结论：现有 13 个任务已经覆盖安卓版最新行为；需要在实现和验收时特别保留 Android 的消息分类/角标、横向分页、`BUSY` 刷新语义、日志分享和 1.4.0 对照信息。课程表、DDL、空教室等已有闭环没有因这次安卓版复核重新打开。

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
- [ ] 模拟器优先验证三项资料编辑和重启恢复；真机后置：重新进入“我”和账号页确认服务端值一致。

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
- [ ] 模拟器优先验证 `https://bit101.cn` 容器行为、文件选择、外链打开和成绩页状态；真机后置：真实账号与校园网络登录态。

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

- [x] 为 `/messages/unread_num`、`/messages/unread_nums`、`/messages?type=&last_id=` 建立严格模型和分页游标测试。
- [x] 实现点赞、评论、关注、系统四个 tab，每类独立缓存、刷新、加载更多和错误状态。
- [x] 复刻 Android 的目标解析规则：`poster{id}` 进入帖子，`user{id}` 进入用户，关注消息 fallback 到来源用户。
- [x] 在“我”页增加消息入口和总未读角标；0 不显示，超过展示上限时使用 `99+`。
- [x] 打开/刷新消息后重新拉取分类型和总未读数，避免角标停留旧值。
- [x] 为 loading、空列表、失败、分页末尾分别实现稳定状态，不把单条消息垂直居中。
- [ ] 真机覆盖四类消息至少各一条；无法构造的类型保留 API fixture 测试证据。

**Progress (2026-10-17):** 新增 MessageRepository、严格 snake_case 消息/未读模型、独立分类分页状态机、共享进程内 UnreadStore 和 MessagePage。按 Android 顺序展示点赞/评论/关注/系统，支持横滑及点击切换、分类缓存、刷新、空态、加载更多和错误重试；GET 成功后重新获取总数及分类未读数。“我”页新增消息入口，零值隐藏计数、超过 99 显示 99+，退出/游客状态清理未读。跳转优先 link_obj，再 obj，再关注来源用户；不执行任意外部链接。游标分页去重、重复游标停止、刷新/退出后丢弃旧响应，401 跳统一登录。新增 9 项回归，全套 295 项成功（Failure=0、Error=0、Ignore=0）；debug/release 签名构建通过，release 在 Huawei_Phone（127.0.0.1:5555）覆盖安装启动成功，未发现应用崩溃日志。证据为 entry/build/message-tests.log、message-debug.log、message-release.log、message-run.log、message-crash.log。当前仅完成安装启动，消息页手势、真实账号四类消息、入口布局和角标变化尚未完成设备交互验收，Task 7 不整体标记完成。

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

- [x] 增加 `/user/followers?page=` 和 `/user/followings?page=` repository 方法与分页去重测试。
- [x] 将“我的粉丝”和“我的关注”做成同一页面的两种 mode，支持刷新、加载更多、空态和失败重试。
- [x] “我”页的关注/粉丝计数可点击进入对应列表；列表项进入用户详情。
- [x] 从用户详情返回后刷新关注关系和数量，避免取关后旧值残留。
- [ ] 消息任务完成后，在“我”页一起验证设置、消息、关注/粉丝三个入口不会互相遮挡。

**Progress (2026-10-17):** 新增 Followers/Followings repository 方法、严格数组解析、共用 FollowListPage 和可注入分页状态机；按用户 ID 去重并更新重复用户资料，空页才判定结束。刷新和加载更多失败保留已有列表、重试原页，刷新或退出后旧请求不得覆盖；401 进入统一登录并携带 mode，登录页保留 redirectParams。“我”页计数可进入两类列表，列表项进入用户详情；关注/取关成功触发关系事件，返回列表时刷新、同步刷新个人计数，并防止重复点击关注。9 项回归覆盖接口、缺少登录、HTTP/解析错误、去重/结束、失败重试、并发/取消、会话过期和事件释放；本地测试 258 项通过（Failure=0, Error=0），debug/release 构建通过。当前模拟器未登录业务账号，真实关注/取关与列表返回交互仍需账号验收，未把 Task 8 整体标记完成。

**Acceptance:** 关注/取关后计数与列表一致；分页无重复；未登录访问时进入统一登录流程。

**Commit:** `feat(user): add follower and following lists`

### Task 9 [P1]: 补齐话廊设置和本地内容屏蔽

**Files:**

- Create: `entry/src/main/ets/services/storage/GallerySettingsStore.ts`
- Create: `entry/src/main/ets/services/gallery/GalleryFilter.ts`
- Create: `entry/src/main/ets/services/gallery/FilteredPager.ts`
- Create: `entry/src/main/ets/pages/settings/GallerySettingPage.ets`
- Modify: `entry/src/main/ets/pages/settings/Settings.ets`
- Modify: `entry/src/main/ets/pages/PostPage.ets`
- Modify: `entry/src/main/ets/pages/SearchPage.ets`
- Modify: `entry/src/main/ets/pages/PosterDetailPage.ets`
- Modify: `entry/src/main/ets/pages/UserDetailPage.ets`
- Modify: `entry/src/main/ets/components/gallery/CommentInputDialog.ets`
- Modify: `entry/src/main/ets/components/gallery/ImagePickerGrid.ets`
- Modify: `entry/src/main/ets/components/gallery/MoreCommentsSheet.ets`
- Modify: `entry/src/main/ets/services/gallery/PosterListState.ets`
- Modify: `entry/src/main/ets/entryability/EntryAbility.ets`
- Modify: `entry/src/main/ets/services/gallery/PosterRepository.ts`
- Modify: `entry/src/main/ets/services/gallery/ReactionService.ts`
- Modify: `entry/src/main/resources/base/profile/main_pages.json`
- Create: `entry/src/test/GalleryFilter.test.ets`
- Create: `entry/src/test/GallerySettings.test.ets`
- Create: `entry/src/test/GalleryComments.test.ets`

**Todo:**

- [x] 建立默认值：隐藏机器人 false、搜索隐藏机器人 false、隐藏 UID 列表空、隐藏匿名 false、严格模式 false、允许横滑 true。
- [x] 列表请求按 Android 语义传 `hide_bot`：推荐/热门/最新受总开关控制，搜索还需搜索子开关，关注流不做本地用户屏蔽。
- [x] 对推荐/热门/最新/搜索做本地 UID/匿名过滤；加载更多必须继续请求直到填充页面或服务端结束，避免“过滤后看似到底”。
- [x] 详情评论过滤被隐藏用户；严格模式同时过滤其他人对被隐藏用户的回复。
- [x] 为帖子详情主评论增加独立的 page、加载中和结束状态；首次和切换排序时从第 0 页重置，滚动到底继续分页并按评论 ID 去重，失败后可重试，不能请求一页就固定显示“没有更多评论了”。
- [x] 评论发送条件改为“有非空文字或至少一张上传成功的图片”；允许发送空文字的纯图片评论，并在图片仍上传中或全部失败时给出明确状态。
- [x] 用户详情增加隐藏/取消隐藏动作；设置页能查看并移除隐藏用户。
- [x] `PostPage` 横滑手势由设置控制，但 tab 点击始终可用。
- [x] 设置变更立即刷新当前列表，不要求重启。

- [ ] 模拟器优先验收设置重启恢复、横滑与点击切换、隐藏/取消隐藏后的列表与评论变化、主评论跨页及纯图片评论发送；真机后置：真实账号数据和后端交互。

**Progress (2026-10-17):** 新增 GallerySettingsStore（默认值、落盘成功后发布变更、写入失败保留旧设置）、话廊设置页和用户主页隐藏/取消隐藏入口。对照 Android DefaultPosterRepo / GalleryIndexViewModel / PosterViewModel：推荐/最热/最新传总开关对应的 hide_bot，搜索同时依赖搜索子开关；关注流不应用本地 UID/匿名过滤。帖子、主评论和更多回复共用可注入 FilteredPager：过滤后继续请求直到补足一页或服务端空页，ID 去重，失败保留数据与游标、点击重试，刷新/排序切换和离页取消旧请求。主评论显式从 page=0 开始，滚动到底继续加载，不再固定声称已到底；子评论和严格回复过滤同样生效。设置变更刷新已挂载列表；横滑默认开启，关闭后标签点击仍可切换。评论支持纯图片，上传中/失败有明确提示；图片上传改用稳定 uploadId 定位，规避 ArkUI 代理对象引用导致上传状态卡住。

**Validation (2026-10-17):** 新增 GalleryFilter / GallerySettings / GalleryComments 三组 14 项回归，覆盖字段映射、请求参数、非 2xx/异常响应、设置恢复及失败、关注流例外、递归严格过滤、跨页补足、去重、失败重试、并发/取消、排序刷新及纯图片请求体；完整本地测试 272 项通过（Failure=0, Error=0）。devecocli debug/release 均通过 ArkTS 编译和 PackageHap/PackingCheck，但 SignHap 报 11014003 keystore password was incorrect；当前配置解密密码经本机 keytool 验证也无法打开对应 keystore。未修改机器签名配置、未卸载应用，Huawei_Phone（127.0.0.1:5555）上的本轮 UI/账号验收未执行。Task 9 保留设备验收未完成。

**Acceptance:** 隐藏用户后其内容从指定流和评论中消失；关注流仍按 Android 策略显示；清除屏蔽后内容可恢复；主评论可完整分页加载；纯图片评论可成功发送。

**Commit:** `feat(gallery): add filtering preferences`

### Task 10 [P1]: 实现真实版本更新和日志反馈

**Files:**

- Create: `entry/src/main/ets/services/version/VersionModels.ts`
- Create: `entry/src/main/ets/services/version/VersionService.ts`
- Create: `entry/src/main/ets/services/storage/AboutSettingsStore.ts`
- Create: `entry/src/main/ets/services/log/LogExportService.ts`
- Create: `entry/src/main/ets/services/log/LogBuffer.ts`
- Create: `entry/src/main/ets/services/log/LogShareTarget.ts`
- Modify: `entry/src/main/ets/pages/settings/AboutPage.ets`
- Modify: `entry/src/main/ets/entryability/EntryAbility.ets`
- Modify: `entry/src/main/ets/utils/Logger.ts`
- Modify: all production files reported by `rg -n "console\\." entry/src/main/ets --glob '!**/debug/**'`
- Create: `entry/src/test/VersionModels.test.ets`
- Create: `entry/src/test/AboutSettings.test.ets`
- Create: `entry/src/test/LogExport.test.ets`

**Todo:**

- [ ] 对 `/version` 响应建立 `min_version_code/name`、`version_code/name`、`url`、`msg` 解析测试，并确认后端是否提供 HarmonyOS 独立版本通道；不能直接把 Android APK 更新信息展示给鸿蒙用户。
- [x] 实现手动检查、启动自动检查、忽略普通版本和最低版本强制更新策略（设备交互待验收）。
- [x] 持久化 `autoDetectUpgrade`、`ignoredVersion` 和最后成功检查时间；失败时显示真实失败，不提示“已是最新”。
- [x] 通过系统浏览器打开更新 URL；强制更新不可普通忽略，空链接、非法协议及 APK 链接回退项目主页（真实鸿蒙更新通道及跳转仍待验收）。
- [x] 设计 HarmonyOS 可获得的应用日志导出方式；导出前对 cookie、token、学号、手机号和 URL query 中敏感字段脱敏。
- [x] 接入系统分享文本日志；失败时提示用户并保留可重试入口（分享面板与接收端文件仍待设备验收）。
- [x] 将生产模块中的 `console.*` 迁移到 Logger，并把新模块同时注册到 `TARGET_MODULES`/`ALL_MODULES`。
- [ ] 模拟器优先验收系统分享面板、取消/重试和 UTF-8 文本附件；真机后置：真实接收端和系统分享目标验证。

**Progress (2026-10-17):** 已新增 `VersionModels`、可注入的 `VersionService`、`AboutSettingsStore` 和共享 `UpdateChecker`，接入 Index 启动检查及关于页手动检查。自动检查开关、忽略版本和最后成功检查时间持久化；普通版本可稍后/忽略，低于最低版本时禁止普通忽略；失败或平台不明时不再假报“最新”。仅接受显式 `harmonyos`/`ohos`/`openharmony` 响应，默认 Android 契约无平台字段时返回“暂未提供鸿蒙版更新信息”；这是客户端保护，尚未确认后端提供鸿蒙通道。新增 12 项解析/更新策略/请求/设置恢复与写入失败测试；完整本地测试 228 项通过（Failure=0, Error=0），`devecocli` debug/release 签名构建通过。当前无活动设备，弹窗、设置开关重启恢复和系统浏览器跳转仍需设备验收。真实鸿蒙更新地址、无 URL 时的后续引导和日志导出继续保留未完成状态，Task 10 尚未整体完成。

**日志进展（2026-10-17）:** 关于页新增“导出诊断日志”，Logger 在写入前统一脱敏，并保留最多 300 条、98304 个 UTF-16 字符的内存日志（单条最多 4096 字符）；包含凭据字段的整条消息省略，HTTP URL、长号码等单独替换。沿用 debug 白名单/release 仅 error/fatal 的策略，导出范围明确为本次运行，不包含历史进程或系统日志。点击后生成缓存目录中的单个 UTF-8 文本文件，以 Share Kit 应用文件 URI 拉起系统分享；未在后台发送日志，写入/分享失败可重试，重复导出会合并。剩余生产 `console.*` 及备份 Ability 的直接 HiLog 已迁到 Logger，新模块已注册。新增 8 项回归覆盖凭据/嵌套 JSON/URL/号码脱敏、容量限制、release 门禁、快照、空日志、失败重试和并发导出；完整本地测试 236 项通过（Failure=0, Error=0），debug/release 签名构建通过。当前 `devecocli device list` 无活动设备，分享面板和接收端文件待验收；Task 10 仍受真实鸿蒙更新通道和设备验证限制，尚未整体完成。

**Acceptance:** 后端返回新版本时展示真实版本/说明/链接；自动检查开关重启后保留；分享出的日志不含凭据。

**Commit:** `feat(settings): add updates and log export`

**补充验证（2026-10-17）:** 更新 URL 为空、不安全协议、无效格式或 APK（含编码扩展名）时，更新按钮改为前往项目主页；补回归测试。release 包在 API 19 模拟器实测诊断日志系统分享面板，显示 UTF-8 文本附件，取消后可重新导出。尚未核验接收端文本内容，设备验收项继续保留。

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

- [x] 将页面枚举收敛为 Android 对应的 5 个真实入口：Schedule、Map、BIT101Web、Gallery、Mine；移除 Home/Schedule/DDL 映射到同一 tab 的历史兼容混乱，必要时写迁移函数。
- [x] 写失败测试：保存的 `home_page` 必须成为冷启动选中 tab；隐藏主页和隐藏 Mine 必须拒绝。
- [x] `Index.aboutToAppear()` 无显式 route 参数时读取 home page，而不是固定 `Schedule`。
- [x] 页面顺序/隐藏/主页统一改用 store，避免页面自己反复调用 `PersistentStorage.persistProp()`。
- [x] 持久化 `darkThemeMode(system/light/dark)` 和 `autoRotate`，启动前恢复并实际应用。
- [ ] 评估鸿蒙壁纸取色/动态主题能力；已移除无实现且标注 Android 12 的开关，未冒充对齐。
- [x] 在 `EntryAbility`/窗口阶段应用 color mode 和方向策略；系统模式变化时实时响应。
- [ ] 清除大量固定 `#FFFFFF/#F7F7F7/#2563EB` 对主题的硬编码阻断点，优先处理 Index、设置、消息、用户和话廊主页面。

**Progress (2026-10-17):** 新增五入口模型、旧别名去重迁移、PageSettingsStore、ThemeSettingsStore 和可注入的主题控制器。首屏加载前恢复主页，合法路由参数优先；保存落盘成功后才更新导航，主页与 Mine 禁止隐藏。深浅模式使用 ApplicationContext.setColorMode，旋转使用主窗口 setPreferredOrientation；保存或运行时应用失败会回滚，禁止并发覆盖。Index、用户头部、话廊列表/评论的主要固定背景与文字颜色改用系统资源。游客和资料加载失败页补设置入口。13 项新增页面/主题/更新链接回归测试使本地测试达到 249 项通过（Failure=0, Error=0）。release 包在 Huawei_Phone（HarmonyOS 5.1.1 API 19）验证地图主页冷启动、隐藏网页入口、深/浅模式立即切换、主题和旋转重启恢复、关闭旋转窗口策略 1、开启策略 8；尚未用传感器模拟验证横竖转换，也未完成所有业务页深色视觉验收。动态主题和全量视觉适配继续保留，Task 11 不整体勾选。

**深色适配进展（2026-10-17）:** 帖子详情正文、主评论/子评论、引用回复、顶栏/底栏、加载/空态、排序和更多操作弹层改用系统主题资源；昵称和可点击正文组件默认颜色同步适配。保留图片预览黑底和遮罩。最终 release 签名构建通过，在 Huawei_Phone（127.0.0.1:5555）覆盖安装启动成功，未发现应用崩溃日志；debug 签名构建在补齐引用回复背景前通过。证据见 entry/build/detail-theme-debug.log、detail-theme-release.log、detail-theme-run.log 和 detail-theme-crash.log。本轮为颜色资源适配，没有新增单元测试；真实帖子及各弹层深浅色视觉交互尚待验收，Task 11 全量适配项仍保留未完成。

**编辑/举报主题进展（2026-10-17）:** 发帖/编辑的标签、输入提示、创作者声明及标签弹窗，举报的正文、加载/错误、类型选择、输入区和页头/页尾，以及更多评论的警示颜色改用系统语义资源。举报类型选中圆点改为圆角 Row 背景，移除 API 26 Shape.fill 兼容警告。debug 签名构建在最后一轮输入/警示颜色调整前通过，最终 release 签名构建通过，Huawei_Phone 模拟器覆盖安装启动成功，未发现应用崩溃日志。证据见 entry/build/editor-theme-debug.log、editor-theme-release.log、editor-theme-run.log、editor-theme-crash.log。仅颜色与选中指示器适配，没有新增单元测试；发帖/举报真实后端行为和深浅色交互仍待验收，Task 11 全量适配继续保留。

**Acceptance:** 将“图”设为主页后冷启动进入地图；主题和旋转设置重启后保留并真正改变窗口行为；现有页面配置可迁移不丢失。

**Commit:** `fix(settings): apply page and theme preferences`

### Task 12 [P2]: 收敛地图和 Web 容器体验差距（实现完成，设备验收后置）

**Status:** 实现、自动化验证及 debug/release 签名构建完成，模拟器覆盖安装启动通过；详细功能交互验收待后续模拟器回归，真实网络、账号和系统应用联动真机后置。

**Files:**

- Modify: `entry/src/main/ets/components/map/MapCanvas.ets`
- Modify: `entry/src/main/ets/services/map/TileCacheService.ts`
- Create: `entry/src/main/ets/services/map/TileCachePlatform.ts`
- Create: `entry/src/main/ets/services/map/MapSettingsModel.ts`
- Modify: `entry/src/main/resources/rawfile/map.html`
- Modify: `entry/src/main/ets/components/web/WebPage.ets`
- Create: `entry/src/main/ets/components/web/WebNavigationModel.ts`
- Modify: `entry/src/main/ets/pages/ForumPage.ets`
- Modify: `entry/src/main/ets/pages/Index.ets`
- Modify: `entry/src/main/ets/pages/WebBrowserPage.ets`
- Modify: `entry/src/main/ets/utils/Logger.ts`
- Create: `entry/src/test/MapSettings.test.ets`
- Create: `entry/src/test/WebNavigation.test.ets`
- Modify: `entry/src/test/List.test.ets`
- Extend debug: `entry/src/main/ets/debug/MapDebugCase.ts`

**Todo:**

- [x] 明确地图设置是“地图 zoom”还是 Android 的“渲染倍率”；修改标题和值域，禁止当前 1..19 zoom 冒充 1..5 缩放倍率。
- [x] 为瓦片增加明确的缓存容量和过期策略；网络失败时优先展示有效缓存。
- [x] 保留 HarmonyOS 已有的视口记忆优势，并测试异常/旧值归一化。
- [x] 实现页面独立、仅进程内的 URL、历史和滚动状态保存；保留现有懒加载后常驻的论坛 Web，切 tab 时不主动刷新。
- [x] 统一页面加载、错误、后退、文件选择、外链和下载策略。
- [x] 修复地图设置面板和 Web 原生背景的主题适配。
- [ ] 模拟器优先验收近期瓦片离线显示、缓存重建恢复、地图视口恢复、论坛切 tab 不重载、Web 历史/滚动恢复、文件选择及外链/下载跳转；真机后置：真实网络、账号和系统应用联动。

**Progress (2026-10-17):** 地图设置明确为“地图缩放级别”，范围 1.0..19.0；旧视口、异常坐标和非有限 zoom 统一归一化，移除依赖固定延迟的恢复。瓦片由原生异步请求拦截接入磁盘缓存，保留 7 天、总量 10 MB、单片上限 1 MB；校验地址和 PNG 签名，优先读取有效缓存，合并同片并发请求，写入前淘汰旧片，存储失败仍可使用新网络响应。Web 使用页面独立的内存状态保存 URL、历史（上限 512 KB）与滚动位置，论坛继续由 Index 常驻，系统返回和工具栏返回共用安全后退策略；主框架错误才显示整页错误，文件选择复用公共处理，HTTP(S) 下载和外链交系统处理，失败提供提示。异步会话注入增加页面生命周期和当前 URL 校验。

**Validation (2026-10-17):** 新增 14 项地图/Web 回归测试，本地总计 286 项通过（Failure=0, Error=0），覆盖缓存过期、容量、离线重建、损坏、存储失败、并发和导航策略；报告为 `entry/.test/default/intermediates/test/coverage_data/test_result.txt`，日志为 `entry/build/map-web-tests.log`。对实际 `map.html` 的 Node VM 桥接冒烟验证 zoom 边界、异常输入和校区坐标；真实瓦片端点抽查返回 HTTP 200、10848 字节有效 PNG。`devecocli build` 与 `devecocli build --build-mode release` 均通过 CompileArkTS、PackageHap、PackingCheck，但 SignHap 均因现有 `11014003 Init keystore failed / keystore password was incorrect` 失败，完整构建未通过；日志分别为 `entry/build/map-web-debug-build.log` 和 `entry/build/map-web-release-build.log`。MapDebugCase 已增加实际磁盘缓存及禁止网络后的重建读取断言，尚未在设备运行；`CURRENT_DEBUG_TARGET` 保持 NONE。签名问题阻止新包安装，平台缓存与 Web 生命周期的设备证据按新的模拟器优先、真机后置口径补做；Task 12 的实现与自动化验证已完成，设备验收保留待后续回归。上述改动尚未提交。

**Acceptance:** 地图设置文案与真实行为一致；离线可复用近期瓦片；Web 返回/切 tab 后保留合理浏览状态。

**Commit:** `feat(map): align cache and scale behavior`

### Task 13 [P2]: 建立跨域回归门禁

**Status:** 自动化门禁持续建设中；模拟器优先形成可重复证据，真实账号、校园网络和系统联动真机后置。

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
- [x] 运行本地测试：`& 'D:\Software\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' test --no-daemon`。
- [ ] 运行构建：`devecocli build`；P0 合并前再运行 `devecocli build --build-mode release`。
- [ ] 优先用 `devecocli run --module entry --device <emulator-serial>` 做登录替身、Web、资料修改、消息、关注、话廊设置、更新和日志分享模拟器冒烟；真实账号、校园网络和系统联动统一真机后置。
- [ ] 优先用模拟器日志检查异常；真机后置时再用 `devecocli log --device <serial> --bundle-name <official-bundle-name> --level E --from 10m --tail 300` 做最终回归。
- [x] 每个 DebugCase 结束后恢复 `CURRENT_DEBUG_TARGET = NONE`；在测试中把该要求变成硬门禁。
- [ ] 在本文件维护完成证据：commit、测试结果、设备型号、日期和关键日志，不再维护第二份平行 Todo。

**回归门禁进展（2026-10-17）:** 功能批次已提交为 ecefd13。新增 scripts/Test-Parity.ps1，可通过 -DevEcoPath 指定 DevEco 安装目录（本机实际为 D:/Huawei/DevEco Studio，旧文档 D:/Software/Huawei 路径已不可用）。脚本检查 CURRENT_DEBUG_TARGET=NONE，执行本地测试并验证报告为本次生成、用例非空、失败/错误/跳过均为零且全部通过；运行后恢复进程环境变量，不修改签名配置。实际执行通过：286 项成功，Failure=0、Error=0、Ignore=0，日志为 entry/build/parity-gate.log。现有 DebugRunnerContract 测试继续覆盖默认 NONE 和 release 禁用调试。此批次复用上一轮 debug/release 签名构建及模拟器启动证据；跨域设备交互和真实账号回归仍待完成。

**Acceptance:** 本地测试、ArkTS 编译/打包/包检查和模拟器可运行路径通过；P0/P1 主路径先形成模拟器或 fixture 证据，真机证据集中后置；release 冷启动无 DebugCase。

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

- [x] Task 12 地图/Web 体验（实现与自动化验证完成；模拟器/真机设备验收后置）
- [ ] Task 13 回归门禁

完成 Milestone D 后，HarmonyOS 与 Android 的主要用户可见功能可视为基本对齐；Milestone E 是平台质量收敛，不应阻塞前四个里程碑按批发布。

## 7. 二次查漏结论

- **数量口径：** 当前仍是 13 个任务簇，不是 13 个原子 Todo。任务簇按可独立交付的功能域和依赖关系归并，每个 Task 下还有多条实现、自动化验证和设备验收项。
- **设备口径：** 模拟器优先验证可重复的 UI、导航、状态恢复、错误处理和系统调用；账号、短信、校园网络、传感器、权限及真实后端联动统一真机后置，后续集中验收。
- **审计基线：** 结论对应 Android `main@6d79f18`（1.4.0）；Android 参考目录已更新到该提交。
- **覆盖范围：** 已复核 Android 全部导航路由和底部 Tab，以及设置、关于、登录、Web、话廊列表/搜索/发布/详情、用户页、消息、关注/粉丝、举报、图片查看/下载；同时追踪 Android API 声明的实际调用点，并与 HarmonyOS 对应页面、服务、存储、发布配置和测试入口交叉核对。
- **二次发现：** 没有发现需要新增 Task 14 的独立产品模块；新发现的“帖子主评论未分页”和“不能发送纯图片评论”已经归入 Task 9。
- **不计入项：** `/reaction/stay` 只有接口声明、没有实际调用；`/scores`、`/papers`、`/courses`、`/variables` 以及管理端 reports/bans 在当前 Android 版没有普通用户入口，因此不作为本轮鸿蒙对齐任务。
- **残余风险：** 静态源码无法证明后端动态开关、短信 challenge、系统权限、Web 登录态和真机交互在所有环境下绝对无遗漏；这些只能通过 Task 13 的接口 fixture、debug/release 构建和设备回归继续收口。
