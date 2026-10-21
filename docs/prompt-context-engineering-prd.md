# 明思 Prompt 与上下文工程 PRD

版本：v1.4

状态：MVP 可执行规格，后续作为 Prompt、上下文检索、原则资产、经验总结、审计链路和服务端迁移的验收依据。

## 0. 对齐摘要

这一版文档用于和产品负责人对齐“明思”的核心算法资产：Prompt、透镜、提问策略、经验总结、上下文召回和审计链路。

当前 MVP 的目标实现可以概括为：

```text
用户输入
-> organizeCards：通过 MINGSI_STREAM_V1 XML-like SSE 只整理当前原文，不注入历史规则
-> StreamingCardDraft：临时展示，不入库
-> 闭合并校验后转换为 ThinkingCard 候选
-> 用户确认卡片和排除敏感卡片
-> CoachTurnState：生成有状态教练轮次，记录 phase/readiness/recommendedMove/openEvidenceGaps
-> 教练推荐训练处方，用户接受、放慢、或 override 推进
-> generateQuestions：注入已确认卡片、透镜、CoachTurnState、最多 3 条相关 active 原则
-> 用户回答追问
-> CoachTurnState：根据回答刷新 readiness 和 recommendedMove
-> generateQuests：注入卡片、回答、透镜、CoachTurnState、最多 3 条相关 active 原则
-> 用户确认明日主线任务
-> extractPrinciple：注入卡片、回答、任务、已有原则，用于提取或去重经验总结
-> 次日 verifyQuest：校准任务价值和完成情况
-> PromptRun：记录 source ids、context ids、响应或错误，支持审计和补跑
```

当前不做的事：

- 不让 AI 直接替用户决策。
- 不把历史原则注入 `organizeCards`，避免污染事实拆解。
- `organizeCards` 的流式输出只是传输和展示协议，不改变正式卡片、历史、项目和成长的数据模型。
- 不把未确认的原则候选放进未来上下文。
- 不把 Growth 分数或长期画像注入日常追问。
- 不允许模型输出任意 UI schema 直接改写核心状态机。

本 PRD 的关键判断：

- **提问不是聊天能力，而是有状态教练轮次 + 透镜 + 当天证据 + 用户历史原则的组合。**
- **透镜不是卡片皮肤，而是决定提问方向和任务取舍标准的结构化策略。**
- **经验总结不是金句，而是可触发、可行动、可验证、可回链证据的 PrincipleAsset。**
- **上下文工程不是把资料都塞给模型，而是在不同 Prompt 阶段选择该进入的证据，并记录为什么进入。**
- **PromptRun 审计是竞争力的一部分，因为它让每次 AI 建议都能追溯、复盘、修正和评测。**

### 0.1 当前对齐结论

当前明思的 Prompt / 上下文工程不是“把日记发给大模型让它总结”，而是一套分阶段算法：

```text
材料清理 Prompt
-> 用户确认事实
-> 透镜策略 Prompt
-> 用户回答追问
-> 行动选择 Prompt
-> 用户验证结果
-> 经验总结 Prompt
-> 规则资产召回策略
```

其中最核心的产品资产有 6 类：

| 资产 | 作用 | 是否 MVP 必须 |
| --- | --- | --- |
| Prompt Template | 定义每一步 AI 应该做什么、不能做什么、输出什么 schema。 | 是 |
| Lens Asset | 定义不同思考方式如何影响追问和任务选择。 | 是，先固定 3 个 |
| Coach Turn State | 定义 Today 当前处于澄清、补证据还是形成行动，以及用户是否 ready。 | 是 |
| Principle Asset | 用户确认过的经验总结，后续相似场景召回。 | 是 |
| Context Policy | 定义每个 Prompt 允许看见哪些上下文，包括 CoachTurnState 只能进入追问和任务生成，不能进入 `organizeCards`。 | 是 |
| PromptRun / Context Audit | 记录每次 AI 调用了什么、看了哪些 source/context、结果和错误是什么。 | 是 |

这 6 类资产必须版本化、可测试、可迁移。后续即使把 Prompt、透镜包、规则包迁移到服务端，App 也不能失去用户确认、敏感排除、本地证据和审计链路的控制权。

## 1. 文档目的

Prompt 与上下文工程是明思的核心产品能力，不是普通接口实现。

明思的目标不是让 AI 替用户思考，而是用稳定的上下文选择、思考透镜、追问策略、原则资产调用和结果校准，训练用户把事情想清楚。

本 PRD 回答以下问题：

- 当前“提问、透视、经验总结”的 Prompt 是怎么设计的。
- 每个 Prompt 在什么时机触发，输入什么，输出什么。
- 用户沉淀下来的规则、原则、经验资产什么时候进入上下文。
- 上下文工程如何避免信息茧房、AI 代替用户下结论、历史资产污染新事实。
- 当前 MVP 已经实现什么，哪些是后续明确预留。
- 后续如果把 Prompt、透镜、规则资产迁移到服务端，App 端应该如何保持低耦合。

## 2. 产品定位

明思是一套个人思维训练系统，也可以理解为元认知微调框架。

核心闭环：

```text
Raw Input
-> Evidence Cards
-> Lens Selection
-> Context-Aware Questions
-> User Answers
-> Tomorrow Quest
-> Next-Day Verification
-> Principle Asset
-> Future Context Retrieval
```

竞争力来自：

- 不是一次性总结，而是跨天积累用户的判断证据。
- 不是固定问卷，而是基于当天材料、历史原则和执行校准生成追问。
- 不是泛泛建议，而是把用户确认过的行为规则转成下一次可验证行动。
- 不是人格测评，而是用可追溯证据形成元认知反馈。
- 不是让用户“看起来思考过”，而是让用户反复经历“澄清、质疑、选择、行动、校准”的训练。

## 3. Prompt 核心原则

### 3.1 AI 的角色

AI 是思考教练，不是代决策者。

AI 可以：

- 整理事实。
- 暴露假设。
- 追问矛盾。
- 提供反方视角。
- 建议下一步验证动作。
- 提醒用户对照自己已经确认过的原则。

AI 不可以：

- 替用户确认价值排序。
- 替用户给敏感业务下结论。
- 无证据地判断用户性格。
- 把一次输入上升为长期人格标签。
- 用口号替代具体行动。
- 因为历史原则存在，就强行把今天的情况套进去。

### 3.2 输出契约

所有生产 Prompt 必须：

- 输出 JSON。
- 有 prompt version 和 output schema version。
- 有可追溯的 source id 或 source title。
- 能被 parser 拒绝不合格结果。
- 失败后允许 retry 或补跑。
- 不把“建议”伪装成“事实”。

### 3.3 隐私契约

Prompt 必须持续提醒：

- 不要求用户输入公司敏感资料、代码、客户名、内部项目名。
- 对疑似敏感内容做抽象化表达。
- 长期资产默认使用用户确认后的抽象名称。
- 敏感卡片可以被用户排除出模型上下文。

## 4. 当前实现基线

当前代码里的请求链路：

```text
TodayView / AppStore
-> TodayAIService
-> PromptProvider
-> ContextAssembler
-> PrincipleRetriever
-> LLMClient
-> TodayAIResponseParser
-> PromptRun tracing
```

当前模块职责：

| 模块 | 当前职责 |
| --- | --- |
| `PromptID` | 定义 Prompt 类型：整理卡片、生成追问、生成任务、验证任务、沉淀原则、周校准、月成长。 |
| `LocalPromptProvider` | 返回本地版本化 Prompt 模板，包括 systemText、userText、schemaVersion。 |
| `TodayAIService` | 编排 Today 流程里的 AI 调用，不直接写 Prompt 文案。 |
| `DefaultContextAssembler` | 按 promptId 选择本次请求上下文。 |
| `LocalPrincipleRetriever` | 从 active 原则资产中检索 0-3 条相关原则。 |
| `LLMRequest` | 携带 Prompt 模板、输入摘要、payload、source ids、context version、context ids。 |
| `DirectGLMClient` | 以 OpenAI-compatible Chat Completion 格式调用 GLM。 |
| `PromptTracingLLMClient` | 记录成功或失败的 PromptRun，用于审计和补跑。 |
| `TodayAIResponseParser` | 把模型 JSON 解析成业务对象，拒绝明显不合格输出。 |

当前已经传递的上下文：

- `DailyEntry.rawText`。
- `sessionMode`。
- `confirmedCards`。
- `selectedLens`。
- `reflectionAnswers`。
- `selectedQuest`。
- `sourceRecordIDs`。
- `contextRecordIDs`。
- `relevantPrinciples`，仅在合适 Prompt 注入。

当前重要缺口：

- `LLMRequest.jsonPayload` 还是 `[String: String]`，结构表达力不足。
- Project、Growth、Verification 历史上下文还没有进入统一上下文选择策略。
- Prompt Eval 已有基础测试，但还没有形成完整离线评测集和人工评分面板。
- Prompt 模板仍在 App 本地，后续迁移服务端时需要版本化发布和回滚机制。

## 5. 请求生命周期

一次 AI 请求必须按以下顺序生成：

```text
1. 用户动作触发某个 PromptID
2. TodayAIService 获取 PromptTemplate
3. ContextAssembler 按 PromptID 选择上下文
4. PrincipleRetriever 判断是否需要原则资产
5. 生成 LLMRequest
6. DirectGLMClient 拼装 system message 和 user message
7. GLM 返回 JSON
8. Parser 解析并校验
9. AppStore 写入本地状态
10. AppStore 刷新本次参考原则展示
11. PromptRun 记录成功或失败
```

GLM 请求内容由三层组成：

```text
System:
  明思的角色、边界、隐私约束、模式约束、JSON 输出要求

User:
  Prompt ID / Prompt version / Context version / Output schema version
  Task instruction
  Input summary
  Payload

Payload:
  当前输入 + 用户选择 + 选中的上下文 + 隐私规则
```

