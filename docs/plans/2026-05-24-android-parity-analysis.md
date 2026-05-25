# BIT101 Android 对齐差距分析

日期：2026-05-24

Android 参考项目已克隆到 `BIT101-Android/`，当前参考提交为 `49310f0 也修改内部版本号`。本报告只做静态功能和架构对比，不包含构建、安装或运行验证。

## 总结

HarmonyOS 版已经覆盖了核心主链路：登录、BIT101 后端会话、话廊列表/详情/发帖/评论/点赞/举报、用户主页/关注、课程表展示、乐学 DDL 同步、地图、Web 容器和基础设置。

主要短板不在“有没有基础页面”，而在学生工具深度和状态持久化能力。Android 的课表域是完整的 `课表 + DDL + 空教室` 工具套件，并且本地 Room 数据库保存课程、考试、自定义日程和 DDL；HarmonyOS 目前更偏向“从接口/ICS 同步后展示”，本地编辑、完成状态、考试和空教室能力明显落后。

## 高优先级差距

| 优先级 | 功能域 | Android 现状 | HarmonyOS 现状 | 对齐建议 |
| --- | --- | --- | --- | --- |
| P0 | 空教室查询 | `ScheduleScreen` 有第三个 Tab `空教室`；通过校方接口获取校区、楼宇、教室占用，按当前课节计算空闲/繁忙并缓存到下一课节边界。 | 没有页面、服务、设置入口；代码检索不到 `空教室/freeClassroom/classroom` 对应实现。 | 新增 `FreeClassroomPage`、`FreeClassroomService`、设置页；复用现有课节时间表计算当前/下一空闲状态。 |
| P0 | DDL 本地管理 | DDL 存 Room；支持新增、编辑、删除、完成勾选；乐学同步时按 `uid` 合并并保留 `done` 状态。 | `DdlList` 只读取 `LexueCalendarStore` 中的乐学事件，过滤后展示；没有本地 DDL CRUD 和完成状态。 | 新增 DDL 本地存储模型：`uid/source/title/time/detail/done`；乐学同步合并时保留用户状态；页面加新增/编辑/删除/完成。 |
| P1 | 考试安排 | Android 获取并保存考试安排，课表可叠加考试卡片，考试详情可添加到系统日历。 | 当前课程表设置只获取学期起始日期和课表；未发现考试接口、考试实体、考试展示。 | 接入校方 `getExamsData` 对应接口或现有可用来源；学期快照增加 exams；课表层叠加考试卡片。 |
| P1 | 自定义课程/日程 | Android 有 `CustomScheduleEntity`，课程表支持新增自定义日程。 | HarmonyOS 课表页面没有本地新增/编辑/删除课程或日程。 | 在学期存储中增加 `customItems`，课程详情页支持编辑用户自定义项。 |
| P1 | 更新检查 | Android 调 `/version`，支持最低版本、最新版本、忽略版本、强更弹窗。 | `AboutPage.checkUpdate()` 是模拟延迟并提示“当前已是最新版本”。 | 增加 `VersionService` 接 `/version`，实现自动检查、忽略版本、强制更新链接。 |

## 中优先级差距

| 优先级 | 功能域 | Android 现状 | HarmonyOS 现状 | 对齐建议 |
| --- | --- | --- | --- | --- |
| P1 | 设置完整度 | Android 设置包含账号、页面、主题、课程表、话廊、关于、DDL、空教室。 | HarmonyOS 设置缺少话廊设置和空教室设置。 | 补 `GallerySettingPage`、`FreeClassroomSettingPage`；设置项落到统一持久化层。 |
| P2 | 消息入口 | Android 有 `message` 路由，主实现是打开 `https://bit101.cn/message`；Mine ViewModel 也能取未读数，但 UI 中消息按钮似乎被注释。 | HarmonyOS 未发现消息入口或未读数服务；可通过 Web 容器补齐。 | 先做 Web 消息入口和未读数 badge；后续再考虑原生消息列表。 |
| P2 | Web 容器细节 | Android 使用可保存状态的 WebView，注入 `fake_cookie`，有文件选择和 URL 拦截。 | HarmonyOS `WebPage` 已支持 JS、localStorage、file selector 和成绩页自动填充；`WebBrowserPage` 是更轻的通用页，文件访问关闭，状态保存能力不明显。 | 统一两个 Web 页面能力：外链拦截、文件选择、状态恢复、统一 token/localStorage 注入策略。 |
| P2 | 成绩/试卷/课程资料 | Android API 层有 `/scores`、`/scores/report`、`/papers`、`/courses`、`/courses/histories`；Mine 中成绩/试卷入口处于注释状态。 | HarmonyOS 只有 Web 成绩页自动填充和 `/courses/schedule` 课表下载；没有这些原生 API 服务。 | 不作为首批硬对齐；先保留 Web 入口，等产品确认后再原生化。 |
| P2 | 话廊个性化 | Android 有话廊设置：隐藏机器人帖、搜索中隐藏机器人、严格模式、屏蔽用户、横向滚动。 | HarmonyOS 话廊主功能基本完整，但没有对应设置页和筛选持久化。 | 增加本地 Gallery settings，并在列表请求/展示层统一生效。 |

