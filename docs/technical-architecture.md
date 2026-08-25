# 明思 Technical Architecture

## vNext Coordination Boundary (2026-07-15)

The active architecture adds matter-scoped repositories and coordinators without exposing internal loop states in SwiftUI:

```text
TodayView -> AppStore -> TrainingCaseCoordinator
                     -> VerificationCoordinator / transactional settlement repository
                     -> GuidanceEngine (eligibility only)
                     -> GuidanceAIService -> CentralLLMDecisionCenter
                     -> CoachDecisionAIService -> CentralLLMDecisionCenter
                     -> GrowthAIService / ProjectAIService / SideQuestAIService
                                             -> CentralLLMDecisionCenter
                     -> Project closure repository

Meaningful decision -> CentralLLMDecisionCenter -> PromptRun source ids
AI request -> PromptContextPayload.currentCase -> PromptRun source ids
```

Card, Quest, and Lens writes use Case-scoped repository APIs so saving Case A cannot soft-delete Case B. Switching first waits for queued persistence, then reloads the selected Case session and evidence. Live verification commits Verification, Quest status, and GrowthSettlement in one SQLite transaction. Provider-profile expansion remains outside this milestone.

## Architecture Summary

MVP 是一个本地优先的 iPhone SwiftUI App。用户自带 GLM API Key，App 直接调用 GLM API。Prompt、模型调用、存储、通知和 UI 都通过协议层解耦，保证后续可以迁移到服务端或替换实现。

MVP 高层结构：

```text
SwiftUI App
  -> Feature UseCases
  -> PromptProvider
  -> CentralLLMDecisionCenter
  -> LLMClient -> DirectGLMClient

SwiftUI App
  -> Repository Protocols
  -> SQLite/GRDB Storage

SwiftUI App
  -> ReminderService
  -> LocalNotificationReminder
```

MVP 不包含服务端代理，但必须预留：

```text
PromptProvider: LocalPromptProvider -> RemotePromptProvider
LLMClient: DirectGLMClient -> ProxyLLMClient
ReminderService: LocalNotificationReminder -> AppleRemindersSync / CalendarSync
```

`CentralLLMDecisionCenter` 是全局判断中心，而非本地状态机的替代品。当前生产路径为 `DirectGLMClient`；Pi 只可在未来作为服务端 `AgentRuntimeAdapter` 的隔离实验实现，且必须仍由中心以 `LLMClient` / `StreamingLLMClient` 调用。adapter 不得访问 iOS 数据库、Keychain、通知、HealthKit、位置、联系人、日历或 UI 状态，也不得拥有持久化与事务权威。触发条件和受控多轮协议见 `docs/agent-runtime-decision.md`；当前 3-7 天真实体验不实现 Pi。

## Core Principle

核心原则：

```text
Persist meaning, not presentation.
```

需要长期保存的是用户输入、确认后的卡片、回答、任务、验证、原则和证据链。UI 样式、卡片布局、动画状态和报表缓存不是事实源。

## Platform

- iOS 17+。
- SwiftUI。
- iPhone only for MVP。
- SQLite/GRDB for local persistence。
- Keychain for GLM API Key。
- UserNotifications for local reminders。

## Module Boundaries

### AppShell

负责：

- App 生命周期。
- Tab 导航。
- Today loop 状态入口。
- Resume Today banner。

不负责：

- 直接调用 GLM。
- 直接读写数据库。

### DesignSystem

负责：

- Color tokens。
- Typography。
- Spacing。
- Card styles。
- Motion tokens。
- Reduce motion 支持。

核心视觉语言：

```text
Calm Native Intelligence
```

### DomainCore

负责定义稳定领域模型：

- DailyEntry。
- ThinkingCard。
- LensSession。
- ReflectionQuestion。
- Quest。
- Verification。
- PrincipleAsset。
- MetricSnapshot。
- MetricContribution。
- Project。
- ProjectLink。
- ProjectMergeCandidate。
- ProjectInsight。
- PromptRun。

DomainCore 不依赖 SwiftUI、GLM SDK 或数据库实现。

### PersistenceCore

负责：

- SQLite/GRDB 初始化。
- 显式 migration。
- Repository 实现。
- 本地备份和导出。

所有 feature 只能依赖 repository protocol，不能直接依赖数据库表。

### PromptCore

负责：

- Prompt 模板。
- Prompt 版本。
- 输入/输出 schema 版本。
- LocalPromptProvider。
- 未来 RemotePromptProvider。

核心接口：

