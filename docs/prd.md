# 明思 PRD

## vNext Product Contract (2026-07-15)

The current product contract supersedes the original one-DailyEntry/one-training assumption. A day can contain multiple user-confirmed matters (`TrainingCase`), while only one matter may be actively coached at a time.

```text
Today Overview -> confirm matters -> train one matter -> verifiable action
-> due verification -> evidence settlement -> project closure -> reusable principle
```

Today keeps the existing three user-visible stages. Verification is non-blocking, settlement contains evidence rather than a score change, and Projects use a required closure review. Meaningful coaching and life decisions are routed through the central LLM decision layer; local code only enforces consent, safety, rate limits and durable state. Alongside this active thinking loop, side quests are occasional, dismissible life invitations visible by default. Completing one earns a separate positive life-experience reward and continuity record; declining, deferring, expiring, or skipping never deducts experience or changes the five evidence-based coaching metrics. System notifications require explicit permission. Full scope and acceptance gates are defined in `docs/vnext-final-execution-plan.md`.

Provider Profile Foundation, account/sync, collaboration, remote markets, and a new scoring system are explicitly out of the current milestone.

## Overview

明思是一款面向个人知识工作者的 iOS 思维训练 App。它把每日输入、结构化整理、深度追问、明日任务、次日验证和长期原则沉淀连接成一个闭环。

MVP 采用 SwiftUI iPhone 原生实现，直接调用 GLM，用户自带 API Key，并使用本地优先存储。

核心闭环：

```text
Clarify -> Challenge -> Choose -> Act -> Calibrate
```

## Goals

- 降低每天复盘的输入成本。
- 将原始输入转化成结构化卡片。
- 通过透镜和追问训练更深思考，而不是只做摘要。
- 生成一个高价值的明日主线任务。
- 次日验证任务是否完成以及实际价值。
- 将可复用的结论沉淀为原则资产。
- 形成长期可回看的历史证据链。

## Target User

首版只服务一个 alpha 用户：

- 忙碌的个人知识工作者。
- 需要在工作环境中避免输入敏感原始资料。
- 愿意用 10-15 分钟做一次完整的日常思考训练。
- 想提升清晰度、判断力、执行力和校准能力。

## User Journey

### First-Time Setup

用户创建一个思考档案：

- 选择主要训练目标：清晰度、价值判断、执行可靠性、项目判断、反思深度。
- 确认隐私边界：不输入公司文档、代码、客户名、内部标识或敏感数据。
- 输入 GLM API Key，存入 Keychain。
- 创建一个或多个抽象项目。
- 完成五项成长指标的基线自评。
- 选择默认训练模式，建议 Standard。

输出：

- 思考档案。
- 初始项目列表。
- 默认周训练重点。

### Daily Reflection

用户开始一天的训练：

1. 输入原始文本。
2. 选择 Quick / Standard / Deep 模式，或使用默认推荐模式。
3. 系统整理出结构化卡片。
4. 用户修正、合并、删除或标记敏感卡片。
5. 选择或接受推荐的思考透镜。
6. 回答至少一个深度问题。
7. 确认明日主线任务和最多两个次要任务。
8. 接受或保存一个可复用的原则候选。

输出：

- 确认后的每日卡片。
- 透镜回答。
- 明日任务。
- 原则候选。

### AI Failure Recovery

GLM 连接测试通过只代表 Key、Base URL、模型名和基础协议可用，不代表每个正式 Prompt 都一定成功。正式调用仍可能因为模型权限、额度、网络、`response_format` 兼容性、输出 JSON 不符合 schema 或响应为空而失败。

要求：

- 任一 AI 调用失败时，必须展示可读失败原因，不能静默替换成假装正常的结果。
- vNext 正式运行的任何实质判断都必须经过中央 LLM。未配置 API Key、模型不可用或质量门失败时，只保留用户材料并进入可补跑状态；本地 fallback 仅允许显式测试、预览和旧流程夹具，不能成为生产判断。
- 用户可以在当前步骤点击“重试当前步骤”，用同一份本地资料再次请求模型。
- 重试失败时保留现有内容，不重复叠加待补跑数量。
- 重试成功后，对应待补跑项必须消失，并用 AI 结果替换对应草稿。
- 全局允许“后台重试”，基于当前本地保存/内存资料补跑待修复的 AI 结果。
- MVP 的待补跑队列按 Prompt 去重；后续应以 PromptRun 作为持久审计和补跑来源。
- AI 等待态必须显示具体阶段和失败原因；如果是网络超时，应明确提示“请求超时”。
- 当前步骤内显示“重试当前步骤”，全局横幅显示“后台重试”，两者文案和作用边界必须区分。