## HarmonyOS 不是落后的部分

- 学校认证和 WebVPN/Lexue 恢复链路：HarmonyOS 已有 `services/school`、`BitSsoAuto`、`BitSsoSession` 和多套 debug case，协议拆分比 Android 更明确。这里不建议照搬 Android。
- 话廊主链路：HarmonyOS 已有帖子列表、搜索、发帖/编辑、创作者声明、详情、评论、点赞、删除和举报，功能面接近 Android。
- Web 成绩页自动填充：HarmonyOS 有针对 `/score` 的自动填充逻辑，Android 目前主要是 Web 容器通用能力。

## 架构差距

Android 的数据层结构更稳定：

- `Room` 保存课程、考试、自定义日程、DDL。
- `DataStore` 和 `SettingItem<T>` 统一管理设置，所有设置都有 `Flow`。
- `Repo + ViewModel + Flow/LiveData` 让页面只消费状态和动作。

HarmonyOS 当前更分散：

- 页面中直接持有 repository 或 store，部分设置用 `AppStorage/PersistentStorage`，部分用 preferences 或文件。
- DDL 和课表缺少统一本地领域模型，后续做完成状态、考试、自定义日程时会重复造状态管理。

对齐时建议先做轻量统一层，而不是直接堆页面：

1. `settings`：封装页面、主题、课表、DDL、话廊、空教室设置。
2. `schoolSchedule`：封装课程、考试、自定义日程、课节时间、当前学期。
3. `ddl`：封装乐学同步事件和用户自建 DDL 的合并结果。
4. `freeClassroom`：封装校区、楼宇、教室占用和缓存。

## 推荐执行顺序

1. P0：补空教室最小闭环
   - 服务：校区/楼宇/教室占用接口。
   - 存储：当前校区、隐藏忙碌教室、空闲分钟阈值。
   - UI：在 `ScheduleShellPage` 增加 `空教室` Tab。
   - 验证：登录后能加载楼宇，展开楼宇能看到空闲/繁忙状态。

2. P0：重做 DDL 为“同步 + 本地管理”
   - 本地模型保存 `done` 和用户手工 DDL。
   - 乐学同步按 `uid` upsert，保留 `done`。
   - UI 加新增、编辑、删除、完成勾选。
   - 验证：同步后勾选完成，再次同步不丢状态。

3. P1：考试安排和自定义日程
   - 接入考试安排，叠加到课表。
   - 自定义课程/日程和考试详情共用详情/编辑入口。

4. P1：真实更新检查
   - 对齐 `/version` 数据模型。
   - 实现自动检查、忽略该版本、强制更新。

5. P2：补设置和消息入口
   - 话廊设置、空教室设置。
   - 消息 Web 入口和未读数展示。

## 关键参考文件

Android：

- `BIT101-Android/features/schedule/src/main/java/cn/bit101/android/features/schedule/ScheduleScreen.kt`
- `BIT101-Android/features/schedule/src/main/java/cn/bit101/android/features/schedule/classroom/FreeClassroomSearchViewModel.kt`
- `BIT101-Android/features/schedule/src/main/java/cn/bit101/android/features/schedule/ddl/DDLScheduleViewModel.kt`
- `BIT101-Android/data/src/main/java/cn/bit101/android/data/database/BIT101Database.kt`
- `BIT101-Android/features/versions/src/main/java/cn/bit101/android/features/versions/UpdateDialog.kt`
- `BIT101-Android/features/setting/src/main/java/cn/bit101/android/features/setting/SettingScreen.kt`

HarmonyOS：

- `entry/src/main/ets/pages/ScheduleShellPage.ets`
- `entry/src/main/ets/components/deadline/DdlList.ets`
- `entry/src/main/ets/services/storage/LexueCalendarStore.ts`
- `entry/src/main/ets/pages/settings/Settings.ets`
- `entry/src/main/ets/pages/settings/AboutPage.ets`
- `entry/src/main/ets/services/jw/timetableRepository.ts`
- `entry/src/main/ets/services/storage/semesterStore.ts`