```swift
protocol PromptProvider {
    func template(for id: PromptID, mode: SessionMode) async throws -> PromptTemplate
}
```

Prompt 与上下文工程的产品规格以 `docs/prompt-context-engineering-prd.md` 为准。PromptCore 不只管理字符串模板，还必须为后续上下文检索和原则资产调用预留边界。

后续核心接口：

```swift
protocol ContextAssembler {
    func assemble(request: ContextRequest) async throws -> PromptContext
}

protocol PrincipleRetriever {
    func relevantPrinciples(for request: ContextRequest) async throws -> [PrincipleAsset]
}
```

模块职责：

- `PromptProvider` 只负责返回版本化 Prompt 模板。
- `ContextAssembler` 负责选择 raw input、cards、answers、principles、projects、growth weak signals 等上下文。
- `PrincipleRetriever` 负责从用户已确认原则中选 1-3 条相关原则。
- `TodayAIService` 只编排业务调用，不直接决定长期上下文检索策略。
- `CentralLLMDecisionCenter` 是所有需要判断、推荐、分类或总结的模型调用入口；它共享一个经过 PromptRun 审计的客户端实例。
- `LLMClient` 只负责传输，不理解产品语义。具体服务负责 schema 和证据边界，不能绕过中心直接创建新的生产模型客户端。
- 本地规则只负责客观资格、用户同意、频率与冷却、安全边界、权限和事务状态，不代替模型做内容决策。原则候选、教练模式摘要和支线邀请素材都只是受控输入材料；最终选择、解释、分类或总结必须由中央 LLM 完成。

### 情境化生活奇遇

`SideQuestContextSnapshot` 是发送给中央模型的最小当前情境：粗粒度场景、忙闲状态、匿名化上下文标记和动态约束。用户可在 Today 临时选择“在家”“在工作地点”“在熟悉地点”或“暂不确定”；这个修正仅在内存中保存至当天结束，并优先于系统模糊场景，不保存坐标、地点原文或系统原始记录。用户未同意生活奇遇前，`AppStore` 不调用任何情境 provider。

在用户主动授予 HealthKit 读取权限后，端侧 `AggregatingSideQuestHealthSummaryProvider` 仅计算过去三天步数、活动能量和睡眠时长的平均区间，并将其转换为不含数值的 token。查询结果、样本、来源、精确时间及数值均不进入 `SideQuestContextSnapshot` 或模型请求；无数据或拒绝读取时不产生健康 token。

模型负责 `offer` / `hold`、邀请内容和 `decisionRationale`；本地只验证 grounding token、资格、同意、冷却、安全及持久化状态。已经发出的 `SideQuestRun` 是不可变的事实快照，情境更改不会改写它或触发同日重复请求。Today 只在 AI run 有安全自然语言理由时展示“为什么现在推荐”，不暴露 prompt、grounding token 或原始数据。

情境资料是自愿、可编辑且可清除的本地最小资料：家/工作地点本地标签、各自可选的数值楼层与楼梯可用性、过渡时间、通勤/运动偏好、禁用类别和简短 constraints；`familiarPlace` 只可作为当前 snapshot scene，不是持久地点资料。模型不接收地点标签、地址、坐标、原始日历或健康样本；当前 payload 会发送活跃地点的数值 `floor_level` 与 `stairs_available`。`practical_place_home` / `workplace` 及其 `*_floor` / `*_stairs` 只在 scene 匹配时进入 `available_grounding_refs`，并有 `scene_*`、`availability_*` 和粗粒度健康 snapshot token。当前不存在设施、预约、预算或熟悉路线 token，因此模型不得建议游泳、远距离场馆、陌生路线或其他外部依赖活动；没有依据时必须 `hold` 或返回不依赖未知条件的体验。未来扩展这些条件必须先新增自愿字段和 grounding token。

未来受控多轮请求也必须由本地协调：purpose 限定的最小字段 allowlist，最多 2 个模型回合，且第二回合的任何补充情境均需用户逐项确认。模型和 `AgentRuntimeAdapter` 只能建议，不能自行操作现实世界、发通知、请求权限或写持久化；本地层仍负责隐私、同意、通知、幂等性和 SQLite 事务。详细契约见 `docs/agent-runtime-decision.md`。

上下文注入规则：

- `organizeCards` 不注入原则库，避免历史标签污染原始材料拆分。
- `generateQuestions` 可注入相关原则作为对照透镜。
- `generateQuests` 可注入相关原则和 active project hints，但任务必须来自当天材料和用户回答。
- `extractPrinciple` 必须注入相似原则用于去重和升级。
- `weeklyCalibration` / `monthlyGrowth` 必须引用 verification、metric contributions 和用户反馈。

