# 明思 MVP Task Breakdown

## Milestone 0: Product Documents

Goal:

- 固化 MVP 范围和技术边界。

Tasks:

- 更新 Product Brief。
- 更新 PRD。
- 更新 UX Flow。
- 更新 Prompt Spec。
- 更新 Technical Architecture。
- 新增 Data Architecture。
- 更新 MVP Task Breakdown。

Exit criteria:

- 文档全部使用产品名“明思”。
- 文档明确 MVP 直连 GLM，用户自带 API Key。
- 文档明确 SQLite/GRDB + Repository + Migration。
- 文档明确 Quick / Standard / Deep。
- 文档明确后端代理、角色卡、框架包、Mirror Cards、能力图谱不是 MVP。

## Milestone 1: iOS Project Skeleton

Goal:

- 创建 SwiftUI iPhone App 骨架。

Tasks:

- 初始化 Xcode project。
- 设置 iOS 17+。
- 创建 AppShell。
- 创建五个 Tab：今日、历史、项目、成长、设置。
- 创建 placeholder views。
- 添加 Resume Today banner 基础结构。
- 添加 DesignSystem 初版：颜色、字体、间距、卡片、motion tokens。

Exit criteria:

- App 可以在 simulator 构建运行。
- 五个 Tab 可切换。
- Today 状态可在 Tab 切换时保持。
- UI 感觉原生、克制，不像网页 dashboard。

## Milestone 2: Persistence and Security

Goal:

- 建立本地数据底座。

Tasks:

- 引入 SQLite/GRDB。
- 创建 Repository protocols。
- 创建本地 migration harness。
- 实现 DailyEntry、ThinkingCard、LensSession、ReflectionQuestion、Quest、Verification、PrincipleAsset、MetricSnapshot、PromptRun。
- 所有核心记录加入 schemaVersion。
- 创建 Keychain service 保存 GLM API Key。
- 添加基础 fixture migration tests。

Exit criteria:

- App 能保存和读取每日草稿。
- App 能保存卡片、任务、验证和原则。
- API Key 只存在 Keychain。
- Fixture migration 不丢失 rawText、confirmed cards、quests、verification、principles。

## Milestone 3: Prompt and GLM Core

Goal:

- 建立模型调用底座。

Tasks:

- 创建 PromptProvider protocol。
- 实现 LocalPromptProvider。
- 创建 LLMClient protocol。
- 实现 DirectGLMClient。
- 创建 mock LLM client 供 UI 开发和测试。
- 实现 PromptRun 记录。
- 为主要 prompt 添加 JSON schema decoding。

Exit criteria:

- 没有页面直接拼 prompt。
- 没有页面直接调用 GLM。
- Mock client 可以驱动完整 Today loop。
- DirectGLMClient 能读取 Keychain 中的 API Key 并返回结构化响应。

## Milestone 4: Daily Capture and Card Organization

Goal:

- 用户可以输入并整理每日内容。

Tasks:

- 实现 Today Capture screen。
- 添加 Quick / Standard / Deep 分段控件。
- 添加隐私提醒。
- 添加 autosave。
- 调用 OrganizeCards use case。
- 渲染 ThinkingCard 列表。
- 支持编辑、删除、合并、标记重要、标记敏感。
- 支持 Confirm Cards。

Exit criteria:

- 用户能输入、关闭、重新打开并继续。
- 用户能整理出可编辑卡片。
- 敏感卡片可排除出后续模型调用。
- 最终追问只基于 confirmed cards。

## Milestone 5: Lenses and Questions

Goal:

- 加入思考透镜和追问。

Tasks:

- 实现 lens recommendation use case。
- 实现 question generation use case。
- 创建 LensCard UI。
- 创建 QuestionCard UI。
- 按模式控制问题数量。
- 强制至少回答一个问题后才能生成任务。

Exit criteria:

- 用户可接受推荐透镜或手动选择。
- Quick、Standard、Deep 的追问深度不同。
- 问题具体、可回答、与卡片相关。

## Milestone 6: Tomorrow Quest and Reminder

Goal:

- 将思考转化成明日行动。

Tasks:

- 实现 quest generation use case。
- 创建 QuestCard UI。
- 支持 main、side、observation。
- 主线任务必须有 completion criteria。
- 支持编辑和确认。
- 实现 ReminderService protocol。
- 实现 LocalNotificationReminder。

Exit criteria:

- 用户能确认一个主线任务。
- 任务包含 why、completion criteria、resistance、reflection question。
- 用户可设置本地通知提醒。

## Milestone 7: Verification and History

Goal:

- 关闭行动校准闭环。

Tasks:

- 检测未验证 active main quest。
- 创建 Verification screen。
- 保存 completion status、actual value、reason。
- 调用 verify quest prompt 生成 calibration note。
- 创建 History list。
- 创建 History detail。
- 支持 raw input 折叠。
- 显示卡片、透镜、回答、任务和验证。

Exit criteria:

- 用户第二天能先验证昨天主线任务。
- 验证结果被保存。
- 用户能在历史里看到完整证据链。

## Milestone 8: Principle Library and Growth

Goal:

- 让每日复盘产生长期资产。

Tasks:

- 实现 principle extraction use case。
- 创建 PrincipleCard UI。
- 支持保存、修改、忽略原则候选。
- 创建最小原则库入口。
- 创建周度校准视图。
- 创建月度成长视图。
- Growth 证据必须可链接到历史。

Exit criteria:

- 每次复盘结束最多生成 1 条原则候选。
- 用户可保存行动准则。
- Growth 报告不展示无证据结论。

## Milestone 9: UI System Hardening

Goal:

- 确保后续视觉、动画和卡片形态可以扩展。

Tasks:

- 创建 ThinkingCard、LensCard、QuestionCard、QuestCard、PrincipleCard、GrowthEvidenceCard。
- 所有组件从 ViewModel 渲染，不直接绑定数据库实体。
- 增加稳定 id 支持动画。
- 支持 reduced motion。
- 预留 component variant enum。

Exit criteria:

- 同一 ThinkingCard 可在列表、详情和报告证据中不同渲染。
- 增加角色卡或框架包不需要改 Today 主流程。
- 动画可以作为表现层添加，不影响数据模型。

## Milestone 10: Future Adapter Reserve

Goal:

- 预留后续服务端、Apple 同步和高级框架能力。

Tasks:

- 保留 RemotePromptProvider 接口。
- 保留 ProxyLLMClient 接口边界。
- 保留 AppleRemindersSync / AppleCalendarSync 类型边界。
- 保留 LensCard 的 role/person/custom 变体。
- 保留 PrincipleAsset 的验证字段。

Exit criteria:

- MVP 不依赖这些未来能力。
- 未来能力可以通过新增 adapter 或 feature module 实现。

## MVP Completion Criteria

MVP 完成时必须证明：

- 用户能完成一次完整 Today loop。
- 用户能用 Quick / Standard / Deep 选择不同训练深度。
- 用户能直连 GLM 完成卡片、透镜、任务和原则生成。
- 用户能保存本地数据并重启后恢复。
- 用户能设置本地通知提醒明日任务。
- 用户能第二天验证昨天任务。
- 用户能回看历史证据。
- 用户能保存一条行动准则。
