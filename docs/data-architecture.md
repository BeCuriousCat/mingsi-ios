# 明思 Data Architecture

## vNext Authoritative Additions (2026-07-25)

`DailyEntry` remains the day container, but is no longer the authority for one training session. `TrainingCase` is the matter aggregate, and `TrainingCaseSession` is the authority for its resumable loop state.

```text
DailyEntry 1 -> N TrainingCase
TrainingCase 1 -> 1 TrainingCaseSession
TrainingCase 1 -> N ThinkingCard / Quest / LensSession
Quest 1 -> 0..1 Verification -> 0..1 GrowthSettlement
SideQuestPreference 1 -> N SideQuestRun -> 0..1 SideQuestExperienceEvent
```

- Verification derives Case ownership through Quest.
- MetricContribution keeps `sourceCaseId` as an immutable attribution snapshot.
- ProjectLink supports `training_case`.
- ProjectClosureReview is retained across restore.
- TrainingCaseMerge is reversible and never deletes source evidence.
- TrainingCaseLink relates cross-day matters without rewriting ownership.
- UserGuidanceState and CoachTurnFeedback are local audit records.
- CoachPromptTurn attributes the exact coach output presented to the user and its quality-gate outcome.
- WeeklyGuidanceReviewRecord stores one immutable, reusable review per natural week.
- SideQuestLifeContextProfile keeps local-only home/workplace labels separate from typed practical context: optional floor level, stairs availability, and transition windows. Labels never cross the model boundary. Migration `v44_side_quest_practical_context_v2` preserves the legacy unscoped `floor_count` for local export and reassignment, but never treats it as model grounding.
- SideQuestPlanningRecord records every central-LLM `offer` or `hold` once per local day, with only the decision, a PromptRun reference and planning time. It deliberately stores no raw context, model text or user notes. `v45_side_quest_planning_audit` commits the record, updated preference, and an optional AI offer in one transaction so trial metrics cannot count a decision that the app failed to persist.
- SideQuestRun snapshots its catalog material and reward when offered. Completion writes one immutable SideQuestExperienceEvent transactionally; declining, expiring, or deferring never writes a negative event.
- SideQuestExperienceEvent is a separate life-growth ledger. It never creates a MetricContribution or changes the five evidence-based coaching metrics.
- HistoryRecord contains multiple TrainingCaseRecord values per day.

Migrations are `v33_training_cases`, `v34_case_ownership`, `v35_vnext_support`, `v36_vnext_closure_integrity`, `v37_coach_prompt_turns`, `v38_weekly_guidance_reviews`, `v39_side_quest_foundation`, `v44_side_quest_practical_context_v2`, and `v45_side_quest_planning_audit`. Before a file-backed pre-vNext store migrates, SQLite completes a WAL checkpoint and the app atomically copies the complete main database to a versioned backup. Migration is attempted only when no other database connection keeps that checkpoint busy; otherwise the original database remains untouched and the app reopens it through the legacy flow. The migrator runs against a working copy and replaces the live database only after all migrations complete. If migration fails, the original database is preserved or restored and the app reopens it through the legacy flow. Export includes all vNext tables and excludes Keychain secrets.

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
- 聚合多天 DailyEntry、ThinkingCard、Quest、Verification 和 PrincipleAsset。
- 支持用户确认的项目合并、拆分、归档和恢复。

字段：

```text
id
schemaVersion
name
goal
successCriteria
currentBottleneck
openQuestionsJson
status: active | watching | paused | archived
createdBy: user | ai_suggested
confidence
mergeHistoryJson
fieldRevisionJson
createdAt
updatedAt
deletedAt
```

保留规则：

- 项目是长期上下文，不能因为 UI 卡片变化而丢失。
- AI 只能创建 candidate，正式 Project 必须由用户确认。
- 项目合并必须保留原项目 id、名称、目标、阻塞和合并理由。
- 敏感原始文本不写入项目摘要，项目只能引用本地证据 id。
- goal、successCriteria、currentBottleneck 和 openQuestions 的修改需要保留 revision，避免后续看不出项目认知如何变化。

### ProjectCandidate

用途：

- 保存 AI 或用户从证据中提出但尚未确认的长期议题。
- 支持用户接受、改名后接受、暂时忽略或拒绝。
- 防止同类候选在短期内反复出现。

字段：

```text
id
schemaVersion
suggestedName
suggestedGoal
suggestedBottleneck
suggestedSuccessCriteria
reason
sourceRefsJson
privacyReviewNote
status: pending | accepted | renamed_and_accepted | dismissed | rejected
acceptedProjectId
createdBy: user | ai_suggested
confidence
createdAt
updatedAt
deletedAt
```

保留规则：

- sourceRefsJson 至少包含 1 个来源。
- rejected 候选必须保留 reason 和 sourceRefs，避免模型重复建议。
- accepted 后创建 Project，但 ProjectCandidate 不删除，用于审计创建来源。
- privacyReviewNote 不能保存公司原名、客户名或内部代号。

### ProjectLink

用途：