### LLMCore

负责：

- GLM 请求封装。
- JSON 响应解析。
- 错误处理。
- PromptRun 记录。

核心接口：

```swift
protocol LLMClient {
    func complete<T: Decodable>(
        request: LLMRequest,
        responseType: T.Type
    ) async throws -> T
}
```

MVP 实现：

```text
DirectGLMClient
```

协议策略：

- 默认按 OpenAI-compatible Chat Completions 调用。
- Base URL 统一视为 `.../v4` 这类 base path；如果用户误填完整 `.../chat/completions`，客户端会归一化回 base path 后再拼接。
- 默认请求带 `response_format: {"type":"json_object"}`，以提高结构化输出稳定性。
- 如端点返回 400/422 且错误体明确拒绝 `response_format`，`DirectGLMClient` 自动用同一 endpoint 重试一次，不带 `response_format`，继续依赖 Prompt 要求模型输出 JSON。
- 这不是长期的多协议系统；长期通过 `LLMClient`/`PromptProvider` 切到服务端配置或显式 endpoint profile。

失败处理：

- 连接测试只验证最小请求链路，不证明正式 Prompt 的 schema 输出一定可用。
- `LLMClientError.userFacingMessage` 必须向 UI 传递 HTTP 状态、网络错误或响应异常，不能只显示“调用失败”。
- Today 生成步骤在 vNext 正式运行中不会用本地启发式替代模型判断；无 Key、模型失败或质量门失败时，AppStore 保留已确认材料、记录具体失败并按 `PromptID` 提供待补跑项。
- `retryCurrentAIStep()` 只重试当前步骤对应的 Prompt。本地 fallback 仅允许显式注入式测试/预览服务和旧流程夹具，不得进入 vNext 生产路径。
- `retryPendingAIRepairs()` 只补跑待修复的 Prompt，并在成功后移除对应项。
- 当前 MVP 通过 `PromptTracingLLMClient` 持久记录成功/失败 PromptRun。
- API Key 缺失时走 `MissingAPIKeyLLMClient` 明确抛出失败；正式路径不能用 mock 响应伪装成 GLM 成功。vNext 无 Key 时只显示中央模型不可用并进入可补跑状态；本地 fallback 只属于注入式测试/预览和旧流程夹具。
- App 启动加载本地草稿时，会读取 `PromptRunRepository.unresolvedFailures`，把属于当前 DailyEntry 的可修复 Prompt 恢复到待补跑队列。
- GLM 直连默认请求超时为 300 秒；流式请求以 300 秒无新 token 作为空闲超时，超时错误必须明确显示为超时，避免用户无法判断是 Key、Base URL、额度还是等待时间问题。
- Verification 失败时，vNext 正式流程不会保存本地伪校准或伪结算；用户保留当前证据并重试中央 LLM。仅显式注入式测试/预览和旧流程夹具允许显示带标记的本地草稿。
- 今日训练生成统一支持 SSE 流式生成。整理卡片逐步展示候选卡片；追问、明日验证、原则与结果校准只在完整 JSON 通过解析和质量门槛后写入业务数据，但必须向 UI 回报连接、首个数据包和持续接收状态。

### Streaming Card Generation

MVP 把模型调用拆成双协议：

```swift
protocol LLMClient {
    func complete(_ request: LLMRequest) async throws -> Data
}

protocol StreamingLLMClient {
    func stream(_ request: LLMRequest) -> AsyncThrowingStream<LLMStreamEvent, Error>
}
```

`DirectGLMClient` 实现两条路径：

- `complete(_:)`：`stream=false`，用于不需要过程反馈的兼容路径。
- `stream(_:)`：`stream=true`，使用 `URLSession.bytes(for:)` 读取 SSE；除 `choices[0].delta.content` 外，还需回报请求已发出、HTTP 已连接和已收到 SSE 数据包。兼容模型的 reasoning-only 数据包只作为活动信号，不展示或混入结构化业务输出。

`organizeCards` 的流式输出使用受控 XML-like 协议，而不是半截 JSON：

```xml
<MINGSI_STREAM version="1">
<CARD>
<TYPE>fact</TYPE>
<TITLE>会议目标没有提前定义</TITLE>
<BODY>今天会议推进了很多讨论，但会前没有明确必须确认的事项。</BODY>
<IMPORTANCE>high</IMPORTANCE>
<SENSITIVITY>normal</SENSITIVITY>
<CONFIDENCE>medium</CONFIDENCE>
<REASON>这是可验证的流程问题，不是情绪判断。</REASON>
</CARD>
</MINGSI_STREAM>
```

