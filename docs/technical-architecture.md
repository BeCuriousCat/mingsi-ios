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
- 当前目标。
- 当前阻塞。
- 相关历史记录。

### GrowthFeature

负责：

- 周度校准。
- 月度成长。
- 五项趋势指标。
- 历史证据链接。

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
- 本地通知可在用户确认主线任务后创建。
- Today state machine 不允许跳过必要确认步骤。
