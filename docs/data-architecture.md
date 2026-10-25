# 明思 Data Architecture

## 行动清晰度（2026-10-18）

本轮无数据库迁移或历史重写，Quest 既有字段与 schema 3 不变。generateQuests 的 1.11.0/1.10.0 模板原文保留回放；1.12.0 仅改变指导合同。缺少原文行为、无重试和未知结果不能由本地文案补成证据。UI 真实回应回放只在 DEBUG 且显式隔离夹具中启用，不读取或替换正常用户会话。

2026-10-21 客户端补齐 `reviewWithoutAction`，使用现有 daily_entries.state 与 training_case_sessions.loop_state 字符串存储，不增列。事项会话保留该状态和当前复盘，日记录经用户保存后为 sessionComplete；事项无待验证行动时保留 ready，有以前 active 行动时仍为 awaitingVerification。空行动和后退补材料不删除已确认的行动/结果。保存仍跨现有仓储顺序写入，不宣称跨库原子性；新状态需当前版本读取。验证见 [无行动回顾](qa/2026-10-20-no-action/README.md)。


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

## v48 闪念与日聚合

`CaptureFragment` 是不可被 AI 覆盖的原始文字，按本地 `day_key` 保存 `source`、`status` 与可选 `source_id`。`DailyCaptureDigest` 保存生成时的 fragment ID 来源快照、summary、themes 和可选推荐问题。`v48_capture_fragments_daily_digests` 对同一日的 `current` digest 建部分唯一索引，并对外部入口来源 ID 幂等。保存 digest 与标记来源 `included` 在一个事务中完成；失败时 pending 原文不变。两表进入数据导出，但 Keychain/API key 继续完全不进入数据库或导出。

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

## 明思一下轮次链（v52）

`single_nudge_sessions` 以 append-only 轮次保存“明思一下”。v52 增加 `parent_session_id`、`root_session_id`、`continuation_kind`（`initial`、`alternateAngle`、`deeper`）。换角度或继续想一层先排空在途写、再保存已完成父轮、成功后才创建子轮；父轮的问题、回答、当场点拨和两个 PromptRun ID 不会被覆盖。子轮的 `before_text` 从父轮 `after_text`（缺失时用原始输入）带入。

每次发起问题或复盘请求前，AppStore 会先同步保存当前轮（含回答），保存失败则保留输入/回答并提示重试，绝不发起模型调用；因此 PromptRun 的 source ID 不会引用未落盘的会话。每个 PromptRun 的 `source_record_ids_json` 包含当前轮和直接父轮（若存在），因此可审计模型实际使用的最小上下文。恢复当天状态时优先最新未完成轮；旧行把自身 ID 兼容为 root。`single_nudge_sessions` 已纳入本地导出，字段随表导出，且不包含 API Key。

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


## 2026-10-17：不依赖透镜的回顾保存

v71 `training_case_sessions.reflection_state_json` 是可空的新列，保存本事项的问题/回答及已完成的复盘反馈、停止边界和 PromptRun ID。旧会话为空，不生成虚假的反馈；已有 LensSession 仍可作为旧记录恢复来源。恢复优先使用本事项独立快照，因此未选择透镜时也能恢复原话。用户编辑回答后清除旧反馈，并排队保存新的快照。

退出今日回顾和切换事项会先等待排队持久化，再尝试保存当前内容；保存失败时不清空当前页面、不切换事项。停止后的主入口返回今日，不自动生成验证行动。停止不等于证据充分，也不标记事项已完成。

## 2026-10-18：原则候选与正式资产分离

`v72_principle_review_drafts` 为 `daily_entries` 添加可空 `principle_review_drafts_json`。字段映射 `DailyEntryDraft.principleReviewDrafts`，键为事项 UUID，旧单条流程使用 `daily`，值为候选数组。旧行的 NULL 读为空字典；迁移不生成或重分类旧原则。

生成、编辑及返回恢复写候选草稿；候选不写入 `principle_assets`，也不作为历史原则、成长或旧经验召回。用户明确确认后逐个调用 `savePrinciple`，保留当天其他事项的正式资产；跳过只移除当前草稿键。各仓储仍分次写入，未新增跨仓储事务：候选写入成功而完成状态写入失败时，已明确确认的资产可能已存在，当前页面仍保留并可同 ID 重试。没有据此宣称崩溃一致性完成。


## v73：结果回顾保留模型评估与用户自评

