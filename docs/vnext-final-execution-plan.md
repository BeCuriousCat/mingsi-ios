# 明思 vNext 最终执行计划

Date: 2026-07-25
Status: implementation and acceptance

## 1. Product Outcome

明思从“一天一份 DailyEntry、一次完整训练”升级为一天多事项、单事项训练和证据结算：

```text
原始记录 -> AI 事项候选 -> 用户确认 -> 单事项训练
-> 可验证行动 -> 到期验证 -> 成长证据结算
-> 项目结束复盘 -> 可复用原则
```

确定决策：

- 界面统一使用“事项”，内部使用 `TrainingCase`。
- 一天可有多件事项，任意时刻只允许一件活动训练。
- 未完成事项或到期验证达到 3 条时只提醒，不阻塞。
- 分组复用整理调用；模型只提候选，用户确认后才成为正式事项。
- 同日可合并和撤销；跨日只建立 `relatedTo` / `followUpOf` 关联。
- 到期验证优先但不阻塞新记录；暂缓不创建 Verification。
- 单次结算只显示新增成长证据，不显示能力加减分。
- 项目结束原因和实际结果必填；AI 总结与原则候选可跳过。
- Guidance 文案来自随 App 发布的版本化目录；是否展示、是否算作有效证据仍由中央 LLM 判断。仅仅渲染已经确认的文案不重复发起模型请求。
- 任何涉及分类、推荐、训练诊断、结果校准、原则候选、项目总结或生活邀请的判断，都必须经过中央 LLM 决策中心；本地代码只做同意、资格、频率、安全、权限和事务约束。
- 支线邀请是主线之外的可选生活成长层：允许 LLM 决定是否出现，允许用户主动开启系统通知，完成后给予独立的生活经验和非惩罚性连续记录；它不改动五项主线能力指标，也不因拒绝、暂缓或未完成扣除任何记录。
- `CentralLLMDecisionCenter` 是全局判断中心；本地状态机、用户同意、隐私过滤、通知和 SQLite 事务继续由 iOS 拥有。Pi 不替换本地状态机，也不在本次实现范围；仅在真实试用后满足受控多轮和质量门槛时，可作为未来服务端 `AgentRuntimeAdapter` 实验。
- Provider Profile、账号、同步、市场和新评分体系延后到 vNext.1 决策之后。

## 2. User Flows

### Today Overview

Today 首屏依次展示：

1. 到期验证，可验证或暂缓。
2. 今天原始输入和补充记录。
3. 事项列表：待确认、待推进、进行中、待验证、已完成。
4. 非阻塞过载提醒。

选择事项后复用“讲清今天、找出判断、行动验证”。退出、暂存、完成或切换前必须先保存当前 `TrainingCaseSession`。卡片、问题、透镜、Quest、原则上下文和 PromptRun 来源不得串入其他事项。

### Organize, Split, Merge, Link

- 流式协议为 `MINGSI_STREAM_V2`，每个 CARD 可带 `CASE_KEY` 和 `CASE_TITLE`；解析器继续兼容 V1。
- 缺少、重复或无效分组时回退为一个默认事项。
- 用户可以改名、移动卡片、手动新增、忽略和合并。
- 合并来源不删除；目标读取双方证据。撤销后来源恢复，目标期间新产物保留。
- 任一事项存在 Verification 时拒绝合并，只允许关联。

### Verification And Settlement

- Quest 保存验证到期时间和可选暂缓时间。
- 到期队列来自无 Verification 的 active Quest。
- Verification 必须包含真实结果和判断更新。
- Verification、Quest 状态和唯一 GrowthSettlement 在同一数据库事务提交。
- 结算显示原判断、实际结果、判断更新和 1-3 条新证据。
- 证据只映射清晰度、价值判断、执行可靠性、校准、反思深度中的一个指标。
- 结算不直接修改分数；长期趋势仍只读取已接受、可回链的 MetricContribution。
- 判断被推翻但完成证据记录时属于有效校准，不属于能力下降。