- 表示某条证据与某个项目的关系。
- 解耦项目 UI 和原始记录，方便后续重排页面或替换卡片形态。

字段：

```text
id
schemaVersion
projectId
sourceType: daily_entry | training_case | thinking_card | quest | verification | principle
sourceId
linkType: evidence | blocker | decision | task | principle | risk
confidence
isUserConfirmed
createdAt
updatedAt
deletedAt
```

保留规则：

- 未确认卡片不能作为强证据，只能作为 candidate link。
- 用户拒绝的 link 需要保留 rejection 记录，避免 AI 反复建议。

### ProjectMergeCandidate

用途：

- 保存 AI 提出的项目合并候选，等待用户确认。

字段：

```text
id
schemaVersion
sourceProjectId
targetProjectId
reason
overlappingEvidenceRefsJson
status: pending | accepted | rejected | dismissed
createdAt
updatedAt
```

### ProjectInsight

用途：

- 保存从项目证据链中生成的进展信号和思考变化说明。
- 让 Project 页面能回答“项目为什么在推进”和“我的思考哪里变了”。
- 作为可重建的解释层，不替代 ProjectLink 事实源。

字段：

```text
id
schemaVersion
projectId
insightType: progress | blocker_change | thinking_change | open_question_closed | principle_practiced | next_bet
title
summary
beforeText
afterText
sourceRefsJson
periodStart
periodEnd
confidence
userFeedback: accepted | inaccurate | dismissed | none
createdAt
updatedAt
deletedAt
```

保留规则：

- ProjectInsight 必须至少有 1 个 sourceRef；thinking_change 和 blocker_change 类型必须有 before 和 after 来源。
- 用户标记 inaccurate 的 insight 不参与 Growth 归因，但仍保留审计记录。
- ProjectInsight 可以随 Prompt 版本重算，但旧 insight 不直接覆盖，使用新 revision 或新记录。

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
loopState: verify_yesterday | capture | organizing | review_cards | select_mode | select_lens | answer_questions | review_quests | extract_principle | session_complete
displayStatus: draft | in_progress | quested | completed | incomplete
privacyFlagsJson
createdAt
updatedAt
deletedAt
```

保留规则：

- `rawText` 默认不自动删除。
- 用户可以手动删除整条 DailyEntry。
- 删除时默认软删除。
- `loopState` 是事实源，必须对应 Today state machine。
- `displayStatus` 是派生展示字段，可重建，不作为流程判断事实源。

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
- 流式整理阶段产生的 `StreamingCardDraft` 是临时 UI 状态，不写入 `ThinkingCard` 表。
- 闭合并通过 schema 校验的流式卡片只能成为待确认候选；只有 `isConfirmed == true` 或 `isExcludedFromModel == true` 的卡片才允许持久化。
- 后台 AI 补跑不得在已存在卡片、问题、任务或原则时重跑 `organizeCards`，避免覆盖用户已确认或下游生成的状态。
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
positiveContributionRefsJson
negativeContributionRefsJson
previousScoresJson
deltaScoresJson
metricReasonsJson
summary
createdAt
updatedAt
deletedAt
```

保留规则：

- MetricSnapshot 是报告快照，不是唯一事实源。
- 报告必须能链接到底层 DailyEntry、Quest、Verification 和 PrincipleAsset。
- MetricSnapshot 不能只保存分数，必须保存解释和贡献项引用。
- 少于 3 次完整闭环时，MetricSnapshot 可以保存为 insufficient_evidence 状态，但 UI 不能展示具体分数。
- 本期值必须可由 previousScoresJson、deltaScoresJson 和 MetricContribution 重建。
- 如果 contribution 缺少 sourceId，MetricSnapshot 只能保存为 draft 或 insufficient_evidence。

### MetricContribution

用途：

- 解释某个指标为什么加分或减分。
- 支持 Growth 页面展示“哪一次变化加分，哪一次变化减分”。

字段：

```text
id
schemaVersion
snapshotId
metric: clarity | value_judgment | execution_reliability | calibration | reflection_depth
direction: positive | negative
delta
title
reason
sourceType: daily_entry | thinking_card | quest | verification | principle | project
sourceId
sourceDailyEntryId
userFeedback: accepted | inaccurate | dismissed | none
candidateStatus: candidate | accepted | rejected
createdAt
updatedAt
deletedAt
```

保留规则：

- 每个 contribution 必须有 sourceId。
- sourceDailyEntryId 用于 Growth -> History day detail 的稳定跳转。
- 没有证据来源的 contribution 不允许进入正式报告。
- delta 是趋势解释，不是用户能力定论。
- 用户标记 inaccurate 后，该 contribution 保留但不再计入下一次趋势解释。
- candidate contribution 可以由 AI 生成，但进入 confirmed trend 前必须经过报告生成规则过滤。

### PromptRun

用途：