白名单标签：

- `MINGSI_STREAM`
- `CARD`
- `TYPE`
- `TITLE`
- `BODY`
- `IMPORTANCE`
- `SENSITIVITY`
- `CONFIDENCE`
- `REASON`

临时 UI 状态：

```swift
struct StreamingCardDraft: Identifiable, Hashable {
    let id: UUID
    var type: String
    var title: String
    var body: String
    var importance: String
    var sensitivity: String
    var confidence: String
    var reason: String
    var status: StreamingCardStatus
}

enum StreamingCardStatus {
    case receiving
    case closed
    case invalid(String)
}
```

`XMLStreamingCardAssembler` 负责：

- 维护 buffer、当前卡片、当前字段、已闭合卡片和解析错误。
- 遇到 `<CARD>` 创建临时卡片。
- 遇到字段标签后把后续文本追加到对应字段。
- 遇到 `</CARD>` 校验并闭合卡片。
- 流中断时保留已闭合卡片，当前未闭合卡片标记为 invalid。

数据边界：

- `StreamingCardDraft` 只存在于 `AppStore` 内存和 Today UI。
- 数据库仍只保存正式 `ThinkingCard`。
- 只有闭合且校验通过的 `StreamingCardDraft` 可以转换为 `ThinkingCard`。
- 只有用户确认后的 `ThinkingCard` 可以进入追问、任务、历史、项目和成长证据。
- PromptRun 可以保存拼接后的 raw stream 作为 responseJSON；MVP 不需要 token-level stream event 表。
- `unresolvedFailures` 会用同一 Prompt/source/model 的后续成功记录抵消旧失败，避免已修复失败再次出现。

未来实现：

```text
ProxyLLMClient
```

### NotificationCore

负责：

- 本地通知授权。
- 明日主线任务提醒。
- 通知状态记录。

核心接口：

```swift
protocol ReminderService {
    func schedule(_ request: ReminderRequest) async throws
    func cancel(id: String) async
}
```

MVP 实现：

```text
LocalNotificationReminder
```

未来实现：

```text
AppleRemindersSync
AppleCalendarSync
```

## Feature Modules

### DailyLoopFeature

负责 Today 主状态机：

```text
VerifyYesterday
Capture
Organizing
ReviewCards
SelectMode
SelectLens
AnswerQuestions
ReviewQuests
ExtractPrinciple
SessionComplete
```

### HistoryFeature

负责历史证据层：

- 按日期浏览。
- 查看单日详情。
- 过滤卡片、透镜、任务和验证。
- 链接到 Growth 和 Projects。

### ProjectFeature

负责抽象项目上下文：

- 项目名称。
- 当前目标和成功标准。
- 当前阻塞和开放问题。
- 项目候选创建。
- 项目关联建议。
- 项目合并候选。
- 项目进展信号。
- 项目拆分、重命名、归档和恢复。
- 相关历史记录。
- 项目中的思考变化。

关键边界：

- ProjectFeature 不从 UI 卡片结构推断项目，只消费 confirmed domain records。
- AI 只能生成 project candidate、project link candidate、project insight 和 merge candidate。
- 正式项目创建、合并和归档必须由用户确认。
- ProjectInsight 是解释层，必须带 sourceRefs；没有证据时 Project UI 显示证据不足。

### GrowthFeature

负责：

- 周度校准。
- 月度成长。
- 五项趋势指标。
- 指标变化解释。
- 正向/负向贡献事件。
- 历史证据链接。
- 下一阶段训练重点。

关键边界：

- GrowthFeature 不能展示没有 evidenceRefs 的结论。
- MetricSnapshot 只是报告快照；MetricContribution 才是分数变化的解释层。
- UI 展示分数时必须能 drill down 到 source record。

### SettingsFeature

负责：

- GLM API Key 输入和 Keychain 保存。
- 默认训练模式。
- 本地通知权限。
- 数据导出和删除。
- 隐私说明。

## Data Flow

日常训练数据流：

```text
DailyEntry(rawText, mode)
  -> OrganizeCards prompt
  -> ThinkingCard drafts
  -> user-confirmed ThinkingCards
  -> LensSession
  -> ReflectionQuestions + answers
  -> Quest drafts
  -> confirmed Quest
  -> LocalNotificationReminder
  -> next-day Verification
  -> PrincipleAsset candidate
  -> MetricSnapshot evidence
```