### Project Closure

- 项目表示跨日期的长期证据线，不是任务管理器。
- 项目详情直接提供“结束项目”。
- 结束原因和实际结果必填；证据、未完成事项转移、补充复盘可选。
- 数据层继续使用 `archived`，界面显示“已结束”，默认列表隐藏。
- 恢复时回到结束前状态，缺失时回到 active；结束复盘保留。
- AI 总结只在用户主动请求后生成，且只能使用已确认、有引用的证据。

### Controlled Guidance

- `GuidanceCatalogItem` 包含稳定 hintID、版本、阶段、触发规则、冷却、掌握门槛、反例恢复和解释。
- 行动、验证或反馈保存后由本地规则实时更新状态。
- 每一步最多显示一条提示，可暂不显示或标记已掌握。
- 已掌握提示只在新的反例证据出现时恢复。
- 周复盘只有最近 7 天至少 3 次验证、覆盖至少 2 天时才允许 LLM 选择；每个自然周最多持久化一个结果并最多调用一次模型，重复操作或重启后直接复用。返回值限训练重点、已有 hintID 和证据引用。

### Optional Life Side Quests

- 支线不是主线 Quest，也不是任务管理器；它是一件偶尔出现、可以直接拒绝的生活邀请，覆盖关系、好奇、兴趣、创造、探索、活力和自我照料。
- 用户显式开启后，`SideQuestAIService` 通过中央 LLM 在允许的日期和频率窗口内决定 `offer` 或 `hold`，并生成邀请、前置条件、奖励和可选通知文案。素材库只提供受控参考，不替代模型判断。
- 用户显式开启通知后才申请系统权限并安排通知；关闭通知、拒绝权限或关闭支线都不会影响主线训练。
- 完成支线写入独立的生活经验账本和连续完成记录；可选观察带来小额额外经验。该账本不写入 `MetricContribution`，不参与五项成长分，也不将连续记录变成主线惩罚。
- 拒绝、换到下次、暂存、过期或未完成都不扣经验、不降低能力、不强制重复出现。
- 支线只使用用户自愿、可编辑、最小化的已确认情境：当前持久资料只有家/工作地点的本地标签、各自数值楼层/楼梯可用性、过渡时间、出行/运动偏好、禁用类别和简短 constraints；`familiarPlace` 仅是 snapshot scene。活跃地点才可提供 `practical_place_home` / `workplace` 及其 `*_floor` / `*_stairs` grounding，另有 `scene_*`、`availability_*` 和粗粒度健康 snapshot token。当前没有设施、预约、预算或熟悉路线 token，因此不得建议游泳、远距离场馆、陌生路线或其他外部依赖活动，必须 `hold` 或提出不依赖未知条件的低门槛体验；这些条件未来必须先新增自愿字段和 grounding token。
- 未来多轮仅限用户主动启动的会话，最多 2 个模型回合；补充情境逐项展示并经用户确认。模型或 future runtime 不能自行执行现实操作、通知、权限或持久化写入。完整契约见 `docs/agent-runtime-decision.md`。

## 3. Data And Ownership

核心表和类型：

- `TrainingCase`, `TrainingCaseSession`, `TrainingCaseMerge`, `TrainingCaseLink`
- `ProjectClosureReview`, `GrowthSettlement`
- `GuidanceCatalogItem`, `UserGuidanceState`, `CoachTurnFeedback`
- `CoachPromptTurn`, `WeeklyGuidanceReviewRecord`

权威关系：

- ThinkingCard、Quest、LensSession 直接归属 TrainingCase。
- Verification 通过 questId 推导 Case，不重复存 caseId。
- MetricContribution 保存不可变 sourceCaseId 回链快照，并校验与来源 DailyEntry 一致。
- ProjectLink 支持 training_case 来源。
- Principle 仍是全局资产，通过证据引用回链。
- HistoryRecord 按天包含多个 TrainingCaseRecord。

服务边界：

