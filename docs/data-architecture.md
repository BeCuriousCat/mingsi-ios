# 明思 Data Architecture

## Purpose

这份文档定义明思 MVP 的本地数据架构。目标是保证产品后续改 UI、改卡片形态、改动线、迁移 Prompt 或增加服务端时，用户的长期思考资产不会丢失。

核心原则：

```text
保存语义，不保存展示。
保留来源，不只保留结论。
显式迁移，不做隐式覆盖。
用户确认内容默认不自动删除。
```

## Storage Baseline

MVP 使用：

```text
SQLite/GRDB
Repository 层
显式 migration
本地优先
```

GLM API Key 不进入数据库，存 iOS Keychain。

## Data Lifecycle

```text
Raw input
  -> AI draft cards
  -> User-confirmed cards
  -> Lens session
  -> User answers
  -> Quest
  -> Reminder
  -> Verification
  -> Principle asset
  -> Growth evidence
```

其中，用户确认后的内容是长期资产。AI 草稿可以被修改，但修改前后的来源关系必须保留。

## Authoritative Records

以下记录是事实源，不能被 UI 重构替代。

### UserProfile

用途：

- 保存训练目标、隐私确认和基础指标。

字段：

```text
id
schemaVersion
trainingGoals
privacyConfirmedAt
baselineMetricsJson
defaultSessionMode
createdAt
updatedAt
deletedAt
```

### Project

用途：

- 保存抽象项目上下文，不保存公司敏感原名。

字段：

```text
id
schemaVersion
name
goal
currentBottleneck
status
createdAt
updatedAt
deletedAt
```

### DailyEntry

用途：

- 保存每天的原始输入和流程状态。

字段：

```text
id
schemaVersion
date
rawText
sessionMode: quick | standard | deep
transcriptQuality
status: draft | organized | confirmed | reflected | quested | verified | incomplete
privacyFlagsJson
createdAt
updatedAt
deletedAt
```

保留规则：

- `rawText` 默认不自动删除。
- 用户可以手动删除整条 DailyEntry。
- 删除时默认软删除。

### ThinkingCard

用途：

- 保存结构化思考对象。

字段：

```text
id
schemaVersion
dailyEntryId
type: fact | problem | decision | risk | idea | communication | task
title
body
importance
sensitivity
confidence
isConfirmed
isExcludedFromModel
sourceRefsJson
tagsJson
rawPayloadJson
createdAt
updatedAt
deletedAt
```

保留规则：

- 用户确认后的卡片不被自动覆盖。
- 卡片合并时保留被合并卡片的 sourceRefs。
- UI 变体不能改变 ThinkingCard 的语义字段。

### LensSession

用途：

- 保存用户选择的透镜和对应问题。

字段：

```text
id
schemaVersion
dailyEntryId
lensId
lensType: basic | personInspired | role | custom
sessionMode
whyRecommended
createdAt
updatedAt
deletedAt
```

### ReflectionQuestion

用途：

- 保存透镜追问和用户回答。

字段：

```text
id
schemaVersion
lensSessionId
question
whyThisMatters
expectedAnswerType
answer
answeredAt
sourceCardIdsJson
rawPayloadJson
createdAt
updatedAt
deletedAt
```

### Quest

用途：

- 保存明日任务。

字段：

```text
id
schemaVersion
sourceDailyEntryId
type: main | side | observation
title
whyItMatters
completionCriteria
expectedResistance
reflectionQuestion
expectedValue
status: draft | active | completed | partial | failed | archived
dueDate
reminderId
linkedCardIdsJson
rawPayloadJson
createdAt
updatedAt
deletedAt
```

保留规则：

- 主线任务必须有 completionCriteria。
- 任务修改保留来源 DailyEntry。

### Verification

用途：

- 保存次日验证和校准。

字段：

```text
id
schemaVersion
questId
completionStatus: completed | partial | not_completed
actualValue: high | medium | low | unclear
reason
evidenceText
calibrationNote
likelyIssue
createdAt
updatedAt
deletedAt
```

### PrincipleAsset

用途：

- 保存从复盘中沉淀的可复用行动准则。

字段：

```text
id
schemaVersion
title
summary
triggerContext
actionsJson
successCriteria
exceptions
sourceDailyEntryIdsJson
sourceCardIdsJson
validationCount
lastValidatedAt
status: active | needs_review | archived
rawPayloadJson
createdAt
updatedAt
deletedAt
```

保留规则：

- 原则是长期资产。
- 原则更新应保留 revision。
- 未来原则对照功能必须基于 PrincipleAsset，而不是重新从历史文本里猜。

### MetricSnapshot

用途：

- 保存周度/月度成长报告快照。

字段：

```text
id
schemaVersion
period: weekly | monthly
startDate
endDate
clarity
valueJudgment
executionReliability
calibration
reflectionDepth
evidenceRefsJson
summary
createdAt
updatedAt
deletedAt
```

保留规则：

- MetricSnapshot 是报告快照，不是唯一事实源。
- 报告必须能链接到底层 DailyEntry、Quest、Verification 和 PrincipleAsset。

### PromptRun

用途：

- 保存每次 AI 调用的可追踪信息。

字段：

```text
id
schemaVersion
promptId
promptVersion
inputSchemaVersion
outputSchemaVersion
modelProvider
modelName
sessionMode
sourceRecordIdsJson
requestSummary
responseJson
error
createdAt
```

保留规则：

- 不保存隐藏推理链。
- 保存结构化输出和必要元数据。
- 用户可在设置中清除 PromptRun 日志，但清除日志不能删除已确认的用户内容。

## Derived or Disposable Data

以下数据可以重建，不是事实源：

- UI 展开/折叠状态。
- 动画状态。
- 卡片布局变体。
- 图表缓存。
- 临时排序。
- 未保存草稿缓存。
- 远程 prompt 缓存。

## Migration Rules

所有 migration 必须遵守：

```text
只做显式 migration。
迁移前创建备份。
不自动删除 rawText。
不覆盖用户确认后的卡片、任务、原则和验证。
未知字段放入 rawPayloadJson。
删除优先 soft delete。
迁移后写入 migration log。
```

示例：

旧版卡片只有 `problem`，新版拆成 `problem` 和 `assumption`。迁移时：

```text
无法可靠判断的旧 problem 仍保持 problem。
AI 或用户确认后才可转成 assumption。
原始 body 和 sourceRefs 必须保留。
```

## Future Server and Sync Readiness

MVP 不做服务端，但数据必须支持未来迁移：

- 所有核心记录使用稳定 UUID。
- 所有记录包含 `schemaVersion`。
- 记录时间统一使用 ISO 8601。
- 本地数据库可以导出 JSON。
- 未来 SyncRecord 可记录本地与服务端状态。

预留实体：

```text
ExternalSyncRecord
provider: server | apple_reminders | apple_calendar
localRecordId
externalRecordId
syncStatus
lastSyncedAt
error
```

## Privacy Rules

- API Key 只在 Keychain。
- 数据库不保存 GLM API Key。
- 敏感卡片可排除出模型调用。
- 本地通知标题默认不包含敏感细节。
- 用户可以导出和删除全部本地数据。

## Completion Requirement

数据架构完成的判断标准：

- DailyEntry、ThinkingCard、Quest、Verification、PrincipleAsset 能完整保存和读取。
- 迁移测试证明 rawText、confirmed cards、quests、verification、principles 不丢。
- PromptRun 能记录 prompt 和模型版本。
- UI 层不直接依赖数据库表结构。