### Editable Daily Flow

Today loop 不是一次性向前的向导。用户走到后面的步骤后，可以回到已完成步骤修改。

要求：

- 进度条中的已完成步骤可点击返回。
- 用户回到较早步骤后，后续由 AI 或用户基于旧内容产生的派生结果必须清理。
- 例如从“回答问题”回到“思考卡片”，应保留原始输入和卡片，但清空模式选择、透镜、问题、任务和原则候选。
- 不允许跳到尚未完成的未来步骤。
- `Organizing` 是短暂执行态，不作为可编辑返回点；用户应回到 `Capture` 或 `ReviewCards`。

### Next-Day Verification

第二天，App 先验证昨天的主线任务：

- 完成状态：已完成、部分完成、未完成。
- 实际价值：高、中、低、不明确。
- 如果未完成或价值偏低，记录原因。

输出：

- 执行记录。
- 校准记录。

### Weekly Calibration

每周生成一次校准报告：

- 最有价值的动作。
- 最低价值的时间消耗。
- 重复出现的阻塞。
- 重复出现的思考模式。
- 下周训练重点。

输出：

- 周度模式摘要。
- 推荐的训练透镜。

### Monthly Growth Review

每月生成一次前后对照报告：

- 更清晰的任务定义例子。
- 执行可靠性的变化。
- 判断校准趋势。
- 重复未解决的薄弱点。
- 下月训练建议。

输出：

- 月度成长报告。

### Historical Review

用户可以回看历史会话，并将其作为成长证据。

历史体验需要回答：

- 某一天发生了什么？
- AI 整理出了什么卡片？
- 选择了什么透镜？
- 生成了什么主线任务？
- 任务是否完成，结果是否有价值？
- 哪些历史例子证明成长，哪些例子说明问题重复出现？

输出：

- 可搜索、可过滤的历史记录。
- 与 Growth 和 Projects 联动的证据链接。

## Core Features

### Daily Input

要求：

- 大文本输入区域。
- 自动保存。
- 明显的隐私提醒。
- Organize 操作触发卡片提取。
- 原始输入始终可编辑。
- 输入内容支持 Quick / Standard / Deep 三种模式。

### Card Organization

AI 将原始输入转成结构化卡片。

卡片类型：

- Fact
- Problem
- Decision
- Risk
- Idea
- Communication
- Task

要求：

- MVP 必须支持流式生成卡片，不能只显示静态等待态。
- `organizeCards` 使用受控 XML-like 流式协议：遇到 `<CARD>` 创建临时卡片，遇到 `</CARD>` 闭合候选卡片。
- 流式输出只进入临时 `StreamingCardDraft`，不直接写入数据库。
- 闭合并校验通过的候选卡片才能转换为正式 `ThinkingCard`。
- 非法卡片类型、重要度、敏感级别或置信度不能被默认降级成合法卡片。
- 正文里的普通尖括号文本必须按用户原文保留，例如 `< 30 分钟` 不能破坏后续闭合标签解析。
- 用户确认后的正式卡片才进入追问、任务、历史、项目和成长证据。
- 后台 AI 补跑只能在当天还没有卡片、问题、任务和原则时重跑卡片整理，不能覆盖已经形成的下游状态。
- 流式中断时，已闭合卡片可保留，未闭合卡片标记为未完成；用户可以重试当前步骤。
- 卡片可编辑。
- 卡片可删除。
- 卡片可合并。
- 卡片可标记重要。
- 卡片可标记为敏感并从后续模型调用中排除。
- 最终追问只能基于用户确认后的卡片。

### Thinking Lenses

MVP 透镜：

- First Principles
- Occam's Razor
- Opposing View
- Opportunity Cost
- Leverage Analysis
- Evidence Check
- Execution Bias Check

要求：