这意味着 Prompt 文案、上下文选择、模型供应商三者是分离的：

- 换 GLM、OpenAI 或其他模型时，不应该重写业务流程。
- Prompt 从本地迁移到服务端时，不应该重写 SwiftUI 页面。
- 上下文检索从关键词升级到 embedding 时，不应该重写 Today 流程。

### 5.1 当前真实请求结构

MVP 当前使用 OpenAI-compatible Chat Completions 形式请求 GLM。

请求消息：

```text
messages[0]:
  role: system
  content: PromptTemplate.systemText

messages[1]:
  role: user
  content:
    Prompt ID
    Prompt version
    Context version
    Output schema version

    Task:
      PromptTemplate.userText

    Input summary:
      ContextAssembler.inputSummary

    Payload:
      jsonPayload sorted by key
```

传输层：

- `DirectGLMClient` 默认携带 `response_format: {"type": "json_object"}`。
- 如果 GLM endpoint 因 `response_format` 返回 400/422，客户端会自动重试一次，不带 `response_format`。
- 所有 Prompt 文案仍必须显式要求 JSON，因为并不是所有兼容 endpoint 都稳定支持 JSON mode。

这代表“上下文工程”不只是 Prompt 文案，而是以下四件事的组合：

```text
PromptTemplate
+ PromptContext.payload
+ PromptContext.sourceRecordIDs / contextRecordIDs
+ Parser / PromptRun audit
```

### 5.1.1 Prompt 资产组织方式

每个 Prompt 都不能只是一段自然语言。明思里的 Prompt 应被组织成一个可版本化资产：

```json
{
  "promptId": "generateQuestions",
  "promptVersion": "1.0.0",
  "systemPolicyVersion": "1",
  "contextPolicyVersion": "1",
  "lensPolicyVersion": "1",
  "outputSchemaVersion": 1,
  "evalSuiteVersion": "questions.v1",
  "task": "Generate lens-specific reflection questions",
  "allowedContextLayers": ["L0", "L1", "L2", "L3"],
  "forbiddenContextLayers": ["L5", "L6"],
  "outputContract": "ReflectionQuestion[]"
}
```

Prompt 由 6 个部分组成：

| 部分 | 内容 | 变更方式 |
| --- | --- | --- |
| System Policy | 明思的角色、边界、隐私规则、禁止事项。 | 低频变更，影响所有 Prompt。 |
| Task Template | 当前 Prompt 的任务说明，例如整理卡片、生成追问、生成任务。 | 按 Prompt 版本变更。 |
| Mode Guidance | Quick / Standard / Deep 的深度差异。 | 可随 Prompt 版本变更。 |
| Lens Context | 透镜目的、提问方向、任务选择标准、反偏见规则。 | 后续由 Lens Asset 管理。 |
| Context Payload | 当前输入、卡片、回答、任务、原则、项目、成长等结构化上下文。 | 由 Context Policy 决定。 |
| Output Schema | 模型必须返回的 JSON schema，Parser 依此校验。 | 必须显式版本化。 |

组织原则：

- Prompt 负责“如何思考和输出”，不负责决定“哪些历史资产可以进入上下文”。
- Context Policy 负责“给这个 Prompt 看什么”，不负责写自然语言任务。
- Lens Asset 负责“用什么视角追问和取舍”，不负责替用户下结论。
- Principle Asset 负责“用户过去确认过什么规则”，不负责强迫今天必须遵守。
- Parser 负责“拒绝不合格输出”，不靠 UI 默默容忍坏结果。

因此后续服务端化时，替换的是 Provider / Policy / Retriever，不应重写 Today 状态机。

### 5.1.2 一次请求的上下文包示例

假设用户沉淀过一条原则：

```text
跨角色会议前先写清决策、负责人、验收标准。
```

今天输入：

```text
今天开会又绕了很久，最后没有确认谁负责落地。
```

用户确认卡片并选择 `evidenceCheck` 后，`generateQuestions` 的上下文包应接近：

```json
{
  "source": {
    "dailyEntryId": "daily-uuid",
    "confirmedCards": [
      {
        "id": "card-uuid",
        "type": "problem",
        "title": "会议未确认负责人",
        "body": "会议结束时没有明确谁负责落地。"
      }
    ]
  },
  "userChoice": {
    "sessionMode": "standard",
    "selectedLens": "evidenceCheck"
  },
  "reference": {
    "principles": [
      {
        "id": "principle-uuid",
        "title": "会前明确决策和负责人",
        "triggerContext": "跨角色会议",
        "actions": ["写出要确认的决策", "确认负责人", "定义验收标准"],
        "successCriteria": "会后每个 action 有 owner 和 done 标准",
        "usageRule": "仅作对照；如果今天不适用，允许指出不适用。"
      }
    ]
  },
  "privacy": {
    "excludedSensitiveCards": [],
    "rule": "不要要求用户输入公司敏感资料、代码、客户名或内部项目名。"
  }
}
```

模型在这个请求中可以问：

```text
这次会议“没有负责人”是已确认事实，还是你对会后状态的判断？如果要验证，最小证据是什么？
```

模型不应该直接说：

```text
你之前已经保存过会议原则，所以明天必须照做。
```

这一区别是产品质量关键：历史原则只能帮助用户对照自己的行为，不能替代用户判断今天的事实和取舍。

### 5.2 Prompt 编排算法

每个 Prompt 必须通过同一套编排流程：

```text
PromptID
-> PromptProvider.template(promptID, mode)
-> ContextAssembler.assemble(promptID, TodayAIContext)
-> PrincipleRetriever.relevantPrinciples(...)
-> LLMRequest
-> LLMClient.complete(...)
-> TodayAIResponseParser
-> AppStore state mutation
-> Repository persistence
-> PromptRun audit
```

禁止在 SwiftUI View 中拼 Prompt，也禁止让 View 直接决定历史资产是否进入上下文。

职责边界：

| 层 | 负责 | 不负责 |
| --- | --- | --- |
| View | 采集用户输入、展示状态、发起用户动作 | 选择上下文、拼 Prompt、解析模型 JSON |
| AppStore | 编排状态机、调用 AI service、保存结果 | 写死 Prompt 文案 |
| TodayAIService | 根据业务动作调用对应 Prompt | 判断 UI 如何展示 |
| PromptProvider | 提供版本化 Prompt 模板 | 读取数据库 |
| ContextAssembler | 选择当前请求上下文 | 调用模型 |
| PrincipleRetriever | 召回相关原则资产 | 修改原则资产 |
| Parser | 校验输出 schema | 容忍不合格 JSON |

### 5.3 上下文预算和优先级

上下文不是越多越好。MVP 必须按以下优先级放入请求：

1. 当前用户输入和用户确认过的当前闭环数据。
2. 用户当下选择，例如 `sessionMode`、`selectedLens`。
3. 与当前材料直接相关的 source ids。
4. 用户确认过的 active 原则资产，最多 3 条。
5. 后续才加入项目、成长指标、长期画像等低频上下文。

如果上下文预算不足，丢弃顺序为：

```text
长期画像
-> 成长弱信号
-> 项目摘要
-> 低相关原则
-> 未确认卡片
-> 当前输入和已确认卡片永不丢弃
```

冲突处理：

- 当前事实优先于历史原则。
- 用户手动确认优先于 AI 推断。
- 用户当天编辑后的内容优先于原始 AI 输出。
- 如果历史原则和当前事实冲突，Prompt 必须允许“这条原则今天不适用”。

### 5.4 当前实现与目标实现差异

| 项目 | 当前实现 | 目标实现 |
| --- | --- | --- |
| Prompt 模板 | `LocalPromptProvider` 本地 Swift 字符串 | `RemotePromptProvider` 版本化发布、灰度、回滚 |
| Payload | `[String: String]` 扁平结构 | `PromptContextPayload: Codable` 结构化 schema |
| 原则检索 | 本地关键词打分，最多 3 条 | embedding + 使用反馈 + recent/practiced 权重 |
| 透镜 | 固定 3 个枚举 | 结构化 Lens object + 用户自定义 + 透镜包 |
| PromptRun | 独立记录 prompt/source/context/response/error | source/context 关系表、召回理由、用户反馈 |
| Referenced Principles UI | 追问和任务阶段展示本次召回原则 | 展示召回理由、适用/不适用反馈 |
| Project/Growth context | 模型和数据层已预留，Prompt 未系统注入 | 按 Context Matrix 进入周/月和任务设计 |

MVP 可以接受当前实现，但所有后续改造必须保持上述接口边界稳定。

## 6. Prompt 清单

### 6.1 `organizeCards`

触发时机：

- 用户在“今日输入”完成原始文本输入后点击整理。

产品目标：

- 把混乱口述或文本拆成可编辑卡片。
- 区分事实、问题、决策、风险、想法、沟通、任务。
- 标记疑似敏感内容。
- 不把输入总结成一篇文章。

输入上下文：

- `rawText`。
- `sessionMode`。
- `privacyRules`。
- 后续可加入 `transcriptQualityHint`。

明确不注入：

- 原则资产。
- 项目历史。
- 成长分数。
- 全量历史记录。

原因：

- 这一阶段只做“材料清理”，不能让历史标签提前影响事实拆解。

输出：

```json
{
  "cards": [
    {
      "type": "fact | problem | decision | risk | idea | communication | task",
      "title": "string",
      "body": "string",
      "importance": "low | medium | high",
      "sensitivity": "normal | possibly_sensitive | sensitive",
      "confidence": "low | medium | high",
      "reason": "string"
    }
  ],
  "sensitivity_notes": ["string"],
  "transcript_quality": "low | medium | high",
  "recommended_next_step": "string"
}
```


- 不生成长文总结。
- 至少能拆出事实、问题、任务中的有效类型。
- 对疑似敏感内容保守标记。
- 用户能在 UI 中确认、排除、删除，后续应支持编辑和合并。

