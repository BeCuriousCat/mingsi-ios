# 明思 Prompt Specification

> 2026-10-22 传输补充：导师回应／理解整理的 JSON 合同与 Prompt 版本不变，通过 SSE 解码正文预览；预览不视为完整或已保存结果。必须收到协议完成标记并经既有解析／来源／质量检查后提交。生产流式请求共享 600 秒无内容截止，持续内容续期，一次 HTTP 无自动重发。见[执行合同](mingsi-mentor-m1-system-design.md#9-请求执行与审计)及[验收边界](qa/2026-10-22-mentor-streaming/README.md)。

## 透镜的能力目标与适用边界（2026-10-21）

目录 builtin.v3 保留原有六种视角，新增 opportunity_cost、reversible_decision、perspective_taking、control_boundary，对应机会成本、可逆决策、换位理解、可控边界。方法的目的、一次思考动作、适用与禁用条件随 lensCatalog 进入请求，不能凭关键词、目录序号或用户选了视角就诊断能力缺陷。十种方法的选择与不单列的候选见[透镜设计](lens-library-design.md)。

`generateQuestions` 1.31.0 / schema 7 保留 1.30.0 回退；主动检查推断/比较取舍属于自愿思考，不因为用户说“帮我看看”就一律空数组。当前和后续轮都允许零或一个有用且可回答的问题；判断是否冗余与检查问题是否合格分开。方法资产只提供一个可选动作，未知保留未知，行为空结果仍有效。`diagnoseTrainingCase` 1.3.0 / schema 2 使用完整新目录、回退 1.2.0 冻结目录。新透镜复用现有 reasoning move，持久化 id 和历史响应可读。练习完成不证明能力提高，变化需要具体判断与证据，不显示能力分数。

## 行动建议的清晰度与未知结果（2026-10-18）

`generateQuests` 当前为 **1.12.0 / schema 3**，直接回退至 1.11.0，1.11.0 和 1.10.0 原文继续用于回放。当前文本独立组织各字段职责，不再追加修正指令或要求使用“我现在相信 X”替用户表态：title 只写一步，calibration_target 写具体、暂定的可观察命题，why_it_matters 保留解释边界，completion_criteria 写观察标准，reflection_question 写结果支持、减弱或仍未知的方向。上游原句的事实、不确定性和用户权限不能因改写而加强；“证据不足以证明改善”应保留在解释边界，不能作为正反方向容易混淆的目标。具体失败/否定预测仍合法。

自然重试、只对照已有记录和不追加任务是行动范围；没有机会、缺少记录和条件不可比可以维持未知。字段长度仅有软建议，不能靠本地截断、删掉关键限制或自动重发模型请求达到字数。历史自评、AI 问题、建议和讨论次数仍不证明行为或能力。无来源/拒绝行动时不编造任务；当前运行时只接纳显式 `main_quest: null`、`side_quests: []`、`observation_quest: null` 作为不安排行动的正常结果，进入可保存或返回复盘的 `reviewWithoutAction`。缺字段、损坏行动和额外侧任务不作为停下信号；历史默认解析保持旧行为。该状态不生成原则、提醒或成长贡献；已有确认行动和结果保留。实现与验证见 [无行动回顾](qa/2026-10-20-no-action/README.md)。

行动确认页只呈现一次目标判断，默认保留行动、完成证据和校准问题；填写检查移入“练习设置（可选）”，并明确只是是否填写。说明不再要求明天必须产出证据或证明因果，缺少阻力不再临时布置一个填写任务。实际验证及未完成项见[行动清晰度报告](qa/2026-10-18-action-clarity/README.md)。

## 历史讨论主题与当前指导（2026-10-18）

旧 coachPatternSummary 把原文和 AI 输出拼合后强制给出本地能力缺口；现停用生成并在全部生产 Prompt 上下文剔除，即使调用者传入旧摘要也不注入正文、训练指令或来源 ID。旧 Codable 类型仍保留用于历史回放，不改写原始记录。generateQuests 1.11.0 明确这一来源边界，完整保留 1.10.0。

成长“复盘中讨论过”只索引最近 14 条已完成记录中实际保存、已回答、有具体问题标签且回链同事项确认卡片的问题。跨两条日记录的同类问题提供展开对照和各自来源；同日记录同主题取一个问题，相同记录/问题不重复计数。此索引不自动传给模型，不代表共同原因、当前仍有缺口、行为实践或能力。不完整旧来源不补造，仍可在历史回看。完整验证以[主题回看报告](qa/2026-10-18-reflection-topics/README.md)的实际执行记录为准。

## 成长报告前的事实边界（2026-10-18）

停止在旧兼容路径按完成/价值自评、非空完成标准和回答次数生成本地成长分数。三次完整记录仅为报告请求数量门槛，不证明语义证据充分；不足时服务返回无分数/无贡献状态，不调用模型或布置补练习。旧本地作者固定摘要签名识别出的汇总不再用于 `previousSnapshot` 数值基线，历史存储不改写；其余未知来源不推断为模型审核通过。本轮未变更 weeklyCalibration/monthlyGrowth 的 Prompt 文本或版本，没有因此重发已验收语义样本。

## 单次指导行为证据（2026-10-18）

`evaluateGuidanceEvidence` 当前为 1.1.0 / schema 2，保留 1.0.0 原文回放及回退。请求包含原提示、行动计划、待检验判断、本次结果原文、明确标为自报的完成/价值/判断选择，以及已保存的 calibrationAssessment。计划不证明行为发生，结果评估也不证明提示被使用。

supports 要求原文明确报告相关行为；counterexample 要求明确没做或本次描述直接违背提示。好结果、选择、缺少描述、记不清或未有结果均不能替代行为证据；不知道应为 insufficient。前两类必须附一至三段唯一、非空、连续原文 `evidence_quotes` 并保留否定，insufficient 使用空数组；服务也兼容其缺省空引用，拒绝非空引用。理由只解释本次报告，不推断能力、退步、因果或掌握，不布置补练习。

客户端验证提示身份、结果来源和引文字面归属；这不能证明语义正确。当前可选归属只处理已保存、来源匹配且有可核对观察评估的结果，旧 nil、缺少结果和冲突结果跳过。次数不会自动生成 mastered。详细执行结果及边界见[指导证据报告](qa/2026-10-18-guidance-evidence/README.md)。

## 结果输入的中性边界（2026-10-18）

结果页先收集观察，再询问用户自评；未知、反例和冲突不被排除。`judgmentUpdate` 新增合法用户值 `unresolved`（暂不能判断），与已有 confirmed/adjusted/rejected 一同持久化，不等于模型的 calibration_assessment.judgment_status。当前 verifyQuest 1.10.0 已要求自评与实际结果分开，不因新增这个输入选项改写或重发既有语义样本。保存编排新增请求归属和防重复保护；存储重试复用已生成结果，模型回顾取消后保留输入。模型完成/协议通过仍不等于判断或方法有效，详见后续实际验收报告。

## Today 材料直达路径（2026-10-14）

`generateQuestions` 当前线上版本为 `1.31.0`，保留 `1.30.0` 原文作为回退，更早版本用于回放。`userChoice.selectedLens=null` 是合法用户选择：透镜是可选视角，不是进入今日复盘的门槛。当前请求仍只把确认卡片和最新回答当作证据；没有透镜时，模型直接判断材料是否真的需要一个问题，不能自行补选训练焦点。若问题不能改变判断、选择、证据检查或可观察信号，返回空问题集。

## 导师思考引导与最低有用性（2026-10-16）

`mentorRespond` 当前为 2.17.0（`mentor.system.2.17.0`、`mentor.m1.2.17.0`）；`mentorDraftUnderstanding` 当前仍为 2.6.0。两者的 context policy 与 JSON schema 保持 1.0.0。回应模板是一份独立的当前合同，集中定义帮助路由、证据边界、材料问题分类和输出协议；2.16.0 及更早版本仍可按原文回放，2.17.0 回退目标为 2.16.0。当前 Prompt 不把 2.1–2.6 的增量段落全部叠加到线上输入。真实 GLM-5.3 回看输出曾在正文和 question 各问一个不同问题，因此 2.8.0 明确正文只用陈述句、唯一问题归入 question，且补材料只选一个观察角度。2.9.0 进一步禁止从并列事项推断因果或价值高低，澄清只问一个凭已有经历能回答的短问题，不夹带外部调查任务。2.10.0 将 clarify 正文收敛为最多两句已有事实和一个缺口，禁止没有问号的候选问题、回想提示或提前教学；建议不得顺带规定用户未请求的其他管理方式。2.11.0 在系统层明确：材料不足时，确认事实和一个缺口本身就是有效帮助，采用 clarify；选取片段、询问原因、过程和结果属于 material，不得改标 reflection 绕过预算。2.12.0 将这些规则合并为独立合同，并加入并列事项、单个参与者的边界示例；不以历史增量叠加构造当前输入。一般教学须说明适用条件，不能把一种设计取向当成通则。

2.13.0 / schema 1 保留 2.12.0 原文回退。首页导师按用户已经表达的目标、标准和限制给出偏向；缺少决定性标准时只比较一个条件式取舍，不从“帮我选”补造收入、效率、休息或关系的优先级。价值偏好是选择标准，不是需要证明的事实缺口；不愿补问时仍可直接理解已知取舍。一般原则/条件示例不要求个人经历；用户自我标签和动机解释不升级为事实。用户补充或改变优先级后，明确按新标准更新建议，依据充分时保持具体，不回避为“两种都有好处”。不把满意、采纳或完成练习视作能力提升证据。无新增响应字段、关键词路由、数据库迁移或强制行动。


有材料且用户需要理解、比较、建议或纠正时，回应必须引用当前用户来源，并完成一个最小思考动作：辨认一个事实与解释、目标与手段、真实取舍、关键假设或可观察信号。首轮及后续每轮都不一次列出所有可能的解释、建议、反方观点或后续步骤；先完成当前最高价值的一步。多轮保持同一条思考线；若用户回答上一问并提出新请求，先指出新事实改变了什么，再回答新请求。与旧判断冲突时明确更新。用户明确要建议时给出一个有条件的首选及依据、限制；要求找漏洞时指出一个关键薄弱处。问题是可选的，答案必须实质改变下一步帮助，且只能放在 `question` 字段。

第二个可见回合后的默认收束不是硬上限：普通交流通常在回答完当前诉求后收束，但用户明确要求继续或新证据改变判断时可以继续。回看首轮入口不占两轮补材料预算；只有 `initial_entry=review`、`allows_material_question=true`、`material_question_count < 2` 且材料仍不足、用户未拒绝或表示想不起来时才继续补问。该预算只限制补材料问题数，不限制整个对话轮数。用户疲惫、想倾听、直接要讲解或想结束时，不强行训练、分析或追问。无材料回看首轮必须给具体、低负担的回忆入口；`suggested_actions` 最多两项。理解草稿仍只合并有效用户表达，不把教师意见变成用户的认可或承诺。

多轮中如果 `latest_user_source_ref` 存在，它代表当前唯一的用户诉求锚点；非收束回应必须引用该来源，不能用旧轮仍有效的用户来源替代当前表达。只有没有本轮锚点的显式 UI 动作，才可引用其他仍有效的用户来源。

导师 live 验收严格执行协议、最新来源、意图、材料预算和生产质量门；保留完整合成请求快照、模型配置和原始响应。词项检查只能生成待复核信号，不能裁决语义是否合格：例如“结论需要撤回”“我在这里”可能被固定词表误判，而没有问号的回想提示可能被格式检查漏过。九个场景的全部原文须另外逐项复核，并如实记录审核身份、证据及限制；自动执行通过后，Alpha 结果仍标记 `semantic_review_required`。

运行时由 `MentorResponseQualityPolicy` 做最小本地质量门：有 `latest_user_source_ref` 时，非收束回应必须引用该来源；没有本轮锚点的显式 UI 动作必须引用至少一个仍有效的用户来源。此规则也适用于指出材料缺口的澄清回应。零材料回看首轮必须有具体问题入口，像“你今天想聊什么”这样的泛问会被拒绝；明显只有泛泛邀请或鼓励、或正文在引号外提出追问的回应也会被拒绝并进入原有失败／重试路径。引用原话中的问号不拦截。该质量门只挡住结构上明显无用的输出，不替代对无问号反问、思考线连续性、建议取舍是否有据等真实模型语义的复核。

`reviewCoachAnswer` 当前为 1.5.0（保留真实 1.4.0 回放/回退，以及更早历史版本）；JSON schema 仍为 1。独立模板只处理当前事项 `is_latest_answer=true` 的回答，分开证据准备度、追问是否有用与行动意愿。未确定原因可以保持 `not_ready` 或 `partially_ready`，同时返回空问题；这不等于用户拒绝继续。明确要解释时先提供基于当前材料的具体解释，不以“不能替你思考”为由要求填题。

回答复盘的上轮判断是可选上下文：没有初始诊断时显式传入 `previous_assessment_available=false`，直接审读当前事项卡片与回答，不编造上轮缺口。已有上轮模型判断时按原样保留；成功复盘更新后续轮次的上下文。编辑回答使旧反馈失效，但上一轮判断可作为历史上下文保存，不能冒充对新回答的评估。取消/失败后的重试继续 `reviewCoachAnswer`；不得切换成 `generateQuestions` 替换问题和答案。此处是请求组装和客户端生命周期修正，模板仍为 1.5.0、输出 schema 仍为 1。

- 先辨认理解、比较、建议、倾听或纠正的诉求，给与当前情境相关的一步帮助，不机械诊断能力或连续补材料。
- 最新一条明确诉求优先于旧轮次的未完成问题；先完成“读取诉求—选择一种帮助—给出回应—再判断是否追问”的顺序。
- 倾听、疲惫和拒绝追问本身就是有效诉求，不强行转成分析、教学、作业或行动计划；“直接讲”时回答本身优先。
- 每轮只选一个思考动作：事实与解释、目标与手段、选项与代价、关键假设与反例，或下一步与可观察信号。
- 情绪、休息、拒绝总结和不产出均可成立；不强行转成作业或成长结论。
- 追问须实质改变帮助，最多一项，统一放 question，正文不得藏答题要求。明确讲解时无追问；parser 强制 directTeaching 的 question=null。
- 自然语言纠正也优先于旧说法，不要求先点结构化更正；保留其他有效事实。旧助手内容不是事件证据。
- 理解草稿只整理有效用户表达，保留不确定、否定和未决定。复述 AI 不等于认可；没有选句数据时不声称用户逐句选择。
- 一轮只给一个主要建议或比较；缺少证据时说明已知、未知和一个可检查方向，不列训练课程或多个框架。

标准接口的 choices/message/content 响应包被严格解包后再检查协议，不能修补代码围栏、附加说明、缺失字段或虚构来源。timeline 保存已验证的协议正文，PromptRun 继续保存原始接口响应用于审计；重启无需按当前上下文重新解释历史来源。

九个合成语义场景覆盖：只想休息、直接讲解、自然纠正、尚未认可的方法、两次补问后拒绝继续、明确求建议、明确找漏洞、第二个可见回合仍缺少回看材料，以及普通交流中用户补充事实后继续请求建议。Live 断言除协议和来源外，还检查倾听是否接住疲惫、直接讲解是否说明具体差别、纠正是否使用最新范围与原因、建议是否有条件，以及两轮真实模型上下文中的证据更新。`LiveGLMAcceptanceTests/testLiveMentorSemanticCasesWhenExplicitlyEnabled` 需 `MINGSI_LIVE_MENTOR_ACCEPTANCE=1`，使用设备本地 BYOK 配置，输出仅合成材料并保留原始结果供内容复核。契约测试或 Prompt 中写有规则不等于真实模型已遵守这些语义；2026-10-17 已在伊莉丝端点完成这组有限合成样本的逐条 AI 复核，见 `docs/qa/2026-10-17-cc-switch-compatibility/README.md`；未完成人类人工复核或真实个人场景验收。

## Today 先做一个最小思考动作（2026-10-13）

上一版线上资产为 `generateQuestions` 1.23.0；1.22.0 及更早版本仅用于 PromptRun 回放。问题生成运行时只接收确认卡片、最新回答、用户选定视角以及有限的原则和 lens feedback，不注入 `trainingPrescription`、`coachDiagnosis`、`coachTurnState`、`coachTeachingPlan` 或 `coachPatternSummary`。验证行动生成仍可使用教练轮次状态，负责把已复盘判断转换为明日验证行动。

`generateQuestions` 当前为 1.31.0，保留 1.30.0 原文作为回退，并保留 1.24.0、1.23.0、1.22.0、1.21.0、1.20.0、1.19.0、1.18.0、1.17.0、1.16.0、1.15.0、1.14.0 和 1.13.0 作为回退模板。1.19.0 已经规定一次只返回 0 或 1 个问题，1.20.0 增加用户价值门槛，1.21.0 移除线上请求中的本地确定性 `CoachObservationPolicy` 诊断；1.22.0 进一步清理残留的指导冲突；1.23.0 收紧运行时上下文；1.24.0 明确 `selectedLens=null` 是合法的材料直达路径；1.25.0 将历史记录中的结果、自评和思考方法有效性分开，不再按 reinforce/avoid/adjust 强制沿用或避开一种方法。当前问题生成只接收确认卡片、最新回答、用户选定视角以及有限的原则和 lens feedback，不再注入 `trainingPrescription`、`coachDiagnosis`、`coachTurnState`、`coachTeachingPlan` 或 `coachPatternSummary`。确认卡片和最新回答是唯一证据，透镜、原则和历史反馈只是可推翻的假设或可选记忆；它们与材料冲突时让位于材料。问题的回答必须改变判断、选择、证据检查或可观察信号，如果只能让用户“更深入思考”或完成训练，返回空数组。问题、`why_now`、`expected_update`、`proceed_when` 和 `calibration_target` 使用用户情境和普通语言，只解释同一个动作，不能藏第二个任务。帮助优先、用户边界优先、回答优先于提问仍然有效；无论模式都只返回 0 或 1 个问题，问题不足时才问一项可直接回答的缺口，材料足够时返回空数组。深度只增加证据审查，不增加当前轮次的题量。Today 在有 explanation 时展示讲解，否则只说明本轮没有追加问题；不从空数组或模型讲解推断原因已确定或已足够设计验证；用户可继续看是否需要行动或返回材料。每个 `source_card_titles` 必须逐字对应本次 `confirmedCards.title`（仅忽略首尾空格）；本地质量门会拒绝编造、改写或跨事项引用的标题，无法回链时返回空问题集。

1.28.0 / schema 6 明确区分材料缺失与已有材料的重新理解：真实取舍、个人价值和双方已知侧重点可以形成有效问题，无事实缺失时标记 `evidence_gap_type=none`。换位理解先准确表述另一方明说的诉求或限制，再比较双方侧重点；已经区分事实与动机猜测时不重复核对依据，不编造善意动机或要求另行谈话。目录为 builtin.v3，当前 `diagnoseTrainingCase` 为 1.3.0 / schema 2；回退分别保留 1.27.0 和完整冻结 v2 目录的 1.2.0。结构化质量门接纳有来源、具体判断对象、完整用途字段的无缺口重看前提，不再强迫它出现“缺、证据”等词；这只是结构接纳，不替代实际语义审读。

1.29.0 / schema 7 补齐直接帮助：响应为 `{"questions": [], "explanation": {"text": "基于当前材料的简短讲解", "source_card_titles": ["当前确认卡片原题"]}}`。问题轮 `explanation=null`，结束轮也可全部为空。保留历史缺少 explanation 的响应读取；冻结 1.28.0 原文和 schema 6 回退。模型根据用户的真实请求决定讲解或提问，不用关键词路由；讲解两到四句，解释具体区别或机制并保留未知，不暗藏问题、任务、动机断言或能力提升结论。解析拒绝空白、无来源、结构错误和同时夹带问题的讲解；服务拒绝非当前确认卡片来源。AI 讲解和来源在答题页直接可见，可保存并结束，随 `CoachReflectionState.explanation` 保存/恢复；旧会话无此字段可读，切换事项或重置问题时清空解释。输出指纹包含讲解及来源，nil 保持旧问题指纹。讲解不构成用户证据或行动准备度。恢复已保存的问题或讲解不重新触发初始事项诊断；初始建议仅在尚未完成的视角选择中生成。确认/改选视角、继续、退出、切换事项及配置刷新会使旧请求失效，回调还核对当前阶段与完整确认材料，避免旧判断覆盖新交流。


1.26.0 收紧可回答性与理由：只问用户能用已有材料或已知信息回答的一项区别，不要求先调查、测试或与人协调；已说无法取得的事实可以保留未知。解释字段各用一个短句，不能在 why/proceed_when 等元数据里隐藏作业或第二个问题。proceed_when 只说明这一个问题答到哪里，包括诚实说不知道；不是行动门槛或原因成立证明。schema 仍为 6。生产问题卡直接呈现实际理由、预期澄清、足够回答的边界及来源，移除根据缺口/方法枚举补造的指责和作答要求；解析缺失 why_this_matters 时保留空值，不生成“转成可验证行动”的理由。本地预览仍保留旧训练呈现；不作为模型判断。详见[追问理由验收](qa/2026-10-21-question-purpose/README.md)。

`generateQuests` 当前为 1.12.0，保留 1.11.0 原文作为回退，1.10.0、1.9.0 及更早版本用于回放。1.10.0 移除由历史自评导出的思考方法要求；1.11.0 明确历史问题标签和讨论次数不构成能力缺口，AI 问题与建议不构成用户行为，也不能据此安排额外训练。当前请求只把一个已经复盘的判断转换为一个明日验证行动；`side_quests` 必须为空数组，`observation_quest` 必须为 `null`。透镜、教练计划、原则和历史只能帮助选择同一行动的观察角度，不能增加任务、事实或新的训练要求。完成行动不等于判断正确，`completion_criteria` 必须写可观察结果或失败信号；没有区分性信号时，改成最小证据收集行动，而不是普通待办。`linked_cards` 必须逐字对应本次 `confirmedCards.title`，本地质量门会拒绝编造或改写的来源。运行时解析器会拒绝当前响应中的额外行动，历史 PromptRun 仍可按旧版本回放。

`verifyQuest` 当前为 1.11.0，保留 1.10.0 原文作为回退，并保留 1.8.0 及更早版本用于回放。当前模板是独立的结果校准合同：只复盘一个已提交的昨日验证行动，把完成、价值、自报结果和判断更新分开；完成动作本身不能证明价值或判断正确。缺少、间接或冲突的结果会保持判断开放，并只给一个可观察的下一校准信号，不重新开启今日问卷或生成原则。原则实践评估只是审计反馈，不能反过来成为实践证据；成长证据只有在本次材料支持具体行为时才返回。反馈用两三句短句说明实际结果、验收边界和判断更新；下一次自愿观察只放在 recommendation，不在正文重复。output schema 4 引入，独立返回 calibration_assessment：evidence_status（observed/missing/conflicting）、criteria_status（met/not_met/not_assessable）、judgment_status（supported/weakened/unresolved）及 evidence_quotes。缺少结果时必须无引用、验收不可判断、判断未决且无成长证据；有结果时一至三段引用必须逐字出自本次 currentInput.rawText，不可改写、重复或引用目标判断代替结果。当前服务强制校验结构、状态一致性及原文引用；用户反馈只做最小长度检查，不再要求六组固定报告标签。旧 schema 仍可解码回放，其文本检查仅用于兼容；这些检查不能证明引文含义或模型语义正确，仍须逐条内容复核。

1.11.0 / schema 5 另外返回 `principle_practice_assessment`：无所选原则时为 null；有原则时包含原 principle_id、practiced / partially_practiced / not_practiced / not_assessable、evidence_quotes 和简短 reason。请求包含原则原有触发情境、动作、成功标准及例外。只有本次原文描述的实际动作可以归属实践；选择、计划、完成/价值自评、好结果和模型自己的审计文案均不能充当实践证据。可判断的三种状态必须引用一至三段逐字连续原文；无法判断须空引用，缺少原则动作/情境也不可推断。ID、引文和必要上下文由服务校验，旧版本缺少新评估时保持未记录。实践与结果分开：动作做过但结果失败或未知，仍可支持本次行为记录；结果好却没有动作记录不能证明实践。不从次数推断效果、能力或内化，不要求用户为获得标签补做练习。`expected_principle_practice_assessment` 仍只作审计反馈，新结构化判断也只是对用户本次记录的模型评估，不是独立事实核实。

`extractPrinciple` 当前为 1.6.0，保留 1.5.0 及更早版本用于回放。当前模板也是独立合同：原则只是候选假设，不是奖励、承诺或能力结论。只有至少两个独立具体实例形成重复模式，或用户明确陈述了带触发边界和下次检验方式的不变量，才允许生成候选；一次成功、一次好结果、积极感受或完成任务都不足以沉淀原则。`source_card_titles` 必须逐字回链本次 `confirmedCards.title`，否则返回 `principle_candidate: null`。缺少重复、边界或可验证的下次使用标准时返回 `principle_candidate: null`。

`reviewCoachAnswer` 1.5.0 将 `open_evidence_gaps` 限制为一个最重要的缺口。只有现有材料可回答、不重复且能改变当前帮助的问题才保留，未就绪不强制追问。`user_boundary=stop` 或 `ready` 仍不得追加问题；`ask_clarifying_question` 则必须有实际问题。明确收束时四个可选练习/参考字段仍须为空，客户端拒绝通过其他字段继续安排练习。训练目标、输出、自检、经验比较及已补材料留空时保持原样；界面不呈现空的训练说明。卡片和回答 ID 是证据，事项 ID 只用于路由。

2026-10-16 运行时上下文同步清理：`generateQuests` 保留教练状态和未关闭缺口作为可选参考，但不再注入旧的 `coachDiagnosisRule`、`coachTurnRule`、`coachTeachingRule`。这些旧规则要求先补问或满足教学标准才继续，与用户选择带着缺口进入一个安全验证行动相冲突。当前版本化模板是行为规则的唯一来源；本地上下文不另加一套提问义务。请求 JSON 结构仍为 v1，实际字段值继续随本次请求冻结。

这次重写针对当前最大风险：明思很容易把“训练计划、透镜和历史问题”变成必须完成的流程，用户明明需要解释、休息或一个实际回答，却被带进题目。当前 Prompt 不再依赖字符串替换来消除旧指令；历史版本只用于回放，线上版本使用单一、可审计的帮助路由和输出合同。

- 第一问必须是当前最高价值的缺口，并且能在这一轮直接回答。
- 不预先写完整课程、完整诊断或所有反方意见；后续问题只能根据已提供的回答生成。
- 追问保持同一能力和同一主训练目标，不在同一批切换透镜或增加第二个训练目标。
- 这项约束只改变当前 Prompt；历史 Prompt 仍可按版本回放，固定结构测试不把合成问题数量当作真实教练质量。
- 空问题集表示没有值得追加的问题，不能据此推断原因已成立，也不能当作行动同意。用户可以保存返回；只有另行选择设计验证时才检查待验证判断。

### 多轮边界

- 导师交流（`mentorRespond`）是会话式多轮：零材料点击“带我回看”时先自动请求一次具体回忆入口；之后用户每次发送才触发下一次模型请求，当前会话历史会随请求传入。模型不会预生成整段对话。每轮最多提出一个必要问题，用户可以直接结束或只听回答。第二个可见回合后通常收束；若回看仍缺具体片段且补材料预算未耗尽，可以继续提出有区分度的材料问题，最多两轮，用户拒绝或表示想不起来则停止。
- Today 的“教练追问”按当前材料逐轮复盘。首轮允许零或一个有价值的问题；回答后 `reviewCoachAnswer` 可追加同一事项的一条可回答问题，最多两条修补轮次。证据未闭合也允许不追问；就绪也不自动进入明日验证。
- 修补回答提交后再复盘；上下文明确标记最新回答，不能重复旧问题。复盘后无新问题时主动作是“先保存，返回今日”；有未答追问时也有同名次要出口。保存保留回答、准备度、缺口和透镜选择，不完成现实事项、不新增行动、原则或成长贡献。设计验证是独立的明确选择。
- 用户明确说累了或不想继续回答时返回 `user_boundary=stop`。仅“不知道原因”不自动解释为停止；`continue` 与空问题可以同时存在。证据准备度不被停止、保存或继续选择改写。
- 输入框编辑不会触发模型请求，只有提交当前回答才会触发下一轮；网络失败也不会把静态反馈伪装成已完成的多轮。

### 当前轮次锚点

- `MentorContextPayload` 在保留 1.0.0 schema 的同时，新增可选的 `latest_user_source_ref` 和 `current_exchange_refs`。前者只在本次确实新增用户原话时指向当前表达；后者列出当前用户与紧邻的上一条 assistant 条目，帮助理解省略表达。缺失字段的旧持久化上下文仍可回放。
- 同一 payload 还带有可回放的 `conversation_state` 路由信息：当前可见轮次、是否有新用户表达、上一条 assistant 的来源以及上一问（若能从已保存回应中解析）。它不是用户证据；解析器会拒绝与上一问相同的下一问题，避免模型在多轮中原样重复追问。
- 导师 Prompt 必须先解析 `latest_user_source_ref`，不能仅依据 `sources` 排列、`is_current` 或历史问题猜测当前轮。锚点为空时，`intent=explain` 仍应执行明确的讲解动作，`intent=draft_understanding` 应整理所有仍有效的用户表达；其他意图不得把历史助手内容、教材或训练计划当作新的用户诉求。

## 完整人生指南回顾入口（2026-10-09）

`lifeGuidanceShortlist` 读取全部候选标题，依据用户明确事件选至多 5 个原始 ID；没有充分对应返回空数组。随后 `lifeGuidanceReview` 读取候选的完整摘要、成本、收益和备注，最多选择一条资料入口。原文资料不被标为人工审核完成，也不能生成针对用户的医学、法律或投资结论。

两步都经中央决策中心，保留事件和导师会话来源；删除会话后迟到审计记录不能写回。用户事件最多 20 条、合计 8,000 字，每次请求上限 160,000 字节；不能截断目录、用本地关键词兜底或编造候选。最终匹配仍要求连续原话至少六字、置信度至少 0.9、说明不超过 200 字；日内稳定、同一回顾只决策一次、14 天去重。

## vNext Case Isolation And Stream V2 (2026-07-15)

- `organizeCards` uses `MINGSI_STREAM_V2` and may include `CASE_KEY` / `CASE_TITLE` in every CARD.
- The streaming parser remains compatible with V1. Missing or invalid grouping falls back to one matter.
- The model proposes groups only; it never confirms, merges, splits, closes, restores, or saves a principle.
- Matter-scoped coaching requests include `PromptContextPayload.currentCase` with Case ID, title, status, and explicit evidence refs.
- `diagnoseTrainingCase` 1.3.0 / schema 2 is the model authority for phase, readiness, a possible viewing angle, and at most one explicit material gap. `open_evidence_gaps` and exact confirmed-card `source_refs` are required. Already reported observations cannot become missing facts just because a broad phase is `fill_evidence_gap`; no justified repair may remain `not_ready` with `[]`. Malformed, foreign-source and ready-with-gap outputs fail without a local substitute or automatic retry. Unconfirmed, excluded and explicitly other-Case cards never enter this request.
- Initial model gaps are carried by `CoachDiagnosis` and used verbatim in the initial turn; old model decisions lacking explicit gaps retain unknown gaps instead of inheriting a phase-based local diagnosis. Explicit preview policies retain their existing behavior. The current model selection page does not prepend the local keyword diagnosis, local teaching route or uncalibrated confidence percentage. Lens selection remains optional. Historical 1.0.0 / schema 1 is retained for rollback; it does not establish missing materials.
- When currentCase is present, rawText is rebuilt only from that Case's confirmed cards. Other same-day matter text is excluded.
- PromptRun source IDs include the active Case ID, actual source record IDs, context policy version, provider, and model.
- Every PromptID maps to a stable `LLMDecisionRoute`; PromptRun diagnostics derive and display that route without requiring a migration. This makes the global decision center auditable while preserving feature-specific schemas and evidence boundaries.
- Guidance UI copy comes only from the versioned local catalog. The shared LLM decision center selects at most one eligible hint for the current stage and classifies verification evidence as supporting, contradictory, or insufficient. It may not invent hint IDs, UI copy, scores, or personality conclusions.
- A weekly guidance review is allowed only when the last seven days contain at least three Verifications across two calendar days. Its response is limited to `training_focus`, existing `hint_ids`, and supplied Verification `evidence_refs`; it never writes metric scores or contributions.
- A project closure summary is user-triggered. It may use only confirmed project evidence, and every proposed principle must cite at least two supplied evidence references. Candidates are saved for explicit, per-item user confirmation.

V2 card fragment:

```xml
<MINGSI_STREAM version="2">
<CARD>
<CASE_KEY>stable-matter-key</CASE_KEY>
<CASE_TITLE>自然语言事项标题</CASE_TITLE>
<TYPE>fact</TYPE>
...
</CARD>
</MINGSI_STREAM>
```

## Prompt Architecture

Prompt 与上下文工程的完整产品规格见 `docs/prompt-context-engineering-prd.md`。本文档保留具体 Prompt schema 和模板要求；上下文选择、原则资产检索、上下文预算和 eval 规则以该 PRD 为准。

## Side Quest Situation Grounding

- `generateSideQuest` receives only a reduced `current_situation`: coarse scene, availability, opaque context markers, and dynamic constraints. With explicit HealthKit permission, recent activity and sleep may appear only as coarse threshold tokens. It never receives coordinates, location names, calendar titles, health samples, exact health values, contacts, or the user's raw system records.
- Practical place context is typed and semantic: `home` or `workplace`, optional floor level, explicit stairs availability, and selected transition windows. User-entered home/workplace labels are local-only and are excluded from both `life_context` and `available_grounding_refs`; legacy unscoped floor data is retained locally but not sent to the model.
- A user may temporarily correct the coarse scene to home, work, familiar place, or unknown. The correction is in-memory only, expires at the end of the local day, and overrides a system scene only while valid.
- The central model alone decides `offer` or `hold` and supplies a short natural-language reason plus exact `grounding_refs`. For an offer, every grounding reference must match one supplied `available_grounding_refs` token exactly; local code validates consent, expiration, grounding membership, safety, eligibility, and durable state only, and must not invent a substitute invitation.
- A delivered invitation snapshots the model rationale. Today may render that rationale as “为什么现在推荐” only for AI-generated runs and never exposes the prompt, `grounding_refs`, opaque tokens, or raw system data.

Prompt 不允许和 SwiftUI 页面耦合。业务层只能通过 `PromptProvider` 获取模板。

## digestCaptures

- route 为 `capture`，模板版本化且必须通过 `CentralLLMDecisionCenter` 和 PromptRun tracing。
- 输入只可为同一本地自然日的至少两条 pending `CaptureFragment` 原始文字；PromptRun source IDs 必须是实际 fragment IDs。
- 输出 JSON 严格为 `summary`、`themes`（1-3 个非空值）、`recommended_question`（0-1）和 `source_refs`。source refs 不可重复，且必须恰好覆盖全部输入。
- 模型不得改写来源原文，也不得创建事项、卡片、行动、原则、指标、通知或训练结论。缺 key、网络或 schema 失败保持 pending，禁止本地伪造结论。

MVP 使用：

```text
LocalPromptProvider
```

未来可切换为：

```text
RemotePromptProvider
```

每次模型调用必须记录：

- promptId。
- promptVersion。
- inputSchemaVersion。
- outputSchemaVersion。
- modelProvider。
- modelName。
- sessionMode。

## Common System Behavior

```text
You are a thinking coach for a busy knowledge worker.
Your role is to help the user clarify problems, challenge assumptions, choose high-value actions, and calibrate judgment.
Do not decide for the user.
Do not replace the user's thinking.
Separate facts, interpretations, assumptions, risks, and validation needs.
Do not encourage the user to share confidential company information, code, customer data, or internal documents.
Be concise, concrete, and non-performative.
Return valid JSON matching the requested schema.
```

## Session Modes

```text
quick:
  shortest path, fewer questions, one main quest.

standard:
  default full loop, cards, lens, one question per coaching turn, quests, principle candidate.

deep:
  higher scrutiny and stronger opposing views within one question per coaching turn; depth never creates a questionnaire.
```

Mode affects prompt depth, not the underlying data model.

## GLM Response Contract

- Preferred transport: OpenAI-compatible Chat Completions with `response_format: {"type":"json_object"}`.
- Compatibility fallback: if a GLM-compatible endpoint rejects `response_format`, the client retries once without that field.
- All prompts must therefore still say “return valid JSON only” and include an explicit output shape; the parser must not depend solely on transport-level JSON mode.
- Fallback does not change schema versions or parser expectations.
- A successful connection test does not guarantee successful production prompts; production calls can still fail on quota, model permission, malformed JSON, empty content, schema mismatch, or transport errors.
- If a production prompt fails, including when the API Key is missing, UI must show the concrete error, preserve confirmed local input, and allow retry with the same input; it must not silently replace a model decision with local heuristics. An explicitly labeled local fallback is limited to injected test or preview paths and legacy fixtures.
- Retry prompts must be idempotent: re-running the same prompt against the same DailyEntry should replace only that prompt's draft output, not duplicate cards, quests, or principles.

## Opt-In Live Career Golden Evaluation

- `scripts/run_live_glm_acceptance.sh` keeps the ordinary single completion probe as its default behavior. `--career-golden` selects one separate XCTest that runs exactly three synthetic `generateQuestions` scenarios: student, software engineer, and finance worker.
- The career run requires both `MINGSI_LIVE_GLM_ACCEPTANCE=1` and `MINGSI_LIVE_GLM_CAREER_GOLDEN=1`, plus an explicit BYOK environment key. Missing either opt-in or the key skips the XCTest and never sends a request; Keychain-only configuration is not enough for this paid live evaluation.
- Each scenario uses the current `LocalPromptProvider` template and structured payload, then parses the real DirectGLM completion with `TodayAIResponseParser` and rejects `PromptCoachingQualityPolicy` failures. Career labels are context only, never evidence for ability, motivation, preference, income, responsibility, or a conclusion. The request also denies stereotypes, appeasement, and direct-answer behavior.
- This is a manually invoked regression harness, not a product workflow or a source of user data. It does not assert exact output wording and it does not log the BYOK key.

## Opt-In Live Mentor Semantic Evaluation

- `scripts/run_live_glm_acceptance.sh --mentor-semantic` selects `LiveGLMAcceptanceTests/testLiveMentorSemanticCasesWhenExplicitlyEnabled` and injects `MINGSI_LIVE_MENTOR_ACCEPTANCE=1` into the fixed iPhone 17 XCTest environment. The ordinary probe and career golden selectors remain unchanged.
- The mentor run uses the simulator Keychain BYOK configuration when no environment key is supplied. It sends only five synthetic cases: tired and not summarizing, direct teaching/comparison, a natural-language correction, uncertainty about a method, and refusal after the material-question budget. Raw JSON responses are retained as XCTest attachments for manual semantic review.
- Parsing and the small deterministic assertions are necessary protocol checks, not proof of helpfulness. The acceptance record must state whether each response actually helped with the requested mode, avoided hidden questions, respected the latest correction, and preserved uncertainty.

## Data Shapes

### Thinking Card

```json
{
  "type": "fact | problem | decision | risk | idea | communication | task",
  "title": "string",
  "body": "string",
  "importance": "low | medium | high",
  "sensitivity": "normal | possibly_sensitive | sensitive",
  "confidence": "low | medium | high",
  "reason": "string"
}
```

### Thinking Lens

```json
{
  "id": "first_principles | occams_razor | opposing_view | opportunity_cost | leverage_analysis | evidence_check | execution_bias_check",
  "name": "string",
  "why_recommended": "string"
}
```

### Reflection Question

```json
{
  "question": "string",
  "why_this_matters": "string",
  "why_now": "why this question is the right next move in the current coach turn",
  "expected_update": "what judgment, action, evidence plan, or calibration signal the answer is expected to change",
  "proceed_when": "what kind of answer is sufficient to move toward action",
  "evidence_gap_type": "missing_observation | missing_baseline | missing_causal_link | missing_counterexample | missing_constraint | missing_calibration_signal | none",
  "answer_use": "update_judgment | choose_action | test_assumption | collect_evidence | watch_calibration_signal",
  "lens_move": "fact_interpretation_split | alternative_explanation | leverage_tradeoff | constraint_decomposition | feedback_loop | delayed_effect | second_order_consequence | prediction_calibration",
  "source_card_titles": ["string"],
  "calibration_target": "specific judgment, assumption, prediction, causal explanation, or tradeoff this question will calibrate",
  "expected_answer_type": "fact | judgment | tradeoff | validation"
}
```

`why_now`, `expected_update`, and `proceed_when` are user-visible teaching fields, not hidden parser metadata. Together they must explain why this question now, what the answer will change, and what is sufficient to proceed. Today may render them directly inside question teaching cues, so they must be concrete, short, and grounded in the current coach turn.

### Lens Feedback

Current `generateQuestions` 1.26.0, `generateQuests` 1.11.0, and weekly/monthly growth 1.1.0 share `HistoricalEvidenceContract`:

```json
{
  "lensId": "string",
  "lensTitle": "string",
  "signal": "review_evidence | self_report_only",
  "completion": "done | partial | missed",
  "valueRating": "high | medium | low | uncertain",
  "verificationId": "UUID",
  "trainingCaseId": "optional UUID",
  "evidenceText": "reported result, including unknown or conflicting records",
  "calibrationAssessment": {
    "evidenceStatus": "conflicting",
    "criteriaStatus": "not_assessable",
    "judgmentStatus": "unresolved",
    "evidenceQuotes": ["exact saved result excerpt"]
  },
  "calibrationNote": "saved model feedback, not independently verified facts",
  "recommendation": "optional saved recommendation",
  "questionTargets": ["specific prior calibration target"],
  "evidenceGapTypes": ["missing_calibration_signal"],
  "lensMoves": ["prediction_calibration"]
}
```

- `completion` and `valueRating` are user self-reports, including done/high; they do not establish observed results, method effectiveness, or ability growth.
- `review_evidence` means a structured assessment was saved; inspect that assessment and the actual result. `self_report_only` means a legacy record lacks an assessment. Do not fabricate one from ratings.
- Preserve missing, conflicting, not_assessable, unresolved, raw result text, and saved feedback. Even observed/met/supported concerns the target judgment in that attempt; it does not prove the lens caused success or transfers to a different matter. A useful counterexample need not meet an action's criterion.
- Keep verification and case ownership aligned with each lens session, including multiple matters on the same day. Include only selected visible history IDs in `contextRecordIDs`; keep a small recent sample rather than all daily raw text.
- Old reinforce/avoid/adjust labels are unproven historical labels, never instructions or quality gates. Current conditions determine whether a question or action is useful; history does not require an extra task.

Historical assets described lens feedback as "verified outcomes" and used reinforce/adjust/avoid. The historical instruction "Do not repeat a lens move that produced low-value or uncalibratable work" is retained only in old assets for replay; current templates do not apply it.

### Training Dimension

Coach-led training uses `TrainingPrescription` as a plan, not just a selected lens. Prompt context carries:

```json
{
  "primaryTrainingDimension": "evidence_discipline",
  "secondaryTrainingDimensions": ["fact_interpretation_separation", "counterexample_seeking"],
  "baselineTrainingDimensions": [
    "fact_interpretation_separation",
    "evidence_discipline",
    "counterexample_seeking",
    "assumption_testing",
    "testable_action_design",
    "system_feedback_awareness",
    "judgment_calibration"
  ]
}
```

Supported `ThinkingTrainingDimension` values:

- `fact_interpretation_separation`: separate what happened from the user's interpretation.
- `evidence_discipline`: name missing evidence, weak evidence, and what observation would close the gap.
- `counterexample_seeking`: ask what would make the user's current view wrong or incomplete.
- `assumption_testing`: expose inherited assumptions and test the smallest necessary premise.
- `system_feedback_awareness`: look for feedback loops, delays, constraints, and second-order effects.
- `judgment_calibration`: compare prediction, confidence, actual evidence, and judgment update.
- `testable_action_design`: turn thinking into one action with observable completion or calibration evidence.

Rules for historical coach-led assets:

- Historical `generateQuestions` prompts apply this plan before output generation.
- Do not rely on the deterministic quality gate as the first place where training-dimension alignment happens in those historical assets.
- Every question in a historical coach-led turn serves either the primary training dimension or one baseline training dimension.
- The first question in a historical coach-led turn should usually train `primaryTrainingDimension`; later questions may cover `secondaryTrainingDimensions` or unresolved baseline gaps.
- Baseline dimensions are checks, not permission to generate a broad questionnaire. Keep one main coaching focus per loop.
- Do not treat a user's override lens as proof that the coach diagnosis was wrong. Keep `primaryTrainingDimension` tied to the coach recommendation and use `finalTrainingLens` for the generated lens move.

Current 1.23.0 behavior:

- The current question request does not receive `trainingPrescription`, `coachDiagnosis`, `coachTurnState`, `coachTeachingPlan`, or `coachPatternSummary`. It receives confirmed cards, the latest answer, the selected lens, and bounded principle/lens feedback memory.
- A current evidence-grounded question is not rejected solely because it does not match a stale training dimension or coach turn. The runtime calls the quality gate with coach-alignment checks disabled for this current path; structural checks, source grounding, selected-lens safety, and the one-question limit remain active.

### Non-Appeasing Coach Stance

`generateQuestions`, `generateQuests`, and `extractPrinciple` must tell the LLM
that MingSi is not a satisfaction-maximizing assistant. The prompts must forbid
flattering, reassuring, or agreeing only to validate the user.

Empathy is not agreement. The coach may acknowledge pressure, ambiguity, or
context only when that acknowledgement helps the user face the real thinking
gap, action-design gap, or reusable-rule gap. It must not turn pressure,
difficulty, or feeling understood into evidence that the user's current
judgment is sound.

When the user's input contains a weak claim, missing evidence, premature
conclusion, vague goal, avoided responsibility, harmful pattern, or unchecked
experience reuse, the prompt should name the weak thinking move, task-design
gap, or reusable-rule gap clearly. The critique must target the thinking move,
action design, or principle candidate, not the person. The prompt must not
diagnose personality, intelligence, motivation, or hidden intent.

Stage-specific boundaries:

- `generateQuestions` should ask the user to repair the missing thinking move
  instead of validating confidence.
- `generateQuests` must not turn a weak judgment into a quest just to let the
  user proceed. If action is still useful, the quest must test the unresolved
  evidence gap, skipped tradeoff, premature conclusion, or avoided
  responsibility.
- `extractPrinciple` must not turn an unverified story or comforting lesson into
  a principle. If the lesson lacks evidence, exceptions, trigger boundaries, or
  a concrete action standard, return `principle_candidate: null`.

Every correction should state:

- what was observed;
- why it is weak or risky;
- what ability it trains;
- what to repair next.

### Evidence Ownership And Loop Handoff

The core coach loop must preserve a strict boundary between reported material,
coach interpretation, action completion, observable results, and a judgment
update. This is a higher-value guardrail than adding more coaching prose.

- `organizeCards` preserves a user statement as reported material. It must not
  promote an interpretation, motive, causal explanation, or intention into a
  verified fact card.
- `recommendLenses` and `generateQuestions` may use coach diagnosis and
  observation to choose a training move, but must describe them as coaching
  interpretations rather than source evidence. If the input only contains an
  interpretation, the next question should request an observable event,
  baseline, or counterexample.
- `generateQuests` turns one testable judgment into an action. Completing that
  action is not proof that the judgment is true or that value was created. Its
  completion criteria must capture a discriminating result, response, artifact,
  metric, or failed acceptance criterion.
- `verifyQuest` treats completion, self-report, completion evidence, actual
  value, and the user's proposed update as separate claims. It may confirm,
  weaken, or update a judgment only from supplied observable evidence. Missing,
  indirect, or conflicting evidence must keep the judgment open and lead to a
  next evidence-collection step. The product must collect one user-written
  observable result before this prompt runs and retain it with the verification
  record; today's new raw input is not a substitute for yesterday's evidence.
- `extractPrinciple` does not promote a single completed action, favorable
  result, or feeling into a reusable rule. It needs a repeated pattern or a
  stated invariant with an explicit boundary and a checkable next-use test;
  otherwise it returns no principle candidate.

来源归属还要由运行时质量门复核，而不能只写在 Prompt 里：问题的
`source_card_titles`、明日行动的 `linked_cards` 和原则的
`source_card_titles` 必须是当前已确认卡片标题的去重子集。任一标题无法逐字
回链时，当前结果被拒绝并进入可重试路径；这防止模型用一个看似合理但并不存在
的标题给判断、行动或原则制造证据。

This contract applies before deterministic quality gates. The gates remain a
backstop, not the primary place where the model learns the distinction.

### True-Need Grounding

`真需求` is not a new interview flow or a prompt label shown to the user. It is
a test for whether MingSi is training a meaningful judgment rather than helping
the user complete an unexamined request.

- A requested task, feature, solution, or plan is a proposed means, not proof
  of the underlying condition that matters.
- If the material only names work to do, `generateQuestions` should uncover one
  missing link: the affected person or object, the consequence of inaction, or
  the observable condition that would count as success.
- If the material already states that condition, the coach must not add a
  separate needs-analysis step. It should continue to evidence, tradeoffs, and
  a testable judgment.
- `generateQuests` must design a smallest respectful discovery action when the
  condition is unknown, or otherwise a validation action that can show whether
  the proposed work changed that condition. Delivering work alone is not a
  successful validation result.

The user-visible loop remains plain language: `讲清今天 -> 找出判断 -> 行动验证`.
“实现路径” is too solution-first, and “实践路径” still reads as a training
assignment; neither should be the primary navigation label.

### Coach Turn State

Coach Turn State v1 turns the coach from a one-shot lens recommender into a Today-local stateful coach loop. The state is persisted locally, while its meaningful diagnosis is produced by `diagnoseTrainingCase` through the central decision center. Prompt context may carry:

```json
{
  "coachTurnState": {
    "phase": "explore_problem | clarify_judgment | fill_evidence_gap | form_action",
    "readiness": "not_ready | ready",
    "recommendedMove": "ask_clarifying_question | surface_evidence_gap | slow_down_convergence | recommend_training_lens | generate_quest",
    "reason": "short coach rationale",
    "openEvidenceGaps": ["missing_observation", "missing_baseline"],
    "baselineChecks": ["fact_interpretation_separation", "evidence_gap", "testable_action"],
    "decisionSource": "coachRecommended | coachAccepted | userSlowDown | userOverrideProgress",
    "policyVersion": "coach-turn.local-v1",
    "turnSummary": "short summary of where this coach turn currently stands"
  }
}
```

The prompt directive key is `coachTurnRule`.

Rules:

- organizeCards must not receive `coachTurnState`. It also must not receive `coachDiagnosis`, historical principles, or training history. It only cleans current raw input into reviewable cards.
- Historical question assets may use `coachTurnState` before choosing question style. The current `1.23.0` request does not receive it; it decides from today's material and may return zero or one question.
- `generateQuests` may form a verifiable action when readiness is `ready`.
- An action-design request must not reopen the review questionnaire. Keep the unresolved gap visible in the one safe validation action when the user explicitly chooses to proceed.
- If readiness is `not_ready`, `generateQuests` should not produce a quest unless `decisionSource` is `userOverrideProgress`.
- A user override is permission to proceed, not proof that the coach was wrong.
- An override is permission to proceed, not proof that the coach was wrong.
- `openEvidenceGaps` should guide the next question before the model invents broader advice.
- `baselineChecks` are quiet guardrails; they should prevent premature convergence without turning the loop into a broad questionnaire.
- `turnSummary` is an audit summary for the current coach turn, not source evidence.

### Coach Teaching Plan

Coach Teaching Plan turns the current coach turn into a teaching frame. It tells
the model what the user has not thought through yet, why MingSi is training that
move instead of giving an AI answer, and what is enough to proceed. Prompt
context may carry:

```json
{
  "coachTeachingPlan": {
    "policyVersion": "coach-teaching.local-v1",
    "missingMoveTitle": "the missing thinking move the user has not handled yet",
    "trainingTargetTitle": "localized primary training target",
    "whyNotAnswer": "why this is not an AI answer or direct advice moment",
    "proceedStandard": "what answer or evidence is sufficient to continue",
    "repairQuestion": "the concrete question that asks the user to repair their own prior answer",
    "experienceReplayPrompt": "the prompt that asks whether prior experience should be reproduced, adapted, or rejected",
    "routeSteps": ["first teaching step", "second teaching step", "third teaching step"],
    "auditNote": "optional override or boundary note"
  }
}
```

The prompt directive key is `coachTeachingRule`.

Rules:

- Historical question assets may use `coachTeachingPlan` before wording questions.
  The current `1.23.0` request does not receive it; the current turn must not
  inherit a hidden training target.
- Historical question assets used `repairQuestion` to ask the user to repair
  their answer. Current action design does not turn that stored prompt into
  another required question.
- `experienceReplayPrompt` is optional comparison context; it does not create
  another assignment after a user chooses to proceed.
- `generateQuests` may use `coachTeachingPlan` to preserve the proceed standard
  when forming an action after the coach turn is ready or explicitly overridden.
- organizeCards must not receive `coachTeachingPlan`; it only cleans current raw
  input into reviewable cards.
- `coachTeachingPlan` is not source evidence. It is the coach's operational
  teaching frame for the current turn.
- `routeSteps` are training route cues, not a command to add extra workflow
  steps or a broad questionnaire.
- A user override may proceed, but `auditNote` and `proceedStandard` must keep
  the unresolved gap visible.

### Coach Observation Context

Coach Observation Context gives `generateQuestions` a structured interpretation
of the observed material before it words reflection questions. It is designed to
make MingSi show what it noticed in the user's description, what thinking gap is
still open, what core ability is being trained, and which prior experience might
need replay, adaptation, or rejection. Prompt context may carry:

```json
{
  "coachObservation": {
    "policyVersion": "coach-observation.local-v1",
    "providedMaterials": ["event", "action"],
    "missingMaterials": ["stakeholder", "constraint"],
    "thinkingProcessObservation": "short description of the user's visible thinking process",
    "primaryGap": "observation",
    "secondaryGaps": ["evidence"],
    "trainingAbility": "communication",
    "feedback": {
      "observed": "what MingSi saw in the observed material",
      "diagnosis": "why the current thinking is incomplete or risky",
      "training": "the core ability this turn trains",
      "ask": "the repair question shape the user should answer",
      "proceedWhen": "what kind of answer is enough to proceed"
    },
    "experienceReplayPrompt": "how prior experience should be reproduced, adapted, or rejected"
  }
}
```

The prompt directive key is `coachObservationRule`.

Compatibility note for the historical asset: `generateQuestions` 1.22.0 does not
send this local heuristic context to the online model, and its prompt does not
describe that absent value as a signal to read. The schema remains for
historical PromptRun replay, offline UI copy, and explicitly labelled fallback
previews. The current request uses confirmed cards and the latest answer as
evidence, while any coach diagnosis or lens remains a provisional hypothesis.
The model must separate observation, interpretation, judgment, and observable
update before deciding whether a question is useful; a checklist gap alone is
not a reason to ask.

Rules:

- Historical `generateQuestions` PromptRuns may use `coachObservation` before
  wording questions: cite the observed material, start from `primaryGap`, train
  the named `trainingAbility`, use `feedback.ask` as the repair shape, and use
  `experienceReplayPrompt` when prior experience should be reproduced, adapted,
  or rejected. The current 1.23.0 request must not receive this local heuristic.
- organizeCards must not receive `coachObservation`; it only cleans current raw
  input into reviewable cards and must not inherit coach interpretation.
- `coachObservation` is not source evidence. It is the coach's interpretation of
  confirmed material and should not create new facts, card titles, or user
  claims.
- If `missingMaterials` is non-empty, questions should repair the highest-value
  missing material instead of asking a broad questionnaire.
- `feedback.observed`, `feedback.diagnosis`, and `feedback.training` should make
  the user feel the coach is training a thinking move, not generating a generic
  AI answer.

### Question Training Contract

Historical `generateQuestions` assets turn the observation into one primary training contract before they write questions. The current 1.23.0 contract
derives the smallest move from confirmed evidence and treats any coach
diagnosis as a provisional hypothesis.

Rules:

- The first question must ask the user to produce missing material for that
  contract; it must not provide the missing material, solve the case, or turn the
  coach into an answer generator.
- `why_now` must name the observed gap that makes this the next training move,
  not just say the topic is important.
- `expected_update` must name the user-owned training output the answer should
  create, such as a clearer event description, a separated fact, a stated
  judgment standard, a condition difference, or a calibration signal.
- `proceed_when` must name a self-checkable standard the user can inspect in
  their own answer.
- If `experienceReplayPrompt` is relevant, ask the user to decide whether prior
  experience should reproduce, adapt, or reject today's move before applying it.
- Later questions may touch baseline checks, but they must not dilute the
  primary contract or become a broad questionnaire.

### Judgment Sentence Training

MingSi separates two loops:

- 今日理解闭环: today content and 今日复盘 clarify what happened, what the user
  did, what the user believes, what evidence is missing, and which judgment is
  now testable.
- 行动验证闭环: 明日验证 turns one reviewed judgment into a validation action; result
  calibration later compares the action, evidence, value, and judgment update.

`generateQuestions` must train the user toward this judgment sentence without
answering for them:

```text
我现在相信 X；明天用 Y 观察它是否成立；如果出现 Z，我就更新判断。
```

For `generateQuestions`, `calibration_target must be X`: the belief,
prediction, causal explanation, or tradeoff being tested. `expected_update` and
`proceed_when` should help the user make X, Y, and Z concrete enough to move
from 今日复盘 into 明日验证.

`generateQuests` 1.12.0 reuses the grounded substance without imposing the full
first-person XYZ sentence. Preserve an observable tentative target, the signal
and the update direction in their respective fields. A supplied meta claim
about insufficient evidence may be narrowed to an observable proposition only
when the original material supports it; preserve uncertainty and do not imply
that the user endorsed a stronger belief or causal claim. Unknown outcomes and
concrete negative predictions remain valid.

### Quest

```json
{
  "type": "main | side | observation",
  "title": "string",
  "why_it_matters": "string",
  "completion_criteria": "string",
  "expected_resistance": "string",
  "reflection_question": "string",
  "calibration_target": "specific judgment, assumption, prediction, causal explanation, or tradeoff this quest will calibrate",
  "lens_move": "fact_interpretation_split | alternative_explanation | leverage_tradeoff | constraint_decomposition | feedback_loop | delayed_effect | second_order_consequence | prediction_calibration",
  "linked_cards": ["string"]
}
```

Rules:

- Quest must carry the calibration target into tomorrow's verification.
- Quest must carry the selected lens's reasoning move into `lens_move`; this is parsed into `Quest.lensMove` and persisted with the quest's calibration payload.
- Quest must cite confirmed card titles in `linked_cards`; these are parsed into `Quest.sourceCardTitles` and persisted with the quest's calibration payload.
- Use the reflection answer's `calibrationTarget` when present; otherwise derive a concrete target from confirmed cards and the user's answer.
- Do not switch the task into a different lens move just because it sounds useful; the quest is the action form of the selected thinking lens.
- Do not invent `linked_cards`; use only confirmed card titles from the current context.
- Do not use vague targets such as "user thinking" or "this situation".

## Deterministic Coaching Quality Gate

`PromptCoachingQualityPolicy` is a local, deterministic quality gate for obvious coaching regressions. It does not call the LLM and does not replace deeper human or LLM review. It protects the core coaching loop from accepting outputs that are syntactically valid but not useful as thinking training.

The gate supports an explicit `enforceCoachAlignment` switch. Historical and
offline coach-plan evaluations keep it enabled. The current `generateQuestions`
1.23.0 path disables only plan-alignment checks because those checks would turn
a provisional diagnosis into a hidden requirement; structural fields, source
grounding, selected-lens checks, and the one-question limit remain enforced.

Question output can be flagged with:

- `genericQuestion`: question invites generic reflection, opinion, venting, or mood description.
- `tooManyCurrentTurnQuestions`: the active Today request returned more than one question; the user must receive the next move in a later turn.
- `missingFunctionalCoachField`: question does not state why it is the right next move now, what its answer will update, or what answer is sufficient to proceed.
- `missingEvidenceGapType`: question does not classify the evidence gap.
- `missingAnswerUse`: question does not state how the answer will update judgment, action, evidence, assumption testing, or calibration.
- `missingLensMove`: question does not state the trained reasoning move.
- `missingSourceGrounding`: question cites no confirmed source card.
- `vagueCalibrationTarget`: question names an abstract target such as "the user's thinking" or "this situation" instead of a concrete belief, prediction, causal explanation, or tradeoff.
- `missingSelectedLensMove`: question batch does not include the reasoning move required by the selected built-in lens.
- `missingTrainingDimensionAlignment`: question does not serve the primary training dimension or any baseline training dimension.
- `missingPrimaryTrainingDimensionFocus`: first question does not serve the primary training dimension, so the coach-led main focus is being diluted by baseline checks.
- `missingCoachTurnAlignment`: question ignores the current coach turn phase, readiness, or recommended move. For example, a `not_ready` turn that recommends evidence gathering should not accept a generic action-choice question.
- `appeasingWithoutCorrection`: question, quest, or principle flatters, reassures, validates, increases confidence without naming a missing thinking move, evidence gap, risk, repair action, action-design gap, or reusable-rule gap, or acknowledges an unresolved gap while still letting the user proceed without repair.
- `missingSystemThinkingLensMove`: question batch ignores `feedback_loop`, `delayed_effect`, and `second_order_consequence` when the selected lens is `system_thinking`.

Historical audit codes `repeatedAvoidedLensMove`, `unadjustedLensMove`, and `missingReinforcedLensMove` remain decodable, but the runtime no longer emits these method mandates from historical labels. Current generic-question and source-grounding checks remain. Question generation still checks the selected lens. The single-action service explicitly passes `requireSelectedLensMove=false`: a useful existing-record comparison may use alternative_explanation with judgment_calibration selected. This follows the current action Prompt's fit-only lens contract; it does not relax source references, action count, completion criteria, calibration target, or readiness checks. The reusable policy retains an explicit lens-alignment option for callers that require a particular method.

Selected built-in lens move mapping:

- `evidence_check`: requires `fact_interpretation_split`.
- `opposing_view`: requires `alternative_explanation`.
- `leverage_analysis`: requires `leverage_tradeoff`.
- `first_principles`: requires `constraint_decomposition`.
- `system_thinking`: requires `feedback_loop`, `delayed_effect`, or `second_order_consequence`.
- `judgment_calibration`: requires `prediction_calibration`.

Quest output can be flagged with:

- `appeasingWithoutCorrection`: quest validates the user's current judgment or confidence without naming the unresolved evidence gap, skipped tradeoff, premature conclusion, avoided responsibility, or repair action.
- `busyworkQuest`: quest looks productive but does not reduce uncertainty, test a judgment, or create a calibration signal.
- `weakCompletionCriteria`: quest completion criteria are too short or not observable enough.
- `vagueCalibrationTarget`: quest calibration target is too abstract to verify tomorrow.
- `missingSourceGrounding`: quest cites no linked confirmed card, so tomorrow's action cannot be traced back to today's evidence.
- `missingSelectedLensMove`: quest output does not include the reasoning move required by the selected built-in lens.
- `missingCoachTurnAlignment`: quest is generated while the coach turn is not ready and the user has not explicitly chosen `userOverrideProgress`.
- `missingSystemThinkingLensMove`: quest output ignores `feedback_loop`, `delayed_effect`, and `second_order_consequence` when the selected lens is `system_thinking`.

Verification output can be flagged with:

- `weakVerificationCalibrationNote`: verification has a `targetJudgment` but the calibration note does not cover the original prediction, actual evidence, evidence gained, judgment update, observable evidence or signal, and completion criteria or acceptance criteria evidence.
- `weakVerificationRecommendation`: verification has a `targetJudgment` but the recommendation does not name a next calibration action, test, or observable signal to watch.
- `missingExpectedPrinciplePracticeAssessment`: verification has a `trainingPrinciple` context but the parsed output omits the separate `expected_principle_practice_assessment` audit field.

Principle output can be flagged with:

- `appeasingWithoutCorrection`: principle turns reassurance, confidence, or an unverified lesson into a reusable rule without naming missing evidence, exceptions, trigger boundary, or action standard.
- `missingPrincipleSourceGrounding`: principle candidate cites no confirmed source card, so the reusable rule cannot be traced back to today's evidence.
- `weakPrincipleActionability`: principle candidate is grounded but still too slogan-like, lacks at least two concrete next-time actions, or has no observable success criteria.

The gate should stay conservative: it catches low-cost, high-confidence failures. Passing the gate means "not obviously bad"; it does not mean the prompt is high quality.

At runtime, `TodayAIService.generateQuestions`, `TodayAIService.generateQuests`, `TodayAIService.verifyQuest`, and `TodayAIService.extractPrinciple` run this gate after JSON parsing and before returning output to the app state machine. If the gate finds issues, the service throws `TodayAIParsingError.qualityGateFailed` with issue reason codes only. The app should treat this like a parse-quality failure and keep the step retryable rather than showing low-quality AI output or silently substituting a local decision when a model is configured.
This uses the central-decision retry path: a missing-key or model failure preserves the input and waits for a retry; only injected test/preview runs may show a labeled local fallback.

## Coach Prompt Iteration Protocol

Coach Prompt quality is iterated as a versioned evidence loop, not by casually editing copy after a single impression:

```text
attributed user feedback + runtime failures + fixed checks
-> one explicit quality hypothesis
-> versioned Prompt change
-> deterministic regression + human review
-> limited real-use comparison
-> keep, revise, or roll back
```

### Attribution And Signals

- A feedback event is stored with the active `TrainingCaseSession`.
- During `answerQuestions`, it is linked only when the visible question output's fingerprint matches a `presented` `generateQuestions` turn for that case session.
- During `reviewQuests`, it is linked only when the visible Quest output's fingerprint matches a `presented` `generateQuests` turn for that case session.
- A newer or failed `PromptRun`, a fallback result, and a response that was never presented must not receive user feedback attribution.
- During user `selectLens` override, it remains intentionally unlinked; the model diagnosis Prompt must not be blamed for a user-selected lens.
- `wrong_target`, `repetitive`, `too_abstract`, and `gave_away_answer` mark an attributed run as denied so the existing per-version runtime quality gate can see it. `useful` is recorded but never auto-accepts a Prompt version.
- Raw feedback notes and private user material are diagnostic data. They must not be sent back to a model automatically.

### Required Change Record

Every Prompt change must record, in the change description or release note:

1. the affected `PromptID` and the old/new version;
2. one falsifiable hypothesis, for example: "this change should reduce wrong-target questions for evidence-gap cases";
3. the exact failure mode and affected training phase;
4. fixed fixtures or golden examples added for that failure;
5. the expected leading signal and the rollback version.

One change should address one primary failure mode. Do not combine a tone rewrite, schema change, context-policy change, and coaching-strategy change in one version unless each is separately evaluated.

### Evaluation Gates

1. **Local gate:** parser/schema fixtures and `PromptCoachingQualityPolicy` must pass. This only proves that an output is not obviously invalid.
2. **Golden review:** run the affected fixed cases, including prior anonymized negative-feedback cases, against the target model. A human reviews whether the response targets the right training gap, asks instead of answers, avoids repetition, and produces an actionable next move.
3. **Limited comparison:** expose one version at a time and compare the same `PromptID + version` on attributed call count, runtime failure rate, empty-result rate, and all five coach-feedback values. Also inspect downstream action completion criteria and verification quality; a lower complaint rate alone is not sufficient.
4. **Decision:** keep only when the evidence improves or holds the target signal without harming another coaching constraint. Roll back to the recorded version when the target failure rises materially, repeated severe feedback appears, or the human review reveals a new safety/quality regression.

The deterministic suite is a release guard, not a claim that the live model response is high quality. Live golden evaluation is manually triggered and version-comparative; it must never become a hidden per-screen model request.

### Principle Candidate

```json
{
  "title": "string",
  "summary": "string",
  "trigger_context": "string",
  "actions": ["string"],
  "success_criteria": "string",
  "exceptions": "string",
  "source_card_titles": ["string"]
}
```

Rules:

- Principle candidate must cite confirmed card titles in `source_card_titles`; these are parsed into `PrincipleAsset.sourceCardTitles` and persisted with the principle raw payload.
- Principle candidate must include at least two concrete actions the user can do next time.
- `success_criteria` must name observable evidence, a visible artifact, owner confirmation, acceptance criteria, or another verifiable signal.
- Do not return vague slogans such as "keep clear", "be better", or "improve efficiency".
- Do not invent `source_card_titles`; use exact titles from `confirmedCards`.
- If no confirmed card supports the reusable rule, return `principle_candidate: null`.

### Project Link Candidate

```json
{
  "project_id": "string | null",
  "candidate_project_name": "string | null",
  "link_type": "evidence | blocker | decision | task | principle | risk",
  "source_type": "daily_entry | thinking_card | quest | verification | principle",
  "source_id": "string",
  "reason": "string",
  "confidence": "low | medium | high",
  "requires_user_confirmation": true
}
```

### Project Candidate

```json
{
  "candidate_project_name": "string",
  "goal": "string",
  "current_bottleneck": "string",
  "success_criteria": "string",
  "why_this_is_long_running": "string",
  "source_refs": [
    {
      "source_type": "daily_entry | thinking_card | quest | verification | principle",
      "source_id": "string"
    }
  ],
  "privacy_safe_name_required": true,
  "confidence": "low | medium | high"
}
```

Rules:

- A candidate requires at least one source ref.
- The model must explain why the issue is recurring or strategically important.
- The model must not use company-sensitive names as the candidate name.
- The client must require user confirmation before creating a Project.
- Client validator: `TodayAIResponseParser.parseProjectSuggestions(from:)` only accepts project links with user confirmation required and explicit source evidence, and only accepts new project candidates with source refs.

### Project Merge Candidate

```json
{
  "source_project_id": "string",
  "target_project_id": "string",
  "reason": "string",
  "overlapping_evidence_refs": ["string"],
  "risks_if_merged": ["string"],
  "risks_if_kept_separate": ["string"],
  "confidence": "low | medium | high"
}
```

### Project Insight

```json
{
  "project_id": "string",
  "insight_type": "progress | blocker_change | thinking_change | open_question_closed | principle_practiced | next_bet",
  "title": "string",
  "summary": "string",
  "before": {
    "text": "string",
    "source_type": "daily_entry | thinking_card | quest | verification | principle",
    "source_id": "string"
  },
  "after": {
    "text": "string",
    "source_type": "daily_entry | thinking_card | quest | verification | principle",
    "source_id": "string"
  },
  "source_refs": ["string"],
  "confidence": "low | medium | high"
}
```

Rules:

- `thinking_change` and `blocker_change` require both `before` and `after`.
- Other insight types require at least one `source_ref`.
- The model must not infer project progress from unconfirmed cards.
- Client validator: `TodayAIResponseParser.parseProjectInsights(from:)` filters invalid insights; an empty insight list is only valid when `insufficient_evidence_reason` explains what evidence is missing.

### Metric Contribution

```json
{
  "metric": "clarity | value_judgment | execution_reliability | calibration | reflection_depth",
  "direction": "positive | negative",
  "delta": 0.0,
  "title": "string",
  "reason": "string",
  "source_type": "daily_entry | thinking_card | quest | verification | principle | project",
  "source_id": "string",
  "source_daily_entry_id": "string"
}
```

Rules:

- `source_id` and `source_daily_entry_id` are required.
- `delta` must be small and explainable; suggested range is 0.05-0.30.
- Positive and negative contributions are both allowed in the same period.
- If evidence is weak or contradictory, return a candidate with a low confidence reason rather than forcing a score.

## Prompt 1: Organize Raw Input Into Cards

Purpose:

- Convert messy daily input into editable thinking cards.
- Preserve uncertainty.
- Flag possible sensitivity.
- Stream candidate cards progressively so the user can see real generation progress.

Input:

- rawText。
- sessionMode。
- optional project context。
- privacy rules。

Instruction:

```text
Organize the user's raw daily input into thinking cards.
Do not summarize into one article.
Extract concrete facts, problems, decisions, risks, ideas, communications, and tasks.
If the transcript is messy, infer likely boundaries but mark low-confidence cards.
If content may contain confidential company details, mark it as possibly_sensitive or sensitive and avoid repeating unnecessary specifics.
Return concise editable cards.
```

MVP streaming output:

`organizeCards` is the only MVP prompt that returns XML-like streaming text instead of JSON. The model must output only the following controlled tags:

- `<MINGSI_STREAM version="1">`
- `<CARD>`
- `<TYPE>`
- `<TITLE>`
- `<BODY>`
- `<IMPORTANCE>`
- `<SENSITIVITY>`
- `<CONFIDENCE>`
- `<REASON>`
- matching closing tags

Allowed values:

- `TYPE`: `fact | problem | decision | risk | idea | communication | task`
- `IMPORTANCE`: `low | medium | high`
- `SENSITIVITY`: `normal | possibly_sensitive | sensitive`
- `CONFIDENCE`: `low | medium | high`

Rules:

- Output no markdown and no explanatory text outside the tags.
- Start each candidate as soon as it is clear enough; do not wait to plan all cards before outputting the first `<CARD>`.
- Every `<CARD>` must be closed with `</CARD>`.
- Body text must not contain XML control tags. If the user's text contains angle brackets, rewrite them as plain words.
- If uncertain, still output the card with `CONFIDENCE` set to `low`.
- Prefer 2-6 cards for standard mode, 1-3 for quick mode, and 3-8 for deep mode.

Few-shot:

Input:

```text
今天开会讨论接口归属，但会前没有列清楚要确认哪些问题。会后也没有发总结。
```

Output:

```xml
<MINGSI_STREAM version="1">
<CARD>
<TYPE>problem</TYPE>
<TITLE>会议前没有定义确认事项</TITLE>
<BODY>今天的会议讨论了接口归属，但会前没有先列出必须确认的问题。</BODY>
<IMPORTANCE>high</IMPORTANCE>
<SENSITIVITY>normal</SENSITIVITY>
<CONFIDENCE>high</CONFIDENCE>
<REASON>这是影响会议效率和结论质量的流程问题。</REASON>
</CARD>
<CARD>
<TYPE>task</TYPE>
<TITLE>会后总结没有形成闭环</TITLE>
<BODY>会议结束后没有把关键结论、行动项和负责人发出，后续可能继续不清楚。</BODY>
<IMPORTANCE>medium</IMPORTANCE>
<SENSITIVITY>normal</SENSITIVITY>
<CONFIDENCE>medium</CONFIDENCE>
<REASON>这是可以在下一次会议中验证和改进的行动习惯。</REASON>
</CARD>
</MINGSI_STREAM>
```

Non-streaming compatibility:

- Tests and fallback parsers may still support the old JSON `cards` shape.
- Production MVP should prefer XML-like SSE for `organizeCards`.

## Prompt 2: Recommend Thinking Lenses

Purpose:

- Recommend one or two lenses based on confirmed cards.

Instruction:

```text
Review the confirmed cards and recommend up to two thinking lenses.
Choose lenses that improve the user's thinking quality today.
Prefer lenses that expose unclear goals, weak evidence, opportunity cost, hidden assumptions, or low-leverage execution.
Explain briefly why each lens is useful.
```

Output:

```json
{
  "recommended_lenses": [],
  "default_lens": "string"
}
```

## Prompt 3: Generate Lens Questions

The instruction excerpt below is a historical asset, retained for replay. The current 1.26.0 contract is described above and does not require multiple questions or a historically labelled method.

Purpose:

- Ask high-quality questions under one lens.

Instruction:

```text
Generate lens-specific questions from the confirmed cards.
Questions must be specific to the user's content.
Do not ask generic self-help questions.
At least one question should challenge a hidden assumption.
At least one question should connect to tomorrow's action.
Use lensFeedback verified outcomes and lensMoves when present: reinforce moves marked reinforce, make moves marked adjust more concrete, and avoid moves marked avoid.
Do not repeat a lens move that produced low-value or uncalibratable work.
Use the session mode to control depth.
```

Mode rules:

- quick: one primary question at most, with the shortest useful wording.
- standard: one primary question per request; a later request may add one repair question if the same contract remains open.
- deep: one primary question per request, with stronger scrutiny and opposing views expressed inside that question; depth never creates a questionnaire.

Output:

```json
{
  "questions": []
}
```

## Prompt 4: Generate Tomorrow Quests

The instruction excerpt below is historical. Current 1.10.0 returns exactly one main action, no side/observation quests, and uses the shared historical-evidence boundary above.

Purpose:

- Generate a small set of high-value tasks for tomorrow.

Instruction:

```text
Generate tomorrow's quests from confirmed cards and user answers.
Create exactly one main quest unless information is insufficient.
Create at most two side quests and at most one observation quest.
The main quest should target the highest-value action, not the easiest task.
Each quest must include why it matters, concrete completion criteria, expected resistance, and one reflection question.
Each quest must include calibration_target: the specific judgment, assumption, prediction, causal explanation, or tradeoff it will calibrate.
Each quest must include linked_cards with confirmed card titles from today's context; do not invent linked card titles.
Quest must carry the calibration target into tomorrow's verification.
Use lensFeedback as verified lens outcomes from previous days.
Reinforce lensMoves that produced high-value calibration evidence.
When lensFeedback says adjust, make the same lensMoves smaller, more observable, and more explicit about completion evidence.
When lensFeedback says avoid, avoid repeating quest patterns and lensMoves that were low-value, missed, or did not produce a usable calibration signal.
If information is insufficient, ask for clarification rather than inventing a task.
```

Output:

```json
{
  "main_quest": {},
  "side_quests": [],
  "observation_quest": null,
  "rejected_low_value_tasks": []
}
```

## Prompt 5: Verify Yesterday's Quest

Purpose:

- Calibrate expected value against actual execution.

Instruction:

```text
Review yesterday's quest, completion status, and actual value.
Verify Quest input includes targetJudgment when yesterday's quest had a calibration target.
Verify Quest input includes judgmentUpdate (`confirmed | adjusted | rejected`) from the user's result calibration choice.
Compare targetJudgment with actual evidence when targetJudgment is present.
Use judgmentUpdate as the user's current stance, then check whether the evidence supports that stance.
Name the observable evidence or signal that proves what actually happened.
Compare completion criteria or acceptance criteria with the evidence before judging completion quality.
Identify whether the task was well-chosen, too vague, too large, blocked, avoided, or lower-value than expected.
Do not blame the user.
Return a concise calibration note and one recommendation for today's quest design.
The calibration note must include the original prediction, actual evidence, evidence gained, judgment update, observable evidence or signal, and completion criteria or acceptance criteria evidence.
The recommendation must name the next calibration action, test, or observable signal to watch; do not return generic encouragement.
```

Output:

```json
{
  "calibration_note": "string",
  "likely_issue": "none | task_too_large | unclear_criteria | low_value | dependency_blocked | avoidance | interruption",
  "recommendation": "string"
}
```

## Prompt 6: Extract Principle Candidate

Purpose:

- Identify whether today's reflection contains one reusable action rule.

Instruction:

```text
From the confirmed cards, answers, and quest, identify at most one reusable principle.
Do not create a principle if the lesson is too situational.
The principle must be concrete enough to apply later.
Frame it as a behavior rule, not a slogan.
The principle must include at least two concrete actions the user can do next time.
The success_criteria must name observable evidence, a visible artifact, owner confirmation, acceptance criteria, or another verifiable signal.
Do not return vague slogans such as "keep clear", "be better", or "improve efficiency".
The principle must cite source_card_titles using exact titles from confirmedCards.
Do not invent source_card_titles. If no confirmed card supports the rule, return principle_candidate: null.
```

Output:

```json
{
  "principle_candidate": null
}
```

or:

```json
{
  "principle_candidate": {}
}
```

## Prompt 7: Suggest Project Links

Purpose:

- Suggest project associations from confirmed daily evidence.
- Detect when a new abstract project candidate may be useful.

Instruction:

```text
Review confirmed cards, quests, verifications, principles, and existing active projects.
Suggest at most two project links.
If no existing project fits and the evidence suggests a recurring long-running topic, propose one candidate project name.
Do not use company-sensitive names.
Only link confirmed evidence.
Do not create or merge projects automatically.
Return candidates that require user confirmation.
Do not treat repeated keywords as a project unless there is a recurring goal, blocker, decision pattern, or action standard.
```

Output:

```json
{
  "project_link_candidates": [],
  "new_project_candidates": [
    {
      "name": "string",
      "goal": "string",
      "success_criteria": "string",
      "current_bottleneck": "string",
      "source_ids": ["string"],
      "reason": "string"
    }
  ]
}
```

## Prompt 8: Generate Project Insights

Purpose:

- Produce evidence-backed project progress and thinking-change signals.
- Help Project Detail explain why a project exists and what changed.

Instruction:

```text
Review one project, its confirmed ProjectLinks, related quests, verifications, and principles.
Generate concise progress signals only when there is source evidence.
For thinking_change and blocker_change, compare an earlier source and a later source.
If evidence is insufficient, return an empty list and explain what evidence is missing.
Do not use percentages.
Do not use company-sensitive names.
```

Output:

```json
{
  "project_insights": [],
  "insufficient_evidence_reason": "string | null"
}
```

## Prompt 9: Suggest Project Merge Candidates

Purpose:

- Detect projects that may represent the same long-running topic.

Instruction:

```text
Review active projects and their evidence links.
Suggest merge candidates only when goal, current bottleneck, success criteria, or repeated evidence strongly overlaps.
Name similarity alone is not sufficient.
Explain why merging helps and what may be lost.
Never merge automatically.
```

Output:

```json
{
  "merge_candidates": []
}
```

Client validator:

- `TodayAIResponseParser.parseProjectMergeCandidates(from:)` requires valid source/target project UUIDs, distinct projects, a non-empty reason, and non-empty overlapping evidence refs.

## Prompt 10: Weekly Calibration

Current version is 1.1.0, with the original 1.0.0 preserved for rollback/replay. Weekly and monthly requests add the shared historical-evidence boundary above. Each scope keeps all saved `verifications` as source-labelled `HistoricalVerificationEvidence`, including verification/quest IDs, completion/value/judgment self-reports, reported result, assessment, and model feedback; the latest verification is also retained in compatibility summary fields. Multiple results are not collapsed into one favorable rating. An absent assessment stays unrecorded, and positive ratings or loop counts do not establish evidence sufficiency, ability growth, or method effectiveness. Missing outcomes require insufficient evidence with no scores/contributions. The separate weekly guidance request uses the same boundary and source-labelled Verification records.

Purpose:

- Generate a weekly Growth attribution report with strict evidence traceability.

Instruction:

```text
Analyze confirmed daily records and quest verifications for the week.
Produce a strict Growth attribution report.

Rules:
- Growth is an attribution ledger, not a personality test.
- Fewer than 3 complete loops: return insufficient_evidence=true.
- Every score delta must be explained by positive or negative metric_contributions.
- Every contribution MUST include source_type, source_id, and source_daily_entry_id (UUID of the daily entry).
- A contribution without source evidence must be omitted.
- Delta per contribution must be between 0.01 and 0.30.
- Avoid vague praise. Use evidence snippets.
- Include dismissed contributions from prior rounds as context only.
```

Context payload (rendered from typed `PromptContextPayload.growth`):

| Key | Type | Description |
|-----|------|-------------|
| period | string | "weekly" |
| complete_loop_count | int | number of completed daily loops |
| record_count | int | number of daily records in scope |
| evidence_summaries | string | per-scope entry/case IDs, cards, quest, explicit self-reports, full saved result/assessment/feedback, and JSON verificationRecords for every included Verification |
| previous_clarity etc. | string | previous metric scores if available |
| dismissed_contributions | string | semicolon-separated titles of previously dismissed contributions |

Output schema:

```json
{
  "insufficient_evidence": false,
  "summary": "string: one-sentence attribution summary",
  "metrics": {
    "clarity": {"value": 1.0-5.0, "delta": -1.0 to 1.0, "reason": "string"},
    "value_judgment": {"value": 1.0-5.0, "delta": -1.0 to 1.0, "reason": "string"},
    "execution_reliability": {"value": 1.0-5.0, "delta": -1.0 to 1.0, "reason": "string"},
    "calibration": {"value": 1.0-5.0, "delta": -1.0 to 1.0, "reason": "string"},
    "reflection_depth": {"value": 1.0-5.0, "delta": -1.0 to 1.0, "reason": "string"}
  },
  "metric_contributions": [
    {
      "metric": "clarity | value_judgment | execution_reliability | calibration | reflection_depth",
      "direction": "positive | negative",
      "delta": 0.01-0.30,
      "title": "string",
      "reason": "string",
      "source_type": "daily_entry | thinking_card | quest | verification | principle",
      "source_id": "UUID or string id of the source record",
      "source_daily_entry_id": "UUID of the daily entry"
    }
  ],
  "next_training_focus": "string"
}
```

Insufficient evidence output:

```json
{
  "insufficient_evidence": true,
  "summary": "string: explain what is missing",
  "metrics": {},
  "metric_contributions": [],
  "next_training_focus": "string"
}
```

Client validator:

- `TodayAIResponseParser.parseGrowthReport(from:period:completeLoopCount:)` parses report into `GrowthReportResult` containing a `MetricSnapshot` and `[MetricContribution]`.
- Contributions without valid `source_type`, `source_id`, or `source_daily_entry_id` UUID are rejected.
- Delta values are clamped to [0.01, 0.30].
- `insufficient_evidence=true` produces `MetricSnapshot(status: .insufficientEvidence)` with no numeric score display.

## Prompt 11: Monthly Growth Report

Current version is 1.1.0; 1.0.0 remains available unchanged for rollback/replay. The same historical-evidence boundary and complete per-scope verification records apply as in weekly calibration.

Purpose:

- Generate a monthly Growth attribution report comparing current period against baseline.

Instruction:

```text
Compare this month's records against baseline and early-month examples.
Produce a strict Growth attribution report.

Rules:
- Growth is an attribution ledger, not a personality test.
- Fewer than 3 complete loops: return insufficient_evidence=true.
- Every score delta must be explained by positive or negative metric_contributions.
- Every contribution MUST include source_type, source_id, and source_daily_entry_id.
- A contribution without source evidence must be omitted.
- Delta per contribution must be between 0.01 and 0.30.
- Use before/after evidence.
- Do not present scores as objective intelligence measures; present them as personal trend indicators.
```

Context payload: same as weekly calibration with period="monthly".

Output schema: identical to weekly calibration.

Client validator: same `parseGrowthReport` parser.

## Future Extension: Custom Lens Packs

## 历史兼容：明思一下单次点拨边界

当前界面中的“明思一下”已经统一进入 `MentorFeatureStore` 的会话式多轮交流。下面的 `singleNudge` 规则只保留给历史记录读取、旧数据回放，以及 Mentor 不可用时的兼容环境；新输入不再走这套单问单答 Prompt。

`singleNudge` 是历史兼容 PromptID。它只处理用户主动输入的一件当下卡点，不读取 Today 的其他事项、卡片、Quest、原则或成长数据。

- 首轮只带原卡点；换个角度和继续想一层只带原卡点、直接上一轮的问题、用户表达和当场点拨，以及 `continuation_mode`。
- `alternateAngle` 必须避开上一轮切入点；`deeper` 必须顺着用户刚才的表达再追问一层。每轮只返回一个现在能回答的问题。
- 1.1.0 使用用户语言，寻找一个高杠杆思维缺口；不提供答案、不替用户决定、不问泛泛的“你怎么看”。不得按职业推断能力、动机或刻板印象。
- 回执是简短的当场点拨。只有判断标准、假设或因果解释真的发生前后变化时才返回 `cognitive_shift`。`thinking_action` 只能是现在可做的思维动作，不是自动任务。
- 仅当材料包含可由未来事实检验的判断、预测或行动时，`transition_to_verification` 才为 true。即便为 true，也只显示“带入行动验证”；用户确认后才走已有可编辑 Today capture 路径。
- 这条流程绝不自动创建 Quest、Verification、Principle 或 MetricContribution。用户可随时“到这里”，完成后可“再明思一件”。

固定质量覆盖分两层：模板层断言 1.1.0 保留全部反护栏（不给答案、不替用户决定、拒绝“你怎么看”、单行单问号、禁止职业刻板推断、两种续问模式约束）；解析层用学生/程序员/金融语境的代表性输出固定 accept/reject 矩阵（拒绝泛问、直接给答案或建议、多问号、换行、职业刻板）。这只验证确定性质量门，不代表真实模型质量。

UI 合同：Today 页只有紧凑常驻入口，完整交互在独立 sheet。完成后隐藏“点到了/没点到/继续想一层/到这里/带入行动验证”，保留回执并只显示一个“再明思一件”。反馈选定后未选中的评价按钮立即消失；“没点到”只提供“换个角度”或“到这里”。所有触控目标不小于 44pt 并适配 Dynamic Type。

MVP ships with fixed first-party lenses. The long-term design should treat lenses as versioned prompt assets, not hardcoded UI choices.

Lens pack fields:

```json
{
  "id": "string",
  "name": "string",
  "author": "user | official | community",
  "version": "string",
  "description": "string",
  "use_cases": ["string"],
  "system_prompt": "string",
  "question_style": "socratic | first_principles | contrarian | checklist | custom",
  "safety_notes": ["string"],
  "visibility": "private | shared_link | marketplace",
  "created_at": "date",
  "updated_at": "date"
}
```

Rules:

- Custom lenses may guide questions, but cannot silently override privacy boundaries.
- Community/marketplace lenses must be copied into the user's local library before use, so later marketplace edits do not mutate past records.
- Daily records should store the lens id and version used for that session.
- First-party examples can include Socratic questioning, first principles, inversion, pre-mortem, opportunity cost, and decision journal review.


## 辅助提示的当前思考边界（2026-10-21）

`recommendGuidance` 当前 1.1.0/schema 1，保留 1.0.0 完整回退。候选触发只负责检索，不能把缺少 fact 卡片解释成用户缺证据；个人价值与一般讲解不必制造事实缺口。当前问答、AI 讲解及复盘边界分字段传入，AI 文字不是用户行为证据。用户选择停下、当前解释已覆盖提示或只会追加负担时 hold；只在确有独特且当下有用的思考动作时 show。展示冷却由实际页面 appearance 回执开始，既不代表已读，也不代表能力提升。相同完整上下文成功 show/hold 进程内复用，不缓存失败；不承诺重启后复用 hold。实现与分层验收见[提示展示报告](qa/2026-10-21-guidance-presentation/README.md)。


## 原因未知、决策依据与继续意愿（2026-10-21）

`mentorRespond` 2.14.0/schema 1，冻结 2.13.0 完整回退。不知道原因、记不清或不确定不自动解释为想结束，先看用户当前诉求；明确拒绝、停止或不想补材料仍停止追问。原因未定和是否足以作一个有限选择分开：已有明确目标、权限和相关经历时，可以给可选方案或应请求示范表达，不以查明动机/补证据作为保护个人边界的前提；也不保证沟通有效或把新线索升级为动机证明。已有解释足够、用户表示停止时不再追加任务。没有新增模型字段、本地意图关键词路由或数据库迁移。有限场景验收见[专项报告](qa/2026-10-21-mentor-uncertainty/README.md)。


## 2026-10-21：感受不覆盖请求，倾听无需训练

`mentorRespond` 2.15.0/schema 1 冻结完整 2.14.0 回退，区分情绪状态与帮助意图。疲惫、焦虑、难过不自动表示想结束；同时请求解释、比较、建议或表达示范时，简短承接后给实际帮助。明确只想被倾听时不追加分析、问题、任务或能力评价；随后主动请求帮助则按新请求继续。只有需要分析时才聚焦一个思考动作，倾听和收束不强加训练。建议使用用户明确标准，保留用户决定权；不将自述感受作为他人动机证明或人格诊断。无 schema、存储或本地情绪关键词路由变更。


### 显式片段与交流连续性 · 2026-10-21

`mentorRespond` 2.16.0/schema 1，完整冻结 2.15.0 回退。`conversation_state.usesSelectedExcerpts=true` 只标识本轮发送了显式选择的片段：原话、老师正文、老师提问分别可选，未选字段、原用户材料和内部 source_refs 不被复制。存在本轮输入时至少选一段本轮输入，不把旧选择改标为当前诉求；不存在的新输入不凭按钮生成。所有明确选择的交流组保留，仍超限则重新选择，不静默丢弃第七组以前的已选内容。

模型只能解释实际选入的内容；老师片段不是用户事实或同意，不从编号、历史轮数或指代补写未选内容。可解释时先提供有限帮助，必要澄清仍受原提问预算及停止意愿约束。选择页提供片段全文展开、明确角色与当前输入，最大辅助字号下操作纵排。元数据为可选字段，旧上下文仍可解码回放，无数据库迁移。验收范围见 [报告](qa/2026-10-21-context-selection/README.md)。


### 当前帮助请求与示范措辞（2.17.0）

修正两处遗留冲突：疲惫不再单独触发 question=null；用户主动希望用一个问题厘清标准时，仍须满足问题价值、原有材料预算与停止边界。说明正文不向用户追加追问，但引用用户原话或按请求示范给第三方的问句可以在明确引号内保留问号。示范不是已发生的事实、用户承诺或强制沟通任务，不能把实际补问藏进引号绕过预算。现有质量门仍拒绝引号外追问；JSON schema 与上下文协议不变，2.16.0 原资产完整冻结。

1.30.0 / schema 7 保留完整 1.29.0 回退和原目录 builtin.v3，突出每种透镜的对象：换位理解在双方已有表达时优先比较已知诉求与限制，不以核查动机代替换位；杠杆分析判断投入能否触及已观察瓶颈，机会成本比较被挤掉的备选价值。说明或明确结束可直接满足诉求时不制造问答，不把已知算术、重复事实变成测验。本地质量门对有完整来源、具体目标与用途字段的瓶颈因果比较使用结构接纳，不以出现特定“缺失”词汇为条件；来源错误、模糊目标及缺失用途仍拒绝。GPT 合成目标评测、原始失败、评测纠偏和复测见[专项验收](qa/2026-10-22-lens-goals/README.md)。

1.31.0 / schema 7 保留完整 1.30.0 回退。第一性原理区分“规则必须遵守”和“规则对目标是否必要/有用”：已有实际职责或目标时，核心检查学历、时长、页数等代理指标与目标的关系，不仅询问规定能否修改；不得据此建议违反保密、安全或权利约束。新增与失败原场景的复测范围分别记录。