- AI 在卡片整理后推荐一到两个透镜。
- 用户可接受推荐或手动选择。
- 选择的透镜至少生成 3 个问题。
- 用户必须回答至少一个问题后，才能生成明日任务。

### Quick / Standard / Deep

三种模式用于控制流程长度和追问深度：

- Quick：快速整理和收敛，只保留最少问题。
- Standard：默认模式，完整走一遍卡片、透镜、任务和原则候选。
- Deep：用于周复盘或重要事件，问题更多，校准更深。

要求：

- 模式必须在数据里可记录。
- Prompt 依据模式选择不同深度。
- 模式切换不影响底层数据结构。

### Tomorrow Quest

App 生成轻量游戏化的任务集。

任务类型：

- Main Quest
- Side Quest
- Observation Quest

要求：

- 至少一个主线任务。
- 最多两个次要任务。
- 最多一个观察任务。
- 每个任务都包含：
  - 为什么重要。
  - 完成标准。
  - 预期阻力。
  - 事后反思问题。
- 主线任务必须由用户确认后才激活。

### Verification

App 在开始新一天训练前，先验证昨天的主线任务。

要求：

- 询问完成状态。
- 询问实际价值。
- 如果未完成或价值偏低，记录原因。
- 将结果用于校准和成长指标。

### History

历史存储并展示过去的每日输入、卡片、透镜、答案、任务和验证记录。

要求：

- 按日期展示记录列表。
- 展示 Today state machine 的当前状态，并派生出 draft、in_progress、quested、completed、incomplete 等展示状态。
- 支持单日详情。
- 原始输入默认折叠。
- 用户确认后的卡片可筛选。
- 历史统计不得把未确认或已排除卡片混成“已沉淀卡片”；摘要应区分已确认、待确认和已排除。
- 日历视图需要用证据标识区分：确认卡片、任务/验证、原则/总结。
- 只有确认且未排除的卡片算作“卡片证据”；未确认卡片可以显示为待确认，但不能作为成长、项目和追问事实源。
- 任务和验证结果必须与源记录链接。
- Growth 报告必须能深链到历史证据。
- Project 页面可以显示相关历史记录。
- 用户可以从历史卡片创建新的后续任务。

History 是证据层，不是普通归档。

### Projects

Project 不是普通文件夹，也不是必须等同于公司项目名。它是用户长期反复面对的一组目标、阻塞、判断和行动的抽象容器。

Project 也不是从每日口述中自动抽出来的关键词分类。AI 可以从多天证据中提出候选聚类，但正式 Project 必须满足三个条件：

- 有持续目标或持续阻塞，而不只是一次性事件。
- 有可追踪的行动、验证或原则证据。
- 用户确认这个抽象名称对自己有长期复盘价值。

例子：

- 可以成为 Project：“会议效率”“判断质量训练”“跨团队协作边界”“个人表达质量”。
- 不应直接成为 Project：“今天很忙”“某个公司内部项目原名”“一个孤立会议”“一个未确认的情绪判断”。

项目可以来自两种方式：

- 用户手动创建。
- AI 从每日确认后的卡片、任务和原则中提出候选聚类。

项目生命周期：

- Candidate：AI 或用户从证据中提出，但尚未进入长期跟踪。
- Active：用户确认后进入主动跟踪。
- Watching：暂时只观察，不要求每天推进。
- Paused：用户主动暂停，仍保留证据链。
- Archived：已归档，不再默认进入建议。
- Merged：被合并到另一个项目，但原始 id、字段和证据仍保留。

项目候选生成条件：

- 过去 14 天内至少 2 条记录指向相似目标、阻塞、会议模式、决策主题或行动标准。
- 或者单次记录明确出现一个需要持续追踪的目标、风险或长期任务。
- 候选必须附带 source ids，并说明为什么这不是一次性事项。
- AI 只能提出候选，不能自动创建正式项目。

项目约束：

- 候选项目必须先进入候选确认页，不能直接出现在正式项目列表里。
- 一个 DailyEntry 最多自动建议关联 0-2 个 Project，避免把一切都塞进项目。
- 一个 Project 必须有 goal 或 currentBottleneck，不能只是名称。
- AI 不能因为词频、相似标题或相同人物名称直接创建项目。
- 用户拒绝的候选需要记录 rejection，短期内不重复建议同一理由。
- 涉及公司敏感信息时，只保存抽象名称和本地 evidence id，不保存公司原名、客户名或内部代号到项目摘要。