### 6.2 `generateQuestions`

触发时机：

- 用户确认卡片并接受、改选或跳过当前思考方向后；如果材料已经足够，可以直接返回空问题集。

产品目标：

- 让用户从一个明确但可撤回的思考方向继续思考。
- 提问必须围绕当天材料，不能是通用鸡汤问题。
- 当前请求最多一个问题；只有回答会改变判断、选择、证据检查或可观察信号时才提问。
- 不要求同一轮同时完成事实、反例和明日行动三个动作；后续轮次只在同一判断仍未闭合时继续。

输入上下文：

- `confirmedCards`。
- `selectedLens`。
- `priorAnswers`。
- `sessionMode`。
- `relevantPrinciples`，可选，最多 3 条。

原则资产调用：

- 只调用 active 原则。
- 只调用和当天卡片、透镜、问题有足够相关性的原则。
- 原则只作为对照，不允许强行套用。

输出：

```json
{
  "questions": [
    {
      "question": "string",
      "why_this_matters": "string",
      "expected_answer_type": "fact | judgment | tradeoff | validation"
    }
  ]
}
```

`source_card_titles` 必须是当前 `confirmedCards.title` 的逐字子集（仅忽略首尾空格）。问题、行动和原则的运行时质量门都会再次核对这条归属；无法回链的模型输出拒绝进入下一步。

模式差异：

| Mode | 提问策略 |
| --- | --- |
| Quick | 当前请求 0-1 个问题，只做最小有用动作。 |
| Standard | 当前请求 0-1 个问题；同一判断未闭合时由下一请求给一条修补问题。 |
| Deep | 当前请求仍为 0-1 个问题，只增加证据审查深度，不生成问卷。 |

### 6.3 `generateQuests`

触发时机：

- 用户回答至少一个追问后。

产品目标：

- 把当天已经复盘的一个判断转成明天可验证行动。
- 当前线上合同只生成一个主验证行动；没有已复盘判断时不制造普通待办。
- 主任务必须指向高价值动作，不是最容易完成的动作。

输入上下文：

- `confirmedCards`。
- `reflectionAnswers`。
- `selectedLens`。
- `sessionMode`。
- `relevantPrinciples`，可选，最多 3 条。
- 后续可加入 `activeProjectHints` 和 `recentFailurePattern`。

原则资产调用：

- 如果某条原则适用，AI 可以说明这个任务如何实践该原则。
- 如果原则不适用，AI 应忽略或明确“不适用”。
- 任务必须来自当天材料和用户回答，不能只因为原则存在而生成。

输出：

```json
{
  "main_quest": {
    "type": "main",
    "title": "string",
    "why_it_matters": "string",
    "completion_criteria": "string",
    "expected_resistance": "string",
    "reflection_question": "string",
    "linked_cards": ["string"]
  },
  "side_quests": [],
  "observation_quest": null,
  "rejected_low_value_tasks": ["string"]
}
```

验收标准：

- 主任务只有一个。
- 完成标准可验证。
- 预期阻力具体。
- 能回链到卡片或回答。
- 用户后续应能编辑、重试生成、保存为长期议题。

### 6.4 `verifyQuest`

触发时机：

- 第二天用户反馈昨日任务完成情况和价值判断。

产品目标：

- 校准“任务有没有选对”，而不是简单判断用户有没有努力。
- 识别低价值任务、标准模糊、阻力低估、依赖阻塞、回避、中断等情况。
- 把校准结果反馈到未来任务设计。

输入上下文：

- `questTitle`。
- `completionCriteria`。
- `completion`。
- `valueRating`。
- `rawText`，可选。
- `sourceRecordIDs`。

当前不注入：

- 全量原则库。
- 人格判断。
- Growth 分数。

输出：

```json
{
  "calibration_note": "string",
  "likely_issue": "none | task_too_large | unclear_criteria | low_value | dependency_blocked | avoidance | interruption",
  "recommendation": "string"
}
```

验收标准：

- 不责备用户。
- 不根据一次失败做人格判断。
- 不编造未提供的原因。
- Verification 必须能回链到原始 quest 和 daily entry。

### 6.5 `extractPrinciple`

触发时机：

- 用户保存明日任务后。
- 或用户主动把某条结论保存为行为标准。

产品目标：

- 从当天卡片、回答和任务中提取“可复用、可验证、可行动”的原则候选。
- 帮用户沉淀自己的行为标准，而不是保存金句。

输入上下文：

- `confirmedCards`。
- `reflectionAnswers`。
- `selectedQuest`。
- `existingPrinciples`，用于去重和合并。
- 后续可加入 `verification`。

输出：

```json
{
  "principle_candidate": {
    "title": "string",
    "summary": "string",
    "trigger_context": "string",
    "actions": ["string"],
    "success_criteria": "string",
    "exceptions": "string",
    "source_card_titles": ["string"]
  }
}
```

如果不值得沉淀：

```json
{
  "principle_candidate": null
}
```

沉淀标准：

- 必须可复用。
- 必须有触发场景。
- 必须有行动步骤。
- 必须有成功标准。
- 必须有例外条件。
- 必须能追溯到 source ids。

不沉淀：

- 一次性任务。
- 泛泛感悟。
- 情绪宣泄。
- 无行动标准的价值判断。

### 6.6 `weeklyCalibration`

MVP 状态：

- PromptID 和本地模板已预留。
- 完整周报工作流不作为第一轮强制闭环。

后续触发：

- 用户一周内完成 3 次以上“任务 + 次日验证”闭环。

输入上下文：

- 多日 DailyEntry 摘要。
- quest outcomes。
- verification。
- practiced principles。
- metric contributions。

输出目标：

- 本周最高价值动作。
- 最低价值时间消耗。
- 重复阻碍。
- 重复思维模式。
- 下周训练重点。

要求：

- 每个判断都要有证据。
- 不做空泛表扬。

### 6.7 `monthlyGrowth`

MVP 状态：

- PromptID 和本地模板已预留。
- 当前 Growth 更偏本地证据归因，完整月报后续实现。

后续触发：

- 用户完成足够多闭环，且有验证证据。

输入上下文：

- 月度 daily records。
- quest outcomes。
- verification。
- principle assets practiced。
- metric contributions。
- 用户对不准确归因的反馈。

输出目标：

- clarity。
- value judgment。
- execution reliability。
- calibration。
- reflection depth。
- before/after examples。
- next month focus。

要求：

- 每个分数变化必须有 source id。
- 必须允许正负贡献并存。
- 指标只能表示个人训练趋势，不能包装成客观智力评分。

## 7. 透镜系统

### 7.1 MVP 固定透镜

| Lens | 中文名 | 目的 | 提问方向 |
| --- | --- | --- | --- |
| `evidenceCheck` | 证据校验 | 分离事实、判断、假设 | “你确信的事实是什么？”“哪个判断还没有证据？” |
| `opposingView` | 反方视角 | 防止只证明自己是对的 | “如果你错了，最可能错在哪里？” |
| `leverageAnalysis` | 杠杆分析 | 找高价值动作 | “哪一步最能改变结果？”“哪个动作只是忙碌？” |

### 7.2 透镜如何影响 Prompt

透镜不是 UI 标签，而是影响提问策略的结构化上下文。

透镜进入 `generateQuestions` 和 `generateQuests`：

- `generateQuestions`：决定问题方向。
- `generateQuests`：决定任务的取舍标准。

透镜不进入 `organizeCards`：

- 避免用户还没有确认事实前，系统就带着某种解释框架拆材料。

### 7.3 MVP 透镜策略

早期 MVP 不做“透镜推荐模型”作为强依赖，用户在卡片确认后手动选择透镜，系统随后用该透镜生成追问和任务。这个设计适合验证透镜价值，但不应作为最终产品心智：如果用户必须先自选透镜，明思会退化成思维工具箱，而不是教练。

当前下一阶段目标是 Coach Turn State v1：明思根据今日卡片、历史反馈、证据缺口和近期训练表现维护一个有状态教练轮次，用户负责接受、放慢、改选或 override 推进。手动选择透镜应降级为 override 机制；系统需要同时记录 coachRecommendedLens、userSelectedLens 和 coachTurnState，避免把用户自选误当作教练诊断。

单次训练仍然只保留一个主训练焦点，但 prompt/context 必须携带基础思维底盘检查：事实/解释分离、证据缺口、反例、假设、可验证行动、反馈信号、判断更新。复盘阶段再区分 targetedPractice、secondaryPractice 和 possibleSignal。

本阶段不引入 LangChain/LangGraph，不做通用聊天 agent，不扩大订阅、同步、市场或 lens pack。CoachTurnState 应先作为本地、确定性、可审计的 Today 状态机进入 `generateQuestions` / `generateQuests` 上下文，并明确不进入 `organizeCards`。

当前 3 个透镜的 Prompt 行为：

| Lens | 追问策略 | 任务策略 | 反偏见约束 |
| --- | --- | --- | --- |
| `evidenceCheck` | 要求用户把事实、解释、缺失证据拆开。 | 主任务优先选择能补足证据或验证判断的动作。 | 不允许把感觉、印象、单次反馈当作确定事实。 |
| `opposingView` | 要求用户指出自己可能错在哪里、什么证据能推翻当前判断。 | 主任务优先选择能暴露反例或降低错误决策成本的动作。 | 不允许只生成支持用户原观点的问题。 |
| `leverageAnalysis` | 要求用户比较动作影响、机会成本和瓶颈。 | 主任务优先选择最高杠杆动作，而不是最容易完成的动作。 | 不允许把忙碌型任务包装成高价值任务。 |

Prompt 文案里当前以 `selectedLens` 字段传入。目标形态应升级为结构化 LensContext：