项目聚合数据流：

```text
confirmed DailyEntry + ThinkingCards + Quests + Verifications + Principles
  -> SuggestProjectLinks prompt
  -> ProjectLink candidates
  -> user confirmation
  -> GenerateProjectInsights prompt
  -> ProjectInsight progress and thinking-change records
  -> Project timeline and progress
  -> SuggestProjectMerge prompt
  -> ProjectMergeCandidate
  -> user merge / reject / dismiss
```

成长归因数据流：

```text
weekly/monthly History evidence
  -> WeeklyCalibration / MonthlyGrowth prompts
  -> MetricSnapshot draft
  -> MetricContribution positive/negative events
  -> Growth UI
  -> evidence deep link to History or Project
  -> next training focus
  -> Today lens/question recommendation
```

所有 AI 输出都必须记录：

- promptId。
- promptVersion。
- inputSchemaVersion。
- outputSchemaVersion。
- modelProvider。
- modelName。
- generatedAt。

## Local Persistence

存储策略详见 `docs/data-architecture.md`。

技术基线：

- SQLite/GRDB。
- 显式 migrations。
- 每条核心记录包含 `schemaVersion`。
- 软删除优先于硬删除。
- 原始输入和用户确认内容默认不自动删除。
- 报表和 UI 缓存可以重建。

Repository 边界：

```swift
protocol ProjectRepository {
    func saveProject(_ project: Project) async throws
    func activeProjects() async throws -> [Project]
    func project(id: Project.ID) async throws -> Project?
}

protocol ProjectLinkRepository {
    func saveLink(_ link: ProjectLink) async throws
    func links(for projectId: Project.ID) async throws -> [ProjectLink]
    func links(forSourceIds sourceIds: [String]) async throws -> [ProjectLink]
    func updateLinkConfirmation(_ isConfirmed: Bool, linkId: ProjectLink.ID) async throws
}

protocol ProjectInsightRepository {
    func saveInsight(_ insight: ProjectInsight) async throws
    func insights(for projectId: Project.ID) async throws -> [ProjectInsight]
    func updateInsightFeedback(_ feedback: ProjectFeedback, insightId: ProjectInsight.ID) async throws
}

protocol ProjectMergeCandidateRepository {
    func saveMergeCandidate(_ candidate: ProjectMergeCandidate) async throws
    func pendingMergeCandidates() async throws -> [ProjectMergeCandidate]
    func updateMergeCandidateStatus(_ status: ProjectMergeStatus, candidateId: ProjectMergeCandidate.ID) async throws
}

protocol MetricSnapshotRepository {
    func saveSnapshot(_ snapshot: MetricSnapshot) async throws
    func latestSnapshot() async throws -> MetricSnapshot?
    func snapshot(id: MetricSnapshot.ID) async throws -> MetricSnapshot?
}

protocol MetricContributionRepository {
    func saveContribution(_ contribution: MetricContribution) async throws
    func contributions(for snapshotId: MetricSnapshot.ID) async throws -> [MetricContribution]
    func updateContributionFeedback(_ feedback: MetricContributionFeedback, contributionId: MetricContribution.ID) async throws
}
```

MVP 可以先实现最小读写，但接口必须按 ProjectLink 和 MetricContribution 预留，避免后续只能重建数据。

## Security and Privacy

- GLM API Key 只存 Keychain。
- 不写入 UserDefaults、SQLite 或代码常量。
- 用户输入前展示隐私提醒。
- 敏感卡片可从后续模型调用中排除。
- 本地通知内容默认简洁，避免暴露敏感细节。

## Future Server Migration

未来如果需要服务端，迁移路径是增量的：

```text
LocalPromptProvider -> RemotePromptProvider
DirectGLMClient -> ProxyLLMClient
Local report generation -> server-assisted report generation
Local-only storage -> optional encrypted sync
```

不可做的事情：

- 不允许 UI 直接依赖 prompt 文本。
- 不允许页面直接调用 GLM。
- 不允许将语义数据只存成 UI 展示结构。

## Testing Strategy

MVP 需要的测试边界：

- Repository 能保存和读取每日草稿。
- Migration fixture 不丢失 rawText、confirmed cards、quests、verification、principles。
- Prompt JSON 能被严格解析。
- LLMClient mock 能驱动完整 Today loop。
- ProjectLink 和 MetricContribution 必须有 sourceId，不能生成无证据记录。
- 本地通知可在用户确认主线任务后创建。
- Today state machine 不允许跳过必要确认步骤。