项目合并约束：

- 只有目标、关键阻塞、成功标准或持续行动对象明显相同，才建议合并。
- 仅名称相似不能合并。
- 用户必须确认合并。
- 合并时必须保留来源记录、原项目名、原目标、原阻塞和合并理由。
- 用户可以拆分、重命名、归档或恢复项目。

项目维护要求：

- 每日卡片 Review 时，AI 可建议关联到 0-2 个项目。
- 用户可以接受、拒绝或手动关联。
- 项目详情展示当前目标、成功标准、当前阻塞、开放问题、最近任务、相关原则和历史证据。
- 项目状态包括 active、watching、paused、archived。
- 用户可以在 Project Detail 中修改目标、成功标准、阻塞和开放问题；修改需要保留 revision note。
- AI 可以建议项目字段更新，但不能直接覆盖用户确认过的字段。

项目进展需要回答：

- 这个项目的当前目标是什么？
- 最近一周推进了什么？
- 当前阻塞是否变化？
- 哪些开放问题被关闭？
- 哪些明日任务真的降低了不确定性？
- 哪些原则被实践过？

项目进展不是百分比进度条。MVP 使用 evidence-backed progress signals：

- Done：完成了哪些主线任务或验证动作。
- Learned：通过验证学到了什么，哪些假设被证实或推翻。
- Unblocked：哪个阻塞被移除或缩小。
- Newly Blocked：出现了什么新阻塞或风险。
- Next Bet：下一个最值得验证的问题。

项目中的思考变化需要回答：

- 用户对问题的定义是否更清晰？
- 用户是否从“做事列表”转向“高价值验证动作”？
- 用户是否更早识别阻塞、风险和假设？
- 用户是否重复犯同一种判断错误？
- 用户是否形成并执行了稳定原则？

项目中的思考变化必须以 before/after 形式展示：

- Before evidence：早期记录中的原始表述或任务。
- After evidence：近期记录中的表述、任务或验证方式。
- Change claim：AI 对变化的解释。
- Training implication：接下来应该强化或纠偏的点。

没有 before/after 证据时，Project Detail 只能显示“证据不足”，不能编造成长叙事。

Project 页面必须链接到 History 证据，不允许只展示无来源总结。

Project Tab 的展示规则：

- 列表不是普通 Table，不按“分类目录”展示。
- 首屏展示 active / watching 项目的当前目标、当前阻塞、最近证据和 next bet。
- 项目数量为 0 时，展示“尚无长期议题”的证据空状态，并引导用户从历史或今日卡片创建。
- 候选项目和合并候选进入独立 review queue，用户确认前不污染正式项目。
- 任意项目结论如果缺少 source id，只能显示为草稿建议，不能显示为事实。

### Principle Library

最小原则库用于沉淀可复用的行动准则。

要求：

- 每次日常训练结束后，AI 可建议 0-1 条原则候选。
- 用户可保存、修改或忽略。
- 原则记录需要保留来源、适用场景和验证状态。
- 后续版本可扩展为原则对照和能力训练，但 MVP 只做最小沉淀。

### Growth Metrics

App 追踪五个趋势指标：

- Clarity：用户是否能清楚表达真实问题。
- Value Judgment：是否能选择更高价值的动作。
- Execution Reliability：是否能完成确认过的主线任务。
- Calibration：预期结果与实际结果是否逐步对齐。
- Reflection Depth：是否能识别假设、风险和重复模式。

要求：

- 指标基于证据，而不是主观打分。
- 指标需要能链接到历史记录。
- 指标必须解释当前值、上次值、变化量和变化原因。
- 每个指标变化必须能拆成正向贡献和负向贡献。
- 每个贡献项必须链接到具体 DailyEntry、Quest、Verification、ThinkingCard 或 PrincipleAsset。
- 分数是个人趋势信号，不是人格标签或能力定论。

成长分数生命周期：