```json
{
  "id": "leverageAnalysis",
  "name": "杠杆分析",
  "purpose": "找到最能改变结果的一步",
  "questionStrategy": ["比较动作影响", "识别瓶颈", "排除低价值忙碌"],
  "questSelectionRule": "优先生成能改变关键结果的明日主线任务",
  "failureMode": "把容易完成误判为高价值",
  "outputBiasGuard": "必须列出至少一个被拒绝的低价值任务"
}
```

### 7.4 用户自定义透镜和角色卡预留

后续用户自定义透镜、名人思考模式、职业角色卡都属于 Lens 扩展，不应重写 Today 流程。

结构要求：

```json
{
  "id": "custom_uuid",
  "kind": "principle | method | role | person_inspired | user_custom",
  "displayName": "string",
  "shortDescription": "string",
  "questionStrategy": ["string"],
  "questSelectionRule": "string",
  "evidenceRequirement": "string",
  "antiPattern": "string",
  "safetyBoundary": "string",
  "version": "string",
  "author": "system | user | marketplace",
  "status": "active | disabled | archived"
}
```

名人角色卡边界：

- 只能使用公开可抽象的方法论。
- 不允许伪装成该人物本人正在说话。
- 不允许把该人物所有观点当成事实或权威。
- 必须保留 `safetyBoundary`，避免角色风格压过用户自己的判断。

UI 预留：

- 透镜卡片可以有不同视觉形态，但业务层只依赖 Lens id 和 LensContext。
- 后续 Schema 出 UI 时，只能影响展示组件，不允许模型直接改写核心状态机。
- 自定义透镜必须先保存为本地结构化对象，再进入 Prompt，而不是把用户随手输入的 prompt 原文直接拼入系统 prompt。

### 7.5 后续透镜扩展

后续可支持：

- First Principles。
- Occam's Razor。
- Opportunity Cost。
- Socratic Questioning。
- Charlie Munger mental models。
- Role Lens，例如 PM、CEO、Engineer、Operator。
- 用户自定义透镜。
- 透镜包 marketplace。

扩展要求：

- Lens 必须是结构化对象，不是纯 prompt 字符串。
- Lens 必须有 `id`、`name`、`purpose`、`questionStrategy`、`failureMode`、`outputBiasGuard`。
- 用户自定义 Lens 必须有来源、版本、适用场景、禁用条件。
- 名人角色卡必须抽象其公开思维方式，不应伪装成真实人物发言。

## 8. 上下文架构

每次请求由以下层组成：

```text
System Role
Prompt Instruction
Task Payload
Selected Context
Output Schema
Safety / Privacy Rules
```

上下文分层：

| Layer | 内容 | MVP 状态 |
| --- | --- | --- |
| L0 Current Input | rawText、confirmedCards、answers、quest | 必须 |
| L1 User Choice | sessionMode、selectedLens | 必须 |
| L2 Evidence Links | sourceRecordIDs、card ids、quest ids | 必须 |
| L3 Principle Assets | 相关原则资产 | 已有本地检索雏形 |
| L4 Project Context | active projects、project links | 后续强化 |
| L5 Growth Context | metric weaknesses、recent failure patterns | 后续强化 |
| L6 User Profile | 长期偏好、常见盲点、表达风格 | 后续，必须谨慎 |

## 9. Context Matrix

| Prompt | 当前输入 | 用户选择 | 原则资产 | 项目上下文 | 成长上下文 | 说明 |
| --- | --- | --- | --- | --- | --- | --- |
| `organizeCards` | rawText | sessionMode | 不注入 | 不注入 | 不注入 | 先拆事实，不让历史结论污染材料；使用 XML-like SSE 流式输出临时卡片。 |
| `generateQuestions` | confirmedCards、priorAnswers | selectedLens、sessionMode | Coach Context Memory v1 选出的相关原则 0-3 条、同 final lens 的 lensFeedback 0-2 条、当前 CoachTurnState | 后续 | 后续 | 用透镜和当前教练轮次决定追问方向，用少量历史记忆做对照。 |
| `generateQuests` | confirmedCards、reflectionAnswers | selectedLens、sessionMode | Coach Context Memory v1 选出的相关原则 0-3 条、同 final lens 的 lensFeedback 0-2 条、当前 CoachTurnState | 后续 | 后续 | 任务必须来自当天材料，原则和反馈只能辅助验收与校准。 |
| `verifyQuest` | yesterdayQuest、completion、valueRating | sessionMode | 后续 | 后续 | 后续 | 校准任务设计，不做人格判断。 |
| `extractPrinciple` | cards、answers、quest | sessionMode | existingPrinciples | 后续 | 后续 | 生成候选原则，并避免重复沉淀。 |
| `weeklyCalibration` | 多日闭环证据 | 后续 | practiced principles | 后续 | metric contributions | 证据足够才生成趋势。 |
| `monthlyGrowth` | 月度证据链 | 后续 | practiced principles | 后续 | metric history | 展示前后变化、加减分证据和下月训练重点。 |

### 9.1 Prompt 调用时机和上下文闸门

每个 Prompt 必须经过“上下文闸门”，不能因为本地有数据就自动注入。

| Prompt | 调用入口 | 必须上下文 | 可选上下文 | 明确禁止 | 失败后的产品行为 |
| --- | --- | --- | --- | --- | --- |
| `organizeCards` | 今日输入后点击整理 | `rawText`、`sessionMode`、隐私规则 | 语音质量提示 | 原则、项目、成长、长期画像、trainingPrescription、lensFeedback、coachTurnState | XML-like SSE 流式生成临时卡片；失败时保留已闭合卡片或生成本地 fallback，保留重试入口。 |
| `generateQuestions` | 卡片确认 + 透镜选择后 | 已确认且未排除的卡片、`selectedLens`、`sessionMode` | Coach Context Memory v1 选出的相关 active 原则 0-3 条、同 final lens 的 lensFeedback 0-2 条 | `trainingPrescription`、`coachDiagnosis`、`coachTurnState`、`coachTeachingPlan`、`coachPatternSummary`、未确认原则、全量历史、其他 lens 的反馈、Growth 分数、历史 coach turn 全量记录 | 本地 fallback 追问，UI 展示失败原因和可重试。 |
| `generateQuests` | 用户至少回答一个追问后 | 已确认卡片、用户回答、`selectedLens`、`sessionMode`、当前 CoachTurnState | Coach Context Memory v1 选出的相关 active 原则 0-3 条、同 final lens 的 lensFeedback 0-2 条、trainingPrescription | 与当天材料无关的历史建议、其他 lens 的反馈、历史 coach turn 全量记录 | 本地 fallback 任务，保留同一步补跑。 |
| `verifyQuest` | 次日验证昨日任务时 | 原任务、完成标准、完成情况、价值评分 | 用户补充说明 | 人格标签、全量原则库 | 保留用户验证，AI 校准可稍后补跑。 |
| `extractPrinciple` | 明日任务确认后 | 卡片、回答、任务 | 已有 active/needsReview 原则，用于去重 | Growth 分数、项目洞察 | 如果无稳定经验返回空候选；失败时本地生成弱候选或允许跳过。 |
| `weeklyCalibration` | 一周足够闭环后 | 多日记录、任务、验证 | 练习过的原则、贡献证据 | 无证据的人格判断 | 不足证据时显示“证据不足”，不强行生成。 |
| `monthlyGrowth` | 月度证据足够后 | 月度记录、验证、指标贡献 | 原则实践证据、用户否认反馈 | 单次输入推断人格 | 展示趋势和证据，不输出绝对能力标签。 |

上下文闸门的产品意义：

- 让用户知道 AI 的判断来自哪些材料。
- 防止历史原则把今天的新事实提前解释掉。
- 防止 Growth / 画像类信息反过来限制用户思考。
- 让后续服务端检索、embedding、规则包升级时仍能保持同一条产品边界。

### 9.1.1 Coach Context Memory v1

Coach Context Memory v1 决定历史原则、lens feedback、过往教练结果什么时候进入当前教练轮次。它的目标不是让模型“知道更多”，而是让当前轮次得到少量、可解释、不会污染当天判断的参考材料。

当前本地策略版本为 `coach-context-memory.local-v1`：

- `organizeCards` 和 `recommendLenses` 不接收任何 coach memory。它们只处理当天原始材料，不能被历史原则、训练处方、lens feedback 或 coach turn 预设解释。
- 当前 `generateQuestions` 仅接收确认卡片、最新回答、用户选择视角、最多 3 条相关 active 原则及最多 2 条匹配视角的 verified `lensFeedback`；不接收 `TrainingPrescription`、`CoachTurnState`、本地诊断或教学计划作为隐藏训练目标。
- `generateQuests` 可以接收当前 `TrainingPrescription`、当前 `CoachTurnState`、最多 3 条相关 active 原则，以及最多 2 条与 final lens 相同的 verified `lensFeedback`。
- 2026-10-16：行动生成的教练状态和教学计划是可选参考。移除要求补问或强制达到教学标准的旧 directives；用户明确选择带着缺口继续时，当前版本化模板负责设计一个保留未知的安全行动，不能由上下文再次开启问卷。
- `extractPrinciple` 可以接收 `TrainingPrescription` 和 existingPrinciples 作为去重/合并参考，但不接收 lens feedback 或历史 coach turn。
- `verifyQuest` 不接收全量原则库、lens feedback 或 coach turn；它只接收昨日任务、完成结果、价值评分，以及本地已选定的 expected training principle 审计字段。
- 历史 coach outcome 不作为独立长期记忆直接注入 Today prompt。它只有在被沉淀为已确认原则、verified lensFeedback、任务验证或其他可审计资产后，才可能通过对应策略进入上下文。

预算和污染防护：

- 当前事实和用户回答永远优先于历史原则。
- 历史原则只能作为 comparison lens，不能作为命令。
- lensFeedback 只使用与 final lens 相同的反馈，避免“上一个训练动作的成败”污染另一个思维动作。
- 如果模型没有收到某条历史反馈，质量门也不能用那条反馈惩罚输出；prompt context 和质量门必须使用同一个 memory selection。

