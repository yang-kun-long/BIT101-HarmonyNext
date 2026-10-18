# 话廊真实闭环与原生教务课程同步实施计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 完成话廊设置在帖子、评论、用户动态中的一致生效，并把 Android 原生教务课程同步接入当前课程表刷新流程，保留旧数据安全性。

**Architecture:** 话廊继续使用现有 GallerySettingsStore、FilteredPager 和 PosterListState，在用户动态和评论层统一过滤，设置变化通过订阅即时刷新。课程同步使用现有 CourseScheduleApiRepository 的学校教务接口，增强响应校验、课程周次/字段映射和刷新失败时保留旧课表；不改动已有 ICS 回退路径。

**Tech Stack:** ArkTS/TypeScript、ArkUI、RCP、Hypium、devecocli。

---

### Task 1: 话廊过滤闭环回归

**Files:**
- Modify: `entry/src/main/ets/pages/UserDetailPage.ets`
- Modify: `entry/src/main/ets/services/gallery/GalleryFilter.ts`
- Test: `entry/src/test/GalleryFilter.test.ets`

**Steps:**
1. 写失败测试，确认用户动态列表按隐藏 UID/匿名设置过滤，并且关注流例外规则不被误用。
2. 运行对应测试确认失败。
3. 将 UserDetailPage 的帖子列表接入统一过滤与设置订阅，刷新/取消隐藏后立即重建列表。
4. 运行 GalleryFilter/GalleryComments 测试确认通过。

### Task 2: 话廊真实交互状态收口

**Files:**
- Modify: `entry/src/main/ets/pages/PostPage.ets`
- Modify: `entry/src/main/ets/pages/PosterDetailPage.ets`
- Modify: `entry/src/main/ets/pages/SearchPage.ets`
- Test: `entry/src/test/GalleryComments.test.ets`

**Steps:**
1. 写失败测试，覆盖设置变更后评论/列表不显示隐藏内容、关闭横滑仍可点击 tab、纯图片评论成功后刷新。
2. 运行测试确认失败。
3. 修正页面生命周期、设置订阅、评论刷新和横滑状态同步。
4. 运行完整本地测试并用 devecocli debug build 验证 ArkTS。

### Task 3: 原生课程同步契约强化

**Files:**
- Modify: `entry/src/main/ets/services/jw/courseScheduleApiRepository.ts`
- Modify: `entry/src/main/ets/services/schoolSchedule/CourseScheduleRepository.ts`
- Modify: `entry/src/main/ets/pages/settings/CalendarSettingPage.ets`
- Test: `entry/src/test/CourseScheduleRepository.test.ets`

**Steps:**
1. 写失败测试，覆盖课程接口空响应、错误响应、非法周次、重复课程 ID，以及刷新失败时本地旧课表不被清空。
2. 运行测试确认失败。
3. 增强原生接口解析和字段归一化；课程刷新成功后才替换本地数据，失败保留旧数据并返回可理解错误。
4. 确认 CalendarSettingPage 使用学校原生接口并保留 ICS 回退注入路径。
5. 运行课程测试和完整本地测试。

### Task 4: 构建与设备验证

**Files:**
- No source changes expected.
- Evidence: `entry/build/`

**Steps:**
1. 使用 `devecocli build --build-mode debug` 编译。
2. 使用 `devecocli build --build-mode release` 编译。
3. 如有设备，安装启动并验证话廊设置重启恢复、隐藏用户、评论过滤、课程刷新入口；记录日志和结果。
4. 更新本计划进度记录。

### 实施记录（2026-10-18）

- 话廊用户动态接入统一隐藏用户/匿名过滤，刷新与取消隐藏后会重新加载，加载更多不再因当前页被过滤为空而提前返回。
- 原生课程接口响应校验、课程行去重/非法周次跳过、刷新失败保留旧数据已完成；该能力原本已接入 CalendarSettingPage，本次未重建 ICS 路径。
- 登录链路按 Android 行为修正为“WebVPN 验证 → /user/register 换取 fake_cookie”；之前先调 /user/login 会对有效账号返回 500（用户名或密码错误）。本机使用 debug 的 ykl 账号按该协议得到 WebVPN 200、register 200、话廊只读列表 200（5 条）。
- 为调试凭据读取增加 AppStorage 上下文初始化和 release 防护。设备凭据文件传输受当前自动审批策略拒绝，因此未在设备上运行真实账号调试用例；源码未嵌入账号，调试目标保持 NONE。
- hvigor test --no-daemon、devecocli build --build-mode debug、devecocli build --build-mode release 均成功，release 包已覆盖安装到 127.0.0.1:5555。
- 最新 Test-Parity 门禁通过：本地 319 项、设备 103 项，debug/release 构建、设备测试、冷启动、日志分享和崩溃门禁均为 0 失败。

