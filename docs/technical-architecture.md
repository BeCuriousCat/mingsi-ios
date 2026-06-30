# 明思 Technical Architecture

## Architecture Summary

MVP 是一个本地优先的 iPhone SwiftUI App。用户自带 GLM API Key，App 直接调用 GLM API。Prompt、模型调用、存储、通知和 UI 都通过协议层解耦，保证后续可以迁移到服务端或替换实现。

MVP 高层结构：

```text
SwiftUI App
  -> Feature UseCases
  -> PromptProvider
  -> LLMClient
  -> DirectGLMClient

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
- `LLMClient` 只负责传输，不理解产品语义。

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
- Today 生成步骤失败时，AppStore 先生成本地 fallback，并按 `PromptID` 记录待补跑项。
- `retryCurrentAIStep()` 只重试当前步骤对应的 Prompt；重试失败时保留现有 fallback，不重复新增同一个待补跑项。
- `retryPendingAIRepairs()` 只补跑待修复的 Prompt，并在成功后移除对应项。
- 当前 MVP 通过 `PromptTracingLLMClient` 持久记录成功/失败 PromptRun。
- API Key 缺失时走 `MissingAPIKeyLLMClient` 明确抛出失败；正式路径不能用 mock 响应伪装成 GLM 成功，只能在 UI 中标记为本地 fallback / 可补跑。
- App 启动加载本地草稿时，会读取 `PromptRunRepository.unresolvedFailures`，把属于当前 DailyEntry 的可修复 Prompt 恢复到待补跑队列。
- GLM 直连默认请求超时为 300 秒；流式请求以 300 秒无新 token 作为空闲超时，超时错误必须明确显示为超时，避免用户无法判断是 Key、Base URL、额度还是等待时间问题。
- `organizeCards` 在 MVP 必须支持 SSE 流式生成；其他 Prompt 仍可使用非流式 JSON 返回。

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

- `complete(_:)`：`stream=false`，用于 questions、quests、verification、principles。
- `stream(_:)`：`stream=true`，使用 `URLSession.bytes(for:)` 读取 SSE，每行解析 `data:`，抽取 `choices[0].delta.content`。

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