### 9.2 三类上下文的区别

明思需要严格区分三类上下文：

| 类型 | 例子 | 用途 | 是否可改变模型判断 |
| --- | --- | --- | --- |
| Source Context | 当前 rawText、卡片、回答、任务、验证 | 作为本次输出的事实来源 | 可以，且优先级最高 |
| Reference Context | 历史原则、项目摘要、历史相似事件 | 作为对照和提醒 | 可以影响提问角度，但不能覆盖当前事实 |
| Profile / Trend Context | 成长指标、长期弱点、常见模式 | 作为周/月训练建议 | 不应进入日常事实拆解，避免贴标签 |

当前实现中：

- `sourceRecordIDs` 记录本次输出直接依赖的当前材料。
- `contextRecordIDs` 记录模型本次请求可见的上下文记录；MVP 代码中它目前包含当前 source ids 和被召回原则 ids 的集合。
- 审计 UI 展示时必须把 `sourceRecordIDs` 作为直接证据，把 `contextRecordIDs - sourceRecordIDs` 作为参考资产，避免用户误以为历史原则和当天事实是同一种证据。
- 未来必须继续把这两者分开，否则无法判断“AI 生成任务是基于今天输入，还是基于历史规则”。

目标实现：

- `sourceRecordIDs`：只放当前输出的事实来源，例如 daily entry、cards、answers、quest、verification。
- `contextRecordIDs`：只放参考性上下文，例如原则、项目摘要、历史相似记录、成长趋势。
- 如果某条记录同时是当前事实和参考材料，应在未来 `prompt_context_refs` 表中用 `refRole` 区分，而不是在数组里重复表达。

### 9.3 当前模型请求的真实形态

当前 GLM 请求不是把所有字段作为原生 JSON object 传入，而是由 `DirectGLMClient` 拼成 Chat Completion 消息：

```text
system:
  LocalPromptProvider.systemText(mode)

user:
  Prompt ID
  Prompt version
  Context version
  Output schema version

  Task:
    LocalPromptProvider.userText(promptId, mode)

  Input summary:
    DefaultContextAssembler.inputSummary(...)

  Payload:
    DefaultContextAssembler.payload + TodayAIService.extraPayload
```

当前 payload 是 `[String: String]`。这是 MVP 可接受实现，但不是长期形态。

长期必须升级为结构化 `PromptContextPayload: Codable`，原因：

- 方便服务端 ContextAssembler 接管。
- 方便 PromptRun 精准审计每个上下文字段。
- 方便对 Project、Growth、Principle、Lens 做 schema 迁移。
- 避免复杂对象被压成字符串后无法做差异比较和 eval。

## 10. 原则资产召回策略

### 10.1 PrincipleAsset 定义

原则资产不是金句，而是可执行行为规则。

结构应包含：

- `title`。
- `summary`。
- `triggerContext`。
- `actions`。
- `successCriteria`。
- `exceptions`。
- `sourceDailyEntryId`。
- `sourceCardIds / questIds`。
- `status`。
- `userFeedback`。

### 10.2 生命周期

```text
Candidate
-> User Confirmed
-> Active
-> Practiced / Challenged in future prompts
-> Verified Useful / Needs Review / Archived
```

规则：

- `extractPrinciple` 只能生成候选。
- 用户确认后才成为 active asset。
- 没有用户确认的候选原则不能进入后续 Prompt 上下文。
- 如果未来验证中发现原则不适用，应进入 needsReview 或 archived。

### 10.3 什么时候调用

不调用：

- `organizeCards`。

调用：

- `generateQuestions`：发现“我已经知道但没有执行”的盲点。
- `generateQuests`：把原则转成明日可验证行动。
- `extractPrinciple`：去重、合并、升级原则。
- `weeklyCalibration`：判断哪些原则被实践，哪些仍停留在认知层。
- `monthlyGrowth`：评估原则是否真的改变了用户行为。

### 10.4 MVP 检索算法

当前 `LocalPrincipleRetriever` 使用本地关键词规则：

- 只检索 `active` 原则。
- `organizeCards` 永远返回空。
- 从 rawText、透镜、卡片、回答、任务中抽取搜索词。
- 过滤低信号停用词。
- 原则标题和触发场景命中权重大于摘要命中。
- 至少达到最低分才进入上下文。
- 最多返回 3 条。

MVP 评分逻辑：

```text
score = highSignalMatch * 2 + fullTextMatch * 1
```

目标升级：

```text
score = semanticSimilarity
      + recentUsageBoost
      + verifiedSuccessBoost
      + userPinnedBoost
      - dismissedPenalty
      - staleOrInaccuratePenalty
```

后续可升级：

- Embedding 检索。
- 服务端 ContextAssembler。
- 用户主动选择要对照的原则。
- 原则包 / 思维框架包 marketplace。

### 10.5 原则召回决策树

原则资产什么时候进入上下文，必须按以下决策树处理：

```text
Is prompt organizeCards?
  yes -> never inject principles
  no ->
    Is principle.status active?
      no -> do not inject
      yes ->
        Is it user-confirmed?
          no -> do not inject
          yes ->
            Is it relevant to rawText/cards/questions/quests/lens?
              no -> do not inject
              yes ->
                Is the prompt allowed to use principles?
                  generateQuestions -> inject as comparison lens
                  generateQuests -> inject as action/criteria reference
                  extractPrinciple -> inject as dedupe/merge reference
                  weeklyCalibration -> inject as practiced/challenged principle
                  monthlyGrowth -> inject as long-term behavior evidence
                  verifyQuest -> MVP no, later only as calibration reference
```

召回必须满足：

- 最多 3 条。
- 每条必须有 id。
- 每条必须保留 `triggerContext`、`actions`、`successCriteria`、`exceptions`。
- 不传入未确认候选原则。
- 不传入被用户 archived 的原则。
- 不传入用户标记为不准确或不想再使用的原则。

### 10.6 原则使用方式

不同 Prompt 使用原则的方式不同：

| Prompt | 原则的作用 | 禁止行为 |
| --- | --- | --- |
| `generateQuestions` | 帮用户发现“知道但没做到”或“旧原则是否适用”的追问。 | 不能直接要求用户遵守旧原则。 |
| `generateQuests` | 把适用原则转成明日任务的完成标准或阻力提醒。 | 不能因为原则存在就生成和当天材料无关的任务。 |
| `extractPrinciple` | 与已有原则去重、合并或升级。 | 不能重复生成同义原则。 |
| `weeklyCalibration` | 判断原则有没有被实践、失败在哪里。 | 不能用原则库训话。 |
| `monthlyGrowth` | 评估原则是否转成稳定行为。 | 不能把原则数量当作成长。 |

原则资产应以“对照材料”的身份进入上下文，而不是以“命令”的身份进入上下文。

### 10.7 原则进入 Prompt 的边界话术

原则进入 Prompt 时必须携带类似边界：

```text
These are previously accepted principle assets.
Use them only as comparison lenses.
Do not force today's situation to fit them.
If a principle does not apply, say it does not apply.
```

AI 输出应说明：

- 哪条原则适用。
- 为什么适用。
- 哪些地方可能不适用。
- 用户如何验证。

### 10.8 原则资产的更新规则

经验总结不是一次生成后永久正确。它必须允许被验证和修订：

| 事件 | 状态变化 | 说明 |
| --- | --- | --- |
| AI 提取原则候选 | candidate only | 不能进入后续上下文。 |
| 用户保存原则 | active | 可进入相关 Prompt。 |
| 后续任务实践成功 | active + usage evidence | 增强召回权重。 |
| 后续任务失败且原因与原则有关 | needsReview | 后续 Prompt 可提示复审，不作为强规则。 |
| 用户认为不准确 | needsReview 或 archived | 降低或停止召回。 |
| 用户删除/归档 | archived | 不进入模型上下文。 |

MVP 当前模型只有 `active / needsReview / archived`，但产品语义上必须把“候选”和“已确认 active”分开处理。
进入 `needsReview` 的原则不能只显示负反馈次数；Growth 必须展示最近一次 `not_applicable` / `misrecalled` 反馈的召回理由和用户备注，让用户知道复审依据是什么。

### 10.9 多规则沉淀后的调用策略

当用户沉淀很多规则后，不能把规则库全量塞进每次请求。明思必须把规则分成 4 类，并按 Prompt 目的召回：

| 规则类型 | 例子 | 召回时机 | 是否进入日常 Prompt |
| --- | --- | --- | --- |
| 行为原则 | 会前先定义决策、负责人、验收标准 | 相似场景出现时 | 是，最多 3 条 |
| 判断准则 | 先看证据，再判断对方动机 | 用户做判断、归因、复盘时 | 是，作为追问对照 |
| 项目经验 | 某项目推进中常卡在跨部门确认 | 项目页、项目相关任务生成 | 后续进入 |
| 成长模式 | 用户常低估阻力、任务标准不清 | 周/月报告、训练建议 | 不进入 `organizeCards`，谨慎进入日常任务 |

召回策略必须遵循：

```text
先判断 Prompt 是否允许规则
-> 再判断规则状态是否 active
-> 再判断规则与当前材料是否相关
-> 再判断是否存在用户否认/不适用反馈
-> 最多选择 3 条
-> 作为 reference context 进入，不作为 system command
```

不同数量级下的策略：

| 规则数量 | 策略 |
| --- | --- |
| 0-10 条 | 本地关键词检索足够，重点展示可见性。 |
| 10-100 条 | 需要召回理由、最近实践权重、用户 pinned / dismissed 权重。 |
| 100+ 条 | 需要 embedding / hybrid retrieval，并按场景、项目、角色、透镜分层索引。 |

规则进入上下文时的格式必须保留：

