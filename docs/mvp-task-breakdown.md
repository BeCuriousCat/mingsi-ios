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

Pre-development gate:

- PRD, UX Flow, Data Architecture, Prompt Spec, Technical Architecture, UI Design Draft, and MVP Task Breakdown must agree on MVP scope.
- Daily loop state names must match across PRD, UX, data, and implementation.
- Projects and Growth must be evidence-backed in every document; no placeholder-only tab is acceptable.
- Non-goals must remain out of implementation except for explicit adapter boundaries.
- Prompt outputs that affect Projects or Growth must include source ids.
- If any item above is not true, update docs before writing more app code.

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
- 实现 DailyEntry、ThinkingCard、LensSession、ReflectionQuestion、Quest、Verification、PrincipleAsset、Project、ProjectCandidate、ProjectLink、ProjectMergeCandidate、ProjectInsight、MetricSnapshot、MetricContribution、PromptRun。
- 所有核心记录加入 schemaVersion。
- 创建 Keychain service 保存 GLM API Key。
- 添加基础 fixture migration tests。

Exit criteria:

- App 能保存和读取每日草稿。
- App 能保存卡片、任务、验证和原则。
- API Key 只存在 Keychain。
- Fixture migration 不丢失 rawText、confirmed cards、quests、verification、principles。
- ProjectLink 和 MetricContribution 必须保留 sourceId，不能变成无证据摘要。
- ProjectInsight 必须能从 ProjectLink 重建；thinking_change 和 blocker_change 需要 before/after 来源。

## Milestone 3: Prompt and GLM Core

Goal:

- 建立模型调用底座。
- 建立可审计、可演进的 Prompt 与上下文工程底座，详见 `docs/prompt-context-engineering-prd.md`。

Tasks:

- 创建 PromptProvider protocol。
- 实现 LocalPromptProvider。
- 预留 ContextAssembler protocol。
- 预留 PrincipleRetriever protocol。
- 创建 LLMClient protocol。
- 创建 StreamingLLMClient protocol。
- 实现 DirectGLMClient。
- DirectGLMClient 支持 `stream=true` SSE，读取 `choices[0].delta.content`。
- 创建 mock LLM client 供 UI 开发和测试。
- 实现 PromptRun 记录。
- 实现 AI 调用失败的可见错误、同步骤重试、待补跑去重和后台补跑入口。
- 为 LLMRequest 预留 contextVersion 和 context refs。
- 为 generateQuestions、generateQuests、extractPrinciple 预留 relevantPrinciples 上下文。
- 为主要 prompt 添加 JSON schema decoding。
- 添加 project candidate、project link candidate、project merge candidate、weekly calibration、monthly growth contribution 的 schema decoding。
- 建立 Prompt Eval fixtures：卡片整理、透镜追问、任务生成、原则沉淀、成长归因。

Exit criteria:

- 没有页面直接拼 prompt。
- 没有页面直接调用 GLM。
- Mock client 可以驱动完整 Today loop。
- DirectGLMClient 能读取 Keychain 中的 API Key 并返回结构化响应。
- DirectGLMClient 能对 `organizeCards` 执行 SSE 流式读取。
- 正式 Prompt 失败时不能静默伪装成功；本地 fallback 必须可识别、可重试、可后台补跑。
- Project/Growth prompt 输出缺少 source id 时会被拒绝或降级为草稿。
- 每个生产 Prompt 的输入上下文、输出 schema、source ids、失败策略都能在 Prompt/上下文 PRD 中追溯。

## Milestone 4: Daily Capture and Card Organization

Goal:

- 用户可以输入并整理每日内容。

Tasks:

- 实现 Today Capture screen。
- 添加 Quick / Standard / Deep 分段控件。
- 添加隐私提醒。
- 添加 autosave。
- 调用流式 OrganizeCards use case。
- 实现 `XMLStreamingCardAssembler`。
- 实现 `StreamingCardDraft` 临时 UI 状态。
- 读取 `<CARD>` 时创建临时卡片，读取 `</CARD>` 时闭合并校验卡片。
- 渲染 ThinkingCard 列表。
- 支持编辑、删除、合并、标记重要、标记敏感。
- 支持 Confirm Cards。

Exit criteria:

- 用户能输入、关闭、重新打开并继续。
- 用户能在等待 GLM 时看到真实流式卡片生成过程。
- 流式卡片闭合并校验后能转为可编辑卡片。
- 流式失败时能保留已闭合卡片或显示本地 fallback，并允许重试当前步骤。
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

## Milestone 8: Project Evidence Layer

Goal:

- 让分散的每日复盘能被聚合成长期议题，并保持证据链。

Tasks:

- 实现 ProjectRepository。
- 实现 ProjectCandidateRepository。
- 实现 ProjectLink 保存和读取。
- 实现 ProjectMergeCandidate 保存和状态更新。
- 实现 ProjectInsight 保存、读取和用户反馈状态。
- 实现 suggest project links use case。
- 实现 generate project insights use case。
- 实现 suggest project merge candidates use case。
- 在 Daily ReviewCards 后展示项目关联建议。
- 创建 Project list。
- 创建 Project detail。
- Project detail 显示 Overview、Timeline、Thinking Change、Open Questions、Principles。
- Project progress 使用 Done / Learned / Unblocked / Newly Blocked / Next Bet 信号，不使用无来源百分比。
- 支持创建、重命名、归档项目。
- 支持候选项目的创建、改名后创建、忽略和拒绝。
- 支持接受/拒绝项目关联建议。
- 支持接受/拒绝合并候选。

Exit criteria:

- 用户能看到一个项目为什么存在。
- 项目中的每条进展都能跳回历史证据。
- 思考变化必须展示 before/after 证据；证据不足时不展示变化叙事。
- 合并项目不会丢失原项目和来源记录。
- Project 页面不展示没有来源的总结。

## Milestone 9: Principle Library and Growth

Goal:

- 让每日复盘产生长期资产。
- Growth 首页展示最近报告审查：闭环数、正负贡献数量、指标级证据摘要和下一步训练重点。

Tasks:

- 实现 principle extraction use case。
- 创建 PrincipleCard UI。
- 支持保存、修改、忽略原则候选。
- 创建最小原则库入口。
- 创建周度校准视图。
- 创建月度成长视图。
- 创建 MetricContribution 模型和读取逻辑。
- Growth 总览显示当前值、上期值和 delta。
- Growth 详情显示加分事件、减分事件和证据链接。
- 少于 3 次完整闭环或缺少 MetricContribution 时，Growth 显示证据不足而不是分数。
- 用户可标记 contribution 不准确，该反馈进入下次周/月报告上下文。
- Growth 证据必须可链接到历史。

Exit criteria:

- 每次复盘结束最多生成 1 条原则候选。
- 用户可保存行动准则。
- Growth 报告不展示无证据结论。
- 用户能看见某个指标为什么加分或减分。
- 每个加分/减分事件都能跳到历史或项目证据。
- Growth 分数必须能解释当前值、上期值、delta 和变化原因。

## Milestone 10: UI System Hardening

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

## Milestone 11: Future Adapter Reserve

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
- 用户能看到项目进展和项目中的思考变化。
- 用户能理解成长指标的变化原因。
- 用户能保存一条行动准则。