- Insufficient Evidence：少于 3 次完整闭环时，不展示具体分数，只展示已收集证据和下一步建议。
- Draft Review：周/月报告生成后，AI 给出指标草稿和贡献事件，用户可以标记“不准确”。
- Confirmed Trend：用户确认或未驳回后，进入趋势展示。
- Recalibrated：后续验证发现之前判断不准时，可以回写校准说明，而不是删除旧报告。

指标归因规则：

- Clarity 加分：问题被更准确命名，事实/判断/假设被区分，任务有明确完成标准。
- Clarity 减分：输入长期停留在泛泛感受，卡片无法形成可验证问题。
- Value Judgment 加分：用户选择了更高杠杆动作，并在次日验证中确认其价值。
- Value Judgment 减分：主线任务完成但实际价值低，或反复选择低影响行动。
- Execution Reliability 加分：主线任务按完成标准交付，或未完成但提前识别阻力并调整。
- Execution Reliability 减分：任务反复未完成且没有清晰原因。
- Calibration 加分：预期结果和实际结果逐步接近，用户能修正判断。
- Calibration 减分：同类判断反复偏离且没有新验证方式。
- Reflection Depth 加分：用户识别隐藏假设、反方证据、机会成本或重复模式。
- Reflection Depth 减分：回答停留在结论，没有展开证据、约束或权衡。

Growth 页面必须提供：

- 指标总览。
- 单指标详情。
- 本期加分事件。
- 本期减分事件。
- 分数变化解释。
- 证据跳转。
- 下一个训练建议。

Growth 单指标详情必须回答：

- 当前值为什么是这个数？
- 与上期相比发生了什么变化？
- 哪些具体事件加分？
- 哪些具体事件减分？
- 哪些判断仍然不确定？
- 用户下一周应该练哪一种动作？

任何指标如果缺少 MetricContribution 或 source id，UI 必须降级为“证据不足”，不能展示孤立数字。

成长分数计算规则：

- 每个指标使用 1-5 的个人趋势值。
- 初始值来自首次建档的 baseline；如果没有 baseline，使用 3.0 作为中性起点。
- 本期值 = 上期 confirmed value + 本期 accepted positive deltas - 本期 accepted negative deltas。
- 分数最终 clamp 到 1.0-5.0。
- 单个 contribution 的 delta 建议限制在 0.05-0.30，避免一次事件过度改变趋势。
- inaccurate 或 dismissed 的 contribution 保留在审计记录中，但不计入下期 confirmed trend。
- 少于 3 次完整闭环时，不计算 confirmed value，只展示证据收集中。

Growth Attribution Ledger：

- 每次完整闭环可以产生 0-N 条 metric contribution candidate。
- 每周/月报告把候选贡献聚合成 MetricSnapshot。
- 用户可以接受、驳回或标记不准确。
- Growth Detail 按时间展示贡献账本，用户可以看到“哪一天、哪条任务、哪次验证”导致指标加分或减分。
- 贡献账本是解释层，不允许把用户定义成某种人格或固定能力类型。

### Settings

设置项包括：

- GLM API Key。
- 默认训练模式。
- 隐私边界说明。
- 数据导出与清除。
- 本地通知开关。
- 主题和字体密度。

## AI Boundaries

- AI 负责整理、推荐、追问和校准建议。
- 用户负责确认、取舍、验证和原则采纳。
- AI 不能要求用户上传原始敏感资料。
- AI 输出必须可追踪到 prompt 版本和模型版本。

## Non-Goals

MVP 不做：

- 服务端代理。
- 账号体系。
- App Store 发布流程。
- 自研语音识别。
- Apple 日历/提醒事项同步。
- 完整角色卡系统。
- 外部框架包市场。
- Mirror Cards。
- 能力图谱。
- Schema 动态 UI。
- 复杂动画。

说明：

- MVP 不做通用 Schema 动态 UI，但 `organizeCards` 的 XML-like 流式协议属于固定卡片组件的传输和展示增强，属于 MVP 范围。

## Acceptance Criteria

MVP 完成时，用户能够：

- 输入一次完整的日常反思。
- 得到结构化卡片。
- 选择透镜并回答至少一个问题。
- 获得一个可执行的明日主线任务。
- 第二天完成验证。
- 保存一条原则候选。
- 在历史里找到完整证据链。