```json
{
  "id": "principle-uuid",
  "title": "会前明确决策和负责人",
  "summary": "重要会议前先写清要确认什么、谁负责、什么算完成。",
  "triggerContext": "跨角色会议、容易返工的协作场景",
  "actions": ["写清决策", "确认负责人", "定义验收标准"],
  "successCriteria": "会后 action 有 owner 和 done 标准",
  "exceptions": "非决策型闲聊或低风险同步",
  "retrievalReason": "当前卡片包含会议未明确负责人",
  "usageBoundary": "仅作对照；如当前事实不匹配，应明确不适用。"
}
```

禁止把规则以以下形式进入上下文：

```text
用户有一条原则：会前明确负责人。请基于这条原则生成任务。
```

这种写法会让模型强行套规则。正确做法是：

```text
以下是用户确认过的历史原则，仅作对照。请先判断它是否适用于今天的事实；如果不适用，不要使用它。
```

### 10.10 规则资产与用户能力训练

规则召回的目标不是让 AI 显得记忆力强，而是训练用户把原则变成本能。

明思需要在后续报告中区分 3 种状态：

| 状态 | 含义 | 产品反馈 |
| --- | --- | --- |
| 已知未用 | 用户保存过规则，但相似场景中没有主动提到或实践。 | 轻提示“这条原则可能还没成为本能”。 |
| 有意识练习 | 用户在任务中刻意实践该规则。 | 记录为 principle practiced。 |
| 稳定内化 | 多次相似场景中用户主动使用，且验证结果较好。 | 周/月报告中标记为稳定能力。 |

判断规则：

- 不能因为用户没提到规则，就断言用户不会。
- 必须结合卡片、回答、任务、验证多次证据。
- 自动记录的练习证据必须写明本地匹配信号，例如命中的 action 或规则字段，并把 `matchSignal` 与 `attributionPolicyVersion` 结构化保存，便于后续复盘它为什么被归因为 practiced。
- 训练摘要需要保留最新练习证据摘要，让原则资产列表能展示最近一次实践归因，而不是只展示计数。
- 必须允许用户在看到最近一次实践归因的 Growth 原则资产行直接标记“这条归因不准确”。
- 被用户否认的归因必须保留为 disputed practice evidence 以支持审计和导出，并在 Growth 原则资产行继续显示为“已否认归因”；但它不能进入 active practice evidence 查询、训练摘要计数、最近练习摘要或长期画像强化。
- 如果后续验证再次命中同一原则的同一本地匹配信号，而该信号最近已被用户否认为误归因，系统不得自动生成新的 active practice evidence；判断时优先使用结构化 `matchSignal`，只对旧数据回退解析摘要文本，除非未来引入更强的结构化召回策略，能说明这次证据和上次被否认的信号不同。

这部分是明思区别于普通日记总结工具的核心：它不只保存经验，而是追踪经验是否真的改变了用户行为。

## 11. 经验总结与用户资产

明思沉淀的资产分三类：

| 资产 | 来源 | 用途 | 是否进入上下文 |
| --- | --- | --- | --- |
| ThinkingCard | 当天输入整理 | 事实证据、问题、任务、风险 | 当前闭环必须进入 |
| PrincipleAsset | 用户确认的经验总结 | 行为标准、反复训练 | 相关时进入 |
| ProjectLink / ProjectInsight | 多日议题沉淀 | 长期议题进展和思考变化 | 后续进入 |
| MetricContribution | 任务和验证归因 | 成长指标加减分证据 | 后续进入 |

原则资产和成长指标的关系：

- 原则资产回答“我以后遇到类似情况应该怎么做”。
- 成长指标回答“我有没有越来越能做到”。
- Prompt 不能只用原则教育用户，还要用验证结果校准原则是否真的有效。

### 11.1 经验总结的产品定义

明思里的“经验总结”不是普通笔记，也不是 AI 生成的一段总结文字。

它必须满足：

- 来自用户当天的真实输入、追问回答、任务选择或次日验证。
- 能解释“以后遇到类似情况我应该怎么做”。
- 能被拆成触发场景、行动步骤、成功标准、例外条件。
- 能在后续相似场景中被召回、挑战、实践或归档。
- 能回链到原始证据。

经验总结分 4 层：

| 层级 | 资产 | 例子 | 是否长期召回 |
| --- | --- | --- | --- |
| L1 事实记录 | ThinkingCard | “这次会议未明确负责人。” | 否，只作为证据回看。 |
| L2 当日结论 | ReflectionAnswer / Quest | “明天会前先列决策清单。” | 否，只影响当前闭环和历史。 |
| L3 行为原则 | PrincipleAsset | “跨角色会议前先写清决策、负责人、验收标准。” | 是，相关时召回。 |
| L4 能力模式 | Growth / MetricContribution | “清晰度提升来自更早定义完成标准。” | 是，但只在周/月报告和训练建议中召回。 |

只有 L3 及以上才是“可复用资产”。

### 11.2 从输入到原则资产的转换链路

转换链路：

```text
RawText
-> ThinkingCards
-> User confirms / excludes / edits
-> Lens questions
-> User answers
-> Quest
-> Principle candidate
-> User confirms
-> Active PrincipleAsset
-> Future retrieval
-> Verification feedback
-> NeedsReview / Active / Archived
```

每一步都必须保留用户控制权：

- 卡片必须可确认、排除、编辑。
- 追问答案由用户写，AI 不能代填。
- 任务必须可编辑。
- 原则候选必须用户保存后才 active。
- 后续召回原则时，用户应能看见“参考了哪条原则”。

### 11.3 规则资产与项目的关系

项目回答“这件长期事情现在进展如何”。

原则回答“我以后遇到类似情境应该怎么做”。

同一条输入可以同时产生项目证据和原则资产：

```text
输入：会议没有确认负责人，导致后续返工。

ProjectLink:
  项目 A 的协作阻塞证据。

PrincipleAsset:
  跨角色会议前先写清决策、负责人、验收标准。
```

后续 Prompt 召回时：

- 任务生成可以参考原则，但不能自动绑定项目。
- 项目洞察可以参考原则是否被实践。
- 月度成长可以参考原则是否从“知道”变成“稳定做到”。

### 11.4 规则资产与成长指标的关系

成长指标不是模型给用户打分，而是对“训练证据”的归因。

例子：

```text
PrincipleAsset:
  会前先定义要确认的决策。

Quest:
  明天会前写出决策清单并发会后确认。

Verification:
  完成，高价值。

MetricContribution:
  clarity +0.20，因为完成标准提前明确。
  executionReliability +0.10，因为任务被按标准完成。
```

如果任务未完成：

```text
Verification:
  未完成，低价值或被中断。

MetricContribution:
  calibration -0.10，因为低估阻力。
  PrincipleAsset may need review if repeated.
```

规则：

- 指标变化必须有 source id。
- 指标变化必须能跳回历史证据。
- 正负贡献可以同时存在。
- 用户可以标记归因不准确。
- 被用户否认的归因不能继续影响后续长期画像，但需要留在审计层，供用户和后续框架判断“系统曾经如何误归因”。

### 11.5 “AI 帮我对照自己资产”的使用点

当用户沉淀了足够多原则后，明思可以做一个关键能力：对比“用户自己是否已经本能使用了自己的原则”。

触发时机：

- `generateQuestions`：今天材料和某条原则相关，但用户没有主动提到它。
- `generateQuests`：任务可以实践某条原则，但用户选择的动作没有覆盖成功标准。
- `weeklyCalibration`：一周内反复出现相同原则的触发场景。
- `monthlyGrowth`：原则被多次实践或多次遗漏。

输出方式：

```text
你已经保存过一条原则：跨角色会议前先写清决策、负责人、验收标准。
今天的输入符合触发场景，但你的原始复盘没有提到“验收标准”。
这可能说明它还没有成为本能动作。
明天的任务可以只训练这一点：会前写出验收标准。
```

边界：

- 只能说“可能说明”，不能说“你就是缺乏某能力”。
- 必须允许用户否认。
- 必须展示证据和来源。
- 不能把用户没有提到某原则自动判为缺陷。

### 11.6 本次参考原则的可见化

原则资产一旦进入 `generateQuestions` 或 `generateQuests` 的上下文，UI 必须在对应步骤展示“本次参考的原则”。

产品目的：

- 让用户知道 AI 的追问或任务建议不是凭空生成。
- 让用户检查旧原则是否被错误套用。
- 让未来的 PromptRun 审计、原则反馈和服务端召回理由有可见入口。

展示规则：

- 只展示本次请求实际召回的 active 原则。
- 最多展示 3 条。
- 文案必须明确“仅作对照”，不能暗示用户必须遵守。
- 当用户退回到更早步骤并修改卡片、透镜或回答时，必须清空旧的参考原则，等待重新生成。
- 当没有相关原则时，不显示空卡片，避免制造虚假权威感。

当前实现：