- repositories: case、session、relationship、closure、settlement、guidance。
- coordinators: case materialization、verification queue/settlement、project closure、guidance selection。
- `TodayAIService.organizeCapture` 返回 cards 和 caseSuggestions；旧 API 保留兼容包装。
- `PromptContextPayload.currentCase` 只带当前事项和明确来源；PromptRun 来源 ID 必须含 Case ID。

## 4. Migration And Rollout

- `v33_training_cases`: 新表，并为旧 DailyEntry 建默认事项和会话。
- `v34_case_ownership`: 回填 cards、quests、lens sessions、metric contributions 的事项归属并启用一致性约束。
- `v35_vnext_support`: closure、settlement、guidance、feedback、Quest 暂缓字段。
- `v36_vnext_closure_integrity`: 项目结束原则候选、项目关闭事务和事项归属更新校验。
- `v37_coach_prompt_turns`: 保存候选、质量门禁和最终呈现输出的精确归因。
- `v38_weekly_guidance_reviews`: 按自然周唯一保存受控周复盘，支持重启复用和导出。
- 文件数据库迁移前使用 SQLite online backup API 创建一致性版本化备份；迁移在工作副本完成后才替换原库。应用持有共享数据库租约时不会并发迁移，失败不得破坏旧数据库。
- 旧 DailyEntry 流程字段暂留，不再作为 vNext 权威事项状态。
- Data Export 包含新增记录和关系，不包含 API Key。
- `trainingCasesVNext` 支持内部环境开关；最终验收后默认开启。

## 5. Acceptance Gates

Automated:

- v1、v32 和复杂 fixture 迁移零丢失。
- Case A/B 交替训练、重启、取消流式和失败重试不串线。
- V1/V2 协议兼容，无分组字段回退单事项。
- 分拆、移动、合并、撤销、跨日关联保留来源。
- 已验证事项拒绝合并。
- 暂缓不生成 Verification；事务失败不产生部分结算。
- 项目结束/恢复保留结束前状态、原则和证据。
- Guidance 冷却、掌握、反例恢复和周复盘阈值生效。
- 支线邀请的 LLM `offer/hold`、用户同意、通知安排、完成经验、连续记录和拒绝无惩罚均可回放验收。
- 情境资料的同意、编辑、清除、最小化发送和 `available_grounding_refs` 校验可验收；缺失地点/设施/出行/健康依据时，场馆、游泳、远距离、陌生路线和楼梯建议必须被拒绝或返回 `hold`。
- 受控多轮 fixture 验收：最多 2 回合，第二回合所有字段均有用户确认，取消/超时后无通知、无持久化、无现实副作用，且 `PromptRun` 可回链。
- 同一自然周重复生成和 App 重启不会产生第二次周复盘模型调用。
- Prompt 上下文只含当前事项，PromptRun 可审计。

UI and device:

- 同日三件无关事项可确认并逐条训练，数据完全隔离。
- 三条以上只提醒，不阻塞。
- 验证成功后才展示无分数的成长结算。
- History、Projects、Growth 能回到准确事项和来源。
- 已结束项目默认隐藏，复盘可回看，原则仍可复用。
- 浅色、深色、动态字体、VoiceOver、reduced motion 可操作且无重叠。
- `MingSiTests`、`MingSiUITests`、Alpha acceptance、模拟器构建和真机启动通过。

## 6. Post-Implementation Trial

完成后进行 3-7 天真实体验，记录分组修改率、事项完成/暂存/放弃、串线、教练反馈、行动标准、验证/暂缓、结算可信度、项目原则质量、Guidance 噪声，以及支线接受率、通知关闭率、经验奖励可信度、连续记录是否造成压力、情境不贴合反馈、`hold` 比例和未经 grounding 的场馆/远距离建议。试用结束后形成 vNext.1 的保留、调整、删除决策；Pi 不在当前实现范围，只有满足 `docs/agent-runtime-decision.md` 的全部 adapter 实验门槛后才可进入后续设计评审。