`v73_result_calibration_receipt` 为 `verifications` 增加可空 `calibration_assessment_json`，为 `growth_settlements` 增加可空 `calibration_assessment_json`、`calibration_note`、`recommendation`。`CalibrationAssessment` 移至 domain，证据状态、验收状态、判断状态及原文引用独立于 `judgmentUpdate`（用户判断自评）；后者保留用户选择，不被模型覆盖。

AppStore 保存本轮 `VerifyQuestResult` 的评估和原文反馈，GrowthSettlementPolicy 原样带入回执；生产验证/行动状态/结算仍通过既有 SQLiteVerificationSettlementRepository 单事务写入。独立 VerificationRepository 同样可读写评估。旧行 NULL 读为 nil，旧回执反馈读为空字符串，不推断或补造历史评估。原有用户自评保留并在界面注明身份。

结果缺少观察或记录冲突时，新评估阻止自动写入原则练习证据及提示掌握/反例记录；旧 nil 评估的兼容行为保留。有观察不等于证明所选原则被实践；这条归属链仍待进一步审查，不由本迁移确认。持久化往返、真实 v72 到 v73 旧行迁移及 AppStore 缺失/冲突保存链路见[结果校准验收](qa/2026-10-18-result-calibration/README.md)。

## v74：原则行为报告独立于结果与自评

`v74_principle_practice_assessment` 为 `verifications` 增加可空 `principle_practice_assessment_json`，保存原则 ID、practiced / partially_practiced / not_practiced / not_assessable、本轮连续原文引用及理由。旧行保持 NULL，不从选择、好结果或旧评语补造实践。Verification 独立仓储和结果/行动/回执事务均保存此字段，历史上下文保留它；GrowthSettlement 不复制该字段，Verification 是分类的原始记录。

派生实践只接受明确选择的有效原则、匹配 ID、可核对原文引用与做过/部分做过的评估。它不要求结果成功或已出现；失败结果也可能有动作报告。新派生记录使用 schema 2、`principle-practice-attribution.result-evidence.v2` 及 Verification ID，原文作为 matchSignal。同一来源/行动不重复计数，旧关联保留且不能阻止新有效报告。用户否认的归属仍受原有争议防重规则保护。

旧自动关联不计为实践，界面单独提示其缺少行为记录。提醒“有帮助/调整使用”不等于做过动作，三次报告不自动推断内化；只有明确手工自报的 internalized 记录显示“自报已形成习惯”。这些仍是用户报告及模型判断，不证明行为真实发生、因果效果或能力提升。派生记录写入在核心事务之后，崩溃恢复尚未建立；每原则最近 20 条读取也不代表历史完整审计。验证见[原则行为证据报告](qa/2026-10-18-principle-practice-evidence/README.md)。

## 单次指导证据的事务与生命周期（2026-10-18）

本轮没有数据库迁移。`SQLiteGuidanceRepository.recordEvidence` 在单个 GRDB 写事务中读取最新 UserGuidanceState、按 Verification ID 去重、更新计数和引用并 upsert；偏好操作 `updatePreference` 同样在事务内修改最新行，避免并发归属覆盖暂缓或用户明确的 mastered 选择。重复来源即使分类相反也不增加计数，两个支持来源不会自动 mastered。新明确非使用报告沿用 practicing 状态以恢复资格，不代表用户能力退步。

AppStore 对同一 Verification 合并进行中的可选请求；重新创建 Store 时读取持久化来源，跳过已记录项。遇模型、读取或写入失败即停止后续目录请求，不给当前页补本地判断。任务由 Store 跟踪，后台或模型配置变更会取消；在 await 返回后检查取消和配置修订，拒绝迟到网络结果。已经开始的写事务仍可能提交，不宣称取消与提交原子化。没有持久恢复队列，未记录的 insufficient 也不构成永久请求去重。

旧计数、引用及 mastered 状态原样保留：历史数据不能区分自动推断和用户明确选择，故不重写。分类理由和引文沿用既有 PromptRun 审计，未新增独立归属审计表。原 v73 章节的 nil 评估兼容描述已由当前入口收紧：旧 nil、missing/conflicting 或不匹配来源均不调用归属模型。已观察结果仍不等于实际使用提示；精确引文只验证来源。详见[指导证据报告](qa/2026-10-18-guidance-evidence/README.md)。

## 停用旧本地成长计分（2026-10-18）