- `AppStore.referencedPrinciples` 保存当前步骤的可见参考原则。
- `generateQuestions` 和 `generateQuests` 使用 `PrincipleRepository.activePrinciples()` 作为历史原则上下文，不只依赖当天原则候选。
- `LocalPrincipleRetriever` 同时服务模型上下文和 UI 展示，保证“模型看到的原则”和“用户看到的原则”一致。
- `PromptRun.contextRecordIds` 记录被召回原则 id，后续可用来补充召回理由和用户反馈。
- Today 引用原则卡会展示每条原则的 `retrievalReason` 作为“召回依据”，用户在点“不适用”或“误召回”前可以先看到本地召回命中的理由。
- `RetrievedPrinciple`、`PromptContextPayload.PrincipleContext` 和 `PrincipleRecallFeedback` 会同时保存机器可读的 `retrievalSignal`，用于说明这次召回命中的稳定本地信号，例如 `meeting ownership`。
- Today 的“不适用”或“误召回”会关联同一日、同一 Prompt 的最近 `PromptRun`，把 `promptRunId` 和 `retrievalSignal` 写入 `PrincipleRecallFeedback`，并将该 PromptRun 标记为 `denied`，让 Prompt Asset 用户否认率来自真实召回纠正事件。
- `LocalPrincipleRetriever.policyVersion` 为 `principle-retrieval.local-keyword-feedback.v3`：负向反馈带有非空 `retrievalSignal` 时，只惩罚同一原则下匹配该 signal 的后续召回；旧反馈行如果没有 signal，保留原则级惩罚作为兼容回退。
- Today 的引用原则反馈提供可选备注输入，备注随 `PrincipleRecallFeedback.note` 持久化和导出，让后续原则修复能看到用户为什么否认该 signal。
- Today 的引用原则卡和 Growth 的 needsReview 复审审计会把结构化 `retrievalSignal` 本地化展示为用户可读的“命中信号”，例如 `meeting ownership` 显示为“命中会议负责人”，避免用户只能阅读调试字符串。
- Growth 原则训练摘要会展示最新负向召回反馈作为“复审依据”，并包含同一条用户可读命中信号，避免 needsReview 状态变成不可解释的后台计数。
- ReviewQuests 的任务卡会基于现有 active principles 和任务文本做本地匹配，展示“训练原则”和命中的本地 action / criteria 信号，让用户在保存任务前看到这条任务预计训练哪条原则。这个提示只读、不提前写入 `PrinciplePracticeEvidence`，真正的训练证据仍等次日验证后产生。
- 用户可以在 ReviewQuests 中把某个任务的预期训练原则从“自动判断”手动校准为某条 active principle；这个选择存入 `Quest.trainingPrincipleId`，通过现有 `QuestRow.rawPayloadJson` 持久化，不新增表结构迁移。
- 次日验证归因时，如果 `trainingPrincipleId` 仍指向 active principle，系统只为该原则写入 verification-backed practice evidence，并把 `matchSignal` 记录为“用户选择”；如果选择已失效或为空，再回退到本地文本匹配。needsReview 原则不能作为手动训练目标。
- `verifyQuest` Prompt Asset `1.6.0` 会收到同一条 expected training principle 上下文，并要求模型返回单独的 `expected_principle_practice_assessment` 审计字段，用于解释“预期原则是否真的被练到”；它不能直接创建或确认 `PrinciplePracticeEvidence`，证据写入仍由本地 AppStore 归因策略负责。

后续升级：

- 可以继续增加更细的选择解释和撤销审计，例如记录“为什么用户把自动目标改成另一条原则”，但不应在任务保存当天提前生成 practice evidence。

## 12. 反信息茧房设计

风险：

- 用户越用越只听到自己想听的话。
- 历史原则变成固定偏见。
- AI 把过往失败模式贴成用户标签。
- 透镜总是推荐用户最熟悉的视角。

约束：

- Deep 模式至少包含一个反方问题。
- 如果 PrincipleAsset 和当前事实冲突，AI 必须允许“旧原则不适用”。
- Growth 必须展示正向和负向贡献。
- Lens 不应永久自动固定为用户最常用的透镜。
- 月报应提示一个“可能被忽视的外部视角”。
- 用户必须能否认 AI 的归因，并把反馈记录为后续上下文。

### 12.1 反信息茧房 Prompt 规则

每类 Prompt 必须有不同的反茧房机制：

| Prompt | 反茧房机制 |
| --- | --- |
| `organizeCards` | 只拆事实和用户表达，不引入历史判断。 |
| `generateQuestions` | 至少一个问题挑战隐藏假设；Deep 模式必须包含反方或验证问题。 |
| `generateQuests` | 输出 `rejected_low_value_tasks`，说明哪些看似忙碌但低价值。 |
| `verifyQuest` | 区分任务设计问题和执行问题，不把失败归因为人格。 |
| `extractPrinciple` | 如果只是一次性情绪或泛泛口号，返回 null。 |
| `weeklyCalibration` | 同时展示有效动作和重复阻碍。 |
| `monthlyGrowth` | 同时展示正负贡献和可能被忽视的外部视角。 |

### 12.2 用户反馈如何进入后续上下文

用户对 AI 的反馈本身也是上下文工程的一部分。

后续需要记录：

- 这条原则不适用。
- 这个任务不是真正高价值。
- 这个成长归因不准确。
- 这个项目合并建议错误。
- 这个透镜今天没有帮助。

召回时必须处理：

```text
accepted feedback -> increase future confidence
inaccurate feedback -> suppress similar inference
dismissed feedback -> do not use as evidence
needsReview -> can mention as uncertain, not as rule
```

MVP 当前只在部分数据结构上预留反馈字段。后续必须把反馈纳入 PrincipleRetriever 和 ContextAssembler，而不是只做 UI 记录。

## 13. Prompt Run 审计

每次 PromptRun 必须记录：

- `promptId`。
- `promptVersion`。
- `inputSchemaVersion`。
- `outputSchemaVersion`。
- `contextVersion`。
- `modelProvider`。
- `modelName`。
- `sourceRecordIds`。
- `contextRecordIds`。
- `requestSummary`。
- `responseJSON` 或 `error`。

审计目标：

- 用户能知道某个建议来自哪些卡片、任务或原则。
- AI 调用失败后可以补跑。
- Prompt 版本升级后可以判断结果差异。
- 后续可以做 Prompt Eval 和回归测试。

当前实现：

- `LLMRequest.contextVersion` 已存在。
- `LLMRequest.contextRecordIDs` 已存在。
- `PromptTracingLLMClient` 已记录 PromptRun。
- `PromptRun.sourceRecordIds` 和 `PromptRun.contextRecordIds` 已独立记录。
- `prompt_runs.context_record_ids_json` 已通过 v7 migration 增加，旧记录用原 `source_record_ids_json` 回填以保持可审计性。

后续改造：

- 增加独立 `prompt_context_refs` 表，记录 source/context ref 类型和召回理由。
- 增加 `retrieval_reason`。
- 增加用户反馈字段：准确、不准确、部分准确。
- UI 已在追问和任务阶段展示“本次参考的原则”；后续需补召回理由和用户反馈。

## 14. 数据结构演进

当前：

```swift
struct LLMRequest {
    let prompt: PromptTemplate
    let inputSummary: String
    let jsonPayload: [String: String]
    var sourceRecordIDs: [String]
    var contextVersion: Int
    var contextRecordIDs: [String]
}
```

问题：

- `[String: String]` 会把结构化对象压平成字符串。
- 不利于 schema 迁移。
- 不利于审计。
- 不利于服务端 PromptProvider 和 ContextAssembler。

目标：

```swift
struct PromptContextPayload: Codable {
    var currentInput: CurrentInputContext
    var lens: LensContext?
    var cards: [CardContext]
    var answers: [AnswerContext]
    var principles: [PrincipleContext]
    var existingPrinciples: [PrincipleContext]
    var projects: [ProjectContext]
    var growth: GrowthContext?
    var privacy: PrivacyContext
}
```

迁移原则：

- 数据库保留原始记录，不因 UI 或 Prompt 变化丢失。
- Prompt 输入结构按版本迁移。
- 老版本 PromptRun 可继续审计。
- 服务端迁移只替换 Provider，不重写业务状态机。

## 15. 服务端迁移预留

MVP 使用本地 `LocalPromptProvider` 和本地 `DefaultContextAssembler`。

后续迁移方向：

```text
LocalPromptProvider
-> RemotePromptProvider

LocalPrincipleRetriever
-> Remote / Hybrid Retriever

DefaultContextAssembler
-> Versioned ContextAssembler
```

服务端迁移后，App 仍应负责：

- 用户本地数据存储。
- BYOK 或服务端 token 的配置。
- 用户确认、排除、编辑。
- 本地 PromptRun / ContextRun 审计。
- 离线 fallback。

服务端可负责：

- Prompt 版本发布。
- 透镜包和规则包管理。
- Embedding 检索。
- Prompt Eval。
- 灰度和回滚。

禁止：

- 把 UI 逻辑写进 Prompt。
- 把业务状态机写进服务端 Prompt。
- 让模型返回任意 schema 直接驱动核心状态。

### 15.1 服务端迁移接口契约

后续迁移到服务端时，App 不应把 Prompt 文案、透镜包、规则包都写死在客户端，但 App 必须保留状态机和数据所有权。

目标接口：

```text
GET /prompt-templates/{promptId}?mode=standard&version=latest
POST /context/assemble
POST /llm/complete
POST /prompt-runs
GET /lens-packs
GET /principle-packs
```

迁移顺序：

1. `RemotePromptProvider`：只远程拉取 PromptTemplate，ContextAssembler 仍在本地。
2. `RemoteLensProvider`：远程下发透镜定义，但用户选择和本地状态不变。
3. `HybridPrincipleRetriever`：本地原则 + 服务端 embedding 检索，返回召回理由。
4. `RemoteContextAssembler`：服务端组装上下文，但 App 仍记录 PromptRun 和 source ids。
5. `RemoteEval`：Prompt 版本升级前跑离线 eval。

不可迁移到服务端的职责：

- 用户是否确认卡片。
- 用户是否保存原则。
- 用户是否否认某个归因。
- 本地敏感卡片是否排除出模型上下文。
- 每日闭环状态机。

### 15.2 Prompt / 透镜 / 规则包版本策略

每个可远程更新的“算法资产”都必须有版本。

```json
{
  "assetType": "prompt_template | lens | principle_pack | context_policy",
  "id": "string",
  "version": "semver",
  "minAppVersion": "string",
  "schemaVersion": 1,
  "status": "draft | active | deprecated | rolled_back",
  "createdAt": "iso8601",
  "changelog": "string"
}
```

兼容规则：

- App 可以继续执行旧 PromptRun 的审计。
- Parser 不支持的新 schema 不能自动上线。
- 远程 Prompt 必须声明 outputSchemaVersion。
- 远程 Lens 不能要求 App 不存在的 UI 或状态字段。
- 规则包只影响候选召回和提问，不得直接改写用户本地资产。