- 保存每次 AI 调用的可追踪信息。
- 作为后续跨启动补跑、错误审计和模型输出质量评估的持久来源。

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
contextRecordIdsJson
requestSummary
responseJson
error
createdAt
```

保留规则：

- 不保存隐藏推理链。
- 保存结构化输出和必要元数据。
- 用户可在设置中清除 PromptRun 日志，但清除日志不能删除已确认的用户内容。
- MVP 当前通过 `PromptTracingLLMClient` 写入 `prompt_runs`，成功调用保存 responseJSON，失败调用保存 error。
- Today 的待补跑横幅会在启动加载本地草稿后，从 `PromptRunRepository.unresolvedFailures` 恢复当前 DailyEntry 的可补跑 Prompt。
- `sourceRecordIdsJson` 记录本次请求直接来源，例如当前 DailyEntry、卡片、问题、任务。
- `contextRecordIdsJson` 记录被纳入上下文的辅助资产，例如相关 PrincipleAsset；旧记录在 v7 migration 中用 source ids 回填。
- 待补跑判断应按 `promptId + sourceRecordIdsJson + contextRecordIdsJson + promptVersion + modelName` 去重，避免同一个失败被重复计数。
- 如果同一 key 后续已有成功 PromptRun，旧失败不再视为 unresolved failure。

### HistoricalRetryCandidate

用途：

- 保存旧 AI 失败重试后的候选结果，等待用户评审。
- 防止历史补跑直接覆盖已经确认的证据链。
- 让历史输入在 GLM 失败后仍可恢复为长期资产。

字段：

```text
id
schemaVersion
failedPromptRunId
repairPromptRunId
promptId
sourceDailyEntryId
status: pending | retrying | candidate_ready | accepted | dismissed | blocked | failed
reconstructedInputSummary
candidatePayloadJson
error
blockedReason
createdAt
updatedAt
deletedAt
```

保留规则：

- 该实体需要显式 migration；不能作为无迁移变更引入。
- `failedPromptRunId` 指向原始失败 PromptRun。
- `repairPromptRunId` 指向补跑产生的新 PromptRun，失败和成功都要可审计。
- `candidatePayloadJson` 保存经过 schema 校验的候选语义输出，不保存 UI 布局。
- 接受候选前必须重新检查是否存在已确认卡片、问题、任务、原则、项目或成长证据。
- 被忽略、失败或阻断的 candidate 仍保留，用于解释为什么旧失败没有变成正式资产。

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

当前实现中的兼容迁移：

- `v6_metric_contribution_source_entry_backfill`：为已经执行过早期 Growth 表结构的本地数据库补齐 `metric_contributions.source_daily_entry_id`，避免历史/成长证据查询在旧库上失败。
- 该迁移只补列，不删除或重写已有贡献记录；旧记录的来源日期为空字符串，后续不会被当作可追溯证据计入展示跳转。

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
## vNext Closure Reliability (v36)

- `project_closure_reviews.principle_candidates_json` stores unaccepted, evidence-backed project closure principle candidates. Accepted principles remain global `principle_assets` and are linked back to the project.
- Closing a project persists the closure review and archived project row in one SQLite write transaction.
- Updates to `lens_sessions.case_id` and `metric_contributions.source_case_id` are validated against the owning `DailyEntry`, matching insert-time ownership checks.

## Coach Prompt Attribution (v37)

- `coach_prompt_turns` records the Case session, PromptRun, coach observation, candidate output, exact presented output, quality-gate outcome, and timestamps for one coach turn.
- Feedback is attributed only to the output actually shown to the user, so discarded or repaired candidates cannot distort prompt-quality measurements.
- Prompt copy experiments require this attribution record and must preserve source references and Case isolation.

## Weekly Guidance Review Persistence (v38)

- `weekly_guidance_reviews.week_key` is a deterministic natural-week key and is unique.

## Side Quest Foundation (v39)

- `side_quest_preferences` is a single profile with categories, appearance frequency, notification preference and permitted time window. Invitations are visible by default; notification permission remains explicit.
- `side_quest_runs` is the auditable lifecycle record: `offered`, `accepted`, `deferred`, `declined`, `completed`, or `expired`. SQLite allows only one unresolved invitation at a time.
- `side_quest_experience_events.side_quest_run_id` is unique. Insert requires the referenced run to be completed, and update/delete triggers preserve the event as an immutable reward record.
- Notification preference is stored in v39 and is activated only from an explicit Settings action; that action is the sole place that requests authorization. v40 schedules an AI-generated offer inside the selected window and cancels it when the invitation is resolved.
- v40 adds the side-quest decision audit (`origin`, `prompt_run_id`, `decision_rationale`, notification copy), the last planning timestamp/PromptRun ID on the preference profile, and immutable positive `streak_count` on each experience event. The LLM decides offer/hold and content; local code remains the enforcement boundary.
- v45 adds `side_quest_planning_records` so holds become durable, privacy-minimized trial evidence instead of disappearing after `last_ai_planning_at` is updated. A unique `day_key` and `prompt_run_id` prevent duplicate same-day accounting.
- A generated review is immutable for that week. Repeated user actions and App restarts load the same row instead of making another model request.
- Repository read failure suppresses generation to avoid accidental duplicate calls; an in-memory result remains reusable when persistence fails during the current session.
- Export includes weekly reviews and their evidence references, but never API keys or provider credentials.