删除 `generateLocalGrowthSnapshotFromHistoryIfNeeded` 及其固定分值归属/加总/理由生成，恢复记录和完成流程均不再自动写 MetricSnapshot 或 MetricContribution，包含旧流程降级和显式服务注入路径。`growthEvidenceScopes` 保留用于模型报告的事项来源上下文；用户自评和实际结果仍按来源独立保留。记录计数直接来自当前读取的 HistoryRecord，描述读取范围，不复制为报告的 completeLoopCount，不宣称全历史或月度总数。

本轮无迁移、无存储重写。旧作者唯一固定摘要格式“已基于 N 次完整复盘生成本地成长快照：P 条正向证据，Q 条负向证据。”作为兼容识别签名。匹配的原始快照不展示分数，读取时只构造说明用途的副本；历史和指标贡献读取按 snapshotId 排除该类贡献，模型 previousSnapshot 也不再使用其分数。原行、数字、贡献及导出保留。其余未知来源报告不据此重分类；没有建立完整历史来源审计。读取历史来源失败时不展示该次贡献集合，避免将未查明项作证据。

成长页展示记录数量及可核对的报告说明，满三次不自动满足证据或能力门槛。三次请求门槛仍保留，服务在不足时不调用模型，返回无分数/无贡献的状态；不自动分配额外练习。详见[成长证据边界报告](qa/2026-10-18-growth-evidence-boundary/README.md)。

### Reflection topic read projection（2026-10-18）

ReflectionTopicSummaryPolicy 是只读投影，不新增表或迁移。优先读取 TrainingCaseRecord.session.reflectionState.questions，缺失独立状态时才使用同日同事项 LensSession；空独立状态不复活旧透镜副本。没有 Case 时仅使用未归属事项的旧 LensSession / 卡片。问题须有非 none 类型、非空问题和回答、非空来源标题，全部标题与本事项已确认且未排除卡片对应。标签和原话不被重写，未知来源不推断。

只索引排除当前记录后的最近 14 条完整记录，按记录 ID 去重；问题 ID 全局去重，同一记录同类型取一项，至少两条记录形成可回看的主题，最多两项。用户展开能读问题/回答并跳转日期或 Case 来源。此投影不进入 Prompt。CoachPatternSummary/Signal 保留 Codable 兼容，旧本地作者返回 nil，ContextAssembler 对全部 Prompt 排除旧摘要；不再从原文/AI 问题/建议推断历史能力缺口。

## 2026-10-21 初始诊断与反思快照的恢复边界

没有新增表或字段。已有 `CoachReflectionState` 的问题、讲解和来源属于该事项的已保存内容；打开阅读不重新调用初始诊断。只有未完成的视角选择需要初始建议，旧本地建议不会因此自动升级为新的模型结论。初始请求接收同时要求 token、日记录、事项、阶段、模式和完整确认卡片仍匹配；相同 id 的原文变化也会失效。退出、选定或继续、切换、重置及模型配置刷新取消旧任务。该规则覆盖初始建议，不代表所有辅助指南请求都有持久化去重；[反例、回归和实际流式保存重开](qa/2026-10-21-initial-decision-lifecycle/README.md)分别记录。


### 辅助提示展示记录（2026-10-21）

无 schema 迁移。`SQLiteGuidanceRepository.recordPresentation(for:at:)` 事务性读取并合并现有 `UserGuidanceState` 的 lastShownAt/updatedAt，保留较新时间、掌握/暂缓偏好、计数与证据。模型决策本身不写已展示；Today 的带身份 offer 出现后才记录，重复 appearance 合并。失败不影响当前输入。进程内 16 项 show/hold 缓存包括完整上下文、有效 Prompt 模板与配置修订；不导出、不持久化，不把 AI 文字写成用户能力证据。见[验收范围](qa/2026-10-21-guidance-presentation/README.md)。

### 导师本轮方法快照（2026-10-26）

`MentorContextPayload.selected_method` 是可选的 `CoachMethodSnapshot`，包含方法ID、版本、限定指令、来源标题/URL/范围与材料哈希。它是方法指导，不进入 `sources`、`source_refs`、`lesson_ref` 或用户认识，缺失字段按nil读取旧记录。使用已有 `mentor_requests.context_snapshot_json` 冻结，不新增数据库表或修改外部透镜包签名序列化。

回复方法通过 `mentor_request_results` 的session/item/request所有权关系读取对应已提交请求，供历史详情展示；不从当前目录重建。方法选择只影响下一次新请求，登记后清空；失败重试继续回放原快照。五项书籍/指南局部适配属于内置目录，必须通过内容哈希、Prompt版本、来源审核、六类效果与增益门槛；当前均保持待验证，不从localCustom路径绕过外部包信任验证。