## 16. Prompt Eval

每个 Prompt 至少有固定 eval cases。

### 16.1 Cards Eval

输入：

- 混乱语音文本。
- 包含敏感项目名的文本。
- 只有情绪没有事实的文本。

检查：

- 是否拆出事实、问题、任务。
- 是否标记敏感。
- 是否避免长文章总结。

### 16.2 Questions Eval

输入：

- confirmedCards + selectedLens。

检查：

- 问题是否具体。
- 是否符合透镜。
- 是否挑战假设。
- 是否没有替用户回答。

### 16.3 Quests Eval

检查：

- 是否只有一个 main quest。
- completionCriteria 是否可验证。
- expectedResistance 是否具体。
- 是否来自用户材料。
- 是否允许用户重试或编辑。

### 16.4 Principle Eval

检查：

- 是否可复用。
- 是否包含触发场景、行动、成功标准、例外。
- 是否避免泛泛口号。
- 是否能和已有原则去重。

### 16.5 Growth Eval

检查：

- 每个 delta 是否有 source id。
- 是否展示负向贡献。
- 是否避免人格标签。
- nextTrainingFocus 是否可执行。

## 17. MVP 验收标准

Prompt 与上下文工程的 MVP 验收标准：

- 每个 Today Prompt 的输入、输出、调用时机、上下文来源清楚。
- `organizeCards` 不注入原则资产。
- `generateQuestions` 和 `generateQuests` 可注入最多 3 条相关 active 原则。
- `extractPrinciple` 能拿到 existingPrinciples，避免重复原则。
- `verifyQuest` 能把验证结果回链到原任务证据。
- PromptRun 记录 prompt version、schema version、模型、source ids、错误或响应。
- AI 调用失败后用户能重试或后续补跑。
- 敏感卡片可以排除出模型上下文。
- 用户确认前的原则候选不能进入后续上下文。
- 文档和代码都保持模块边界：`PromptProvider`、`ContextAssembler`、`PrincipleRetriever`、`LLMClient`。

## 18. 当前优先级缺口

已完成的 MVP 基础：

- `LLMRequest.contextPayload` 已支持结构化 `PromptContextPayload: Codable`。
- `DirectGLMClient` 优先使用结构化 JSON 上下文，保留 legacy `[String: String]` 渲染作为兼容层。
- `organizeCards` 不注入原则资产；`generateQuestions` / `generateQuests` 注入最多 3 条相关 active 原则。
- `extractPrinciple` 注入显式 `existingPrinciples` 去重上下文，并把相关原则 ID 记入 `contextRecordIDs`。
- `verifyQuest` 已用结构化上下文记录任务验证输入，并能接收该任务预计训练的 active principle 标题、id 和匹配信号。
- Project prompt 输出已有严格解析基础：Project link suggestion、Project candidate、Project insight、Project merge candidate 缺少 source id、source refs、before/after 或合法 project id 时会被拒绝或过滤。

P0：

- 将 Project prompt parser 接入 AI use case 和用户确认 UI；Growth 已有 contribution validator，仍需周/月报告级 schema。
- 将 Settings 里的 PromptRun 审计入口升级为完整 ContextRun 详情，补齐 source/context 明细、召回理由、用户反馈和补跑结果。
- 将结构化上下文扩展到 typed Project/Growth context，并补齐 ContextRun 引用明细。

P1：

- 支持任务、原则候选、卡片的编辑。
- 增加 PromptRun 的补跑入口。
- 为原则召回增加“召回理由 / 不适用 / 误召回”反馈字段。
- 补齐 Project / Growth 上下文进入策略的实现，而不只是文档矩阵。

P2：

- 服务端 PromptProvider。
- Embedding PrincipleRetriever。
- 透镜包 / 原则包 marketplace。

## 19. Open Questions

- MVP 是否要在问题或任务卡片上展示“引用原则”标签？
- 用户是否可以在生成任务前手动选择要对照的原则？
- PrincipleAsset 是否需要“练习中 / 已内化 / 需复审 / 已归档”四态？
- Deep 模式是否默认注入最近失败模式？
- 月报是否应该自动生成下一月训练计划？
- 用户自定义透镜是否放在 Settings，还是放在 Growth / Principle Library 中？

## 20. 当前代码实现索引

本 PRD 对应的当前实现位置：

| 能力 | 文件 | 当前状态 |
| --- | --- | --- |
| Prompt 类型 | `Sources/Services/CoreProtocols.swift` / `PromptID` | 已实现 Today 核心 PromptID，周/月预留。 |
| Prompt 模板 | `Sources/Services/CoreProtocols.swift` / `LocalPromptProvider` | 本地 Swift 字符串，含 system role、mode guidance、JSON schema。 |
| Today AI 编排 | `Sources/Services/TodayAIService.swift` | 已通过 `PromptProvider`、`ContextAssembler`、`LLMClient` 编排，不直接在 View 拼 Prompt。 |
| 上下文组装 | `Sources/Services/TodayAIService.swift` / `DefaultContextAssembler` | 已按 PromptID 组装 rawText、cards、answers、quests、principles。 |
| 原则召回 | `Sources/Services/TodayAIService.swift` / `LocalPrincipleRetriever` | 已支持 active 原则关键词召回、停用词过滤、最多 3 条、`organizeCards` 禁用。 |
| GLM 请求 | `Sources/Services/DirectGLMClient.swift` | OpenAI-compatible Chat Completion；支持 `response_format` 失败后降级重试。 |
| JSON 解析 | `Sources/Services/TodayAIResponseParser.swift` | 已解析 cards/questions/quests/principles/verification/growth contributions。 |
| Prompt 审计 | `Sources/Services/CoreProtocols.swift` / `PromptTracingLLMClient` | 已记录 prompt、schema、model、source ids、context ids、response/error。 |
| PromptRun 存储 | `Sources/Services/PersistenceCore.swift` / `SQLitePromptRunRepository` | 已持久化 prompt_runs，并支持 unresolved failure 恢复。 |
| PromptRun 审计入口 | `Sources/App/AppStore.swift` + `Sources/Features/FeatureTabs.swift` | Settings 已展示最近 PromptRun、成功/失败、模型、source/reference 数量和错误摘要。 |
| UI 参考原则 | `Sources/App/AppStore.swift` + `Sources/Features/Today/TodayView.swift` | 追问和任务阶段已展示本次参考原则。 |
| Eval 基线 | `Tests/Services/PromptEvalFixtureTests.swift`、`TodayAIServiceContextTests.swift` | 已覆盖 prompt 输出结构和原则上下文注入规则。 |

## 21. 算法资产路线图

明思后续真正要沉淀的不是单条 Prompt，而是一组可版本化、可测试、可迁移的算法资产。

### 21.1 Prompt Asset

Prompt Asset 包含：

- `promptId`。
- `promptVersion`。
- `systemPolicyVersion`。
- `contextPolicyVersion`。
- `outputSchemaVersion`。
- `evalSuiteVersion`。
- `rollbackTargetVersion`。

验收要求：

- 每次 Prompt 修改必须能跑固定 eval。
- 每个生产 PromptRun 必须记录版本。
- Parser 不支持的新 schema 不能上线。
- 失败率、空结果率、用户否认率必须能被统计；用户否认率不应只靠手工审计更新，真实的原则召回“不适用 / 误召回”反馈也必须回写到关联 PromptRun。

### 21.2 Lens Asset

Lens Asset 包含：

- 透镜目的。
- 问题生成策略。
- 任务选择规则。
- 反偏见规则。
- 适用场景。
- 禁用场景。
- UI 展示 metadata。

当前 MVP 的透镜是枚举，后续要迁移为版本化对象。迁移后 UI 可以换卡片形态、角色卡视觉、动态 schema 展示，但 Today 状态机不应该重写。

### 21.3 Principle Retrieval Policy

Principle Retrieval Policy 决定“规则什么时候进入上下文”。

必须版本化的内容：

- 允许召回的 Prompt 列表。
- 每个 Prompt 的召回上限。
- active / needsReview / archived 的使用规则。
- 关键词、embedding、用户反馈的权重。
- 结构化 `retrievalSignal` 的生成规则。
- 不适用和误召回反馈的惩罚规则。
- 空 `retrievalSignal` 的旧数据兼容回退规则。

目标不是多召回，而是少而准：

- 相关才召回。
- 召回必须可解释。
- 用户能否认。
- 否认会影响以后。

### 21.4 Context Policy

Context Policy 决定每次请求的上下文层级和预算。

必须回答：

- 当前材料是否完整。
- 哪些卡片被用户排除出模型上下文。
- 哪些历史资产可以进入。
- 哪些长期画像不应该进入。
- 如果预算不足，先丢弃什么。
- 如果历史资产和当前事实冲突，谁优先。

### 21.5 Eval Asset

Eval Asset 是验证 Prompt 是否仍然服务产品目标的测试集。

至少包含：

- 语音转文字混乱输入。
- 带敏感公司信息的输入。
- 用户只有情绪没有事实的输入。
- 会议准备和行动闭环案例。
- 原则重复沉淀案例。
- 错误召回历史原则案例。
- 低价值任务被包装成主任务案例。
- Growth 正负贡献并存案例。

通过标准不是“模型回答好看”，而是：

- 是否具体。
- 是否基于证据。
- 是否能让用户继续思考。
- 是否保留用户选择权。
- 是否可追溯。
- 是否避免把用户困在旧模式里。

## 22. 下一轮对齐事项

当前 Prompt / Context PRD 已经能支撑 MVP，但在正式继续扩展前还需要做三件事：

1. 把 `[String: String]` payload 升级为结构化 `PromptContextPayload` 设计文档和迁移任务。
2. 为自定义透镜、角色卡、思维框架包设计 Lens Asset schema。
3. 为 PrincipleAsset 增加“召回理由 / 不适用反馈 / 实践证据”数据结构，避免规则资产只沉淀不训练。
