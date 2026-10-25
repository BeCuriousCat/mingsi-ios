# 女娲／仓颉与明思书籍透镜：源码调研

日期：2026-10-25。通过已认证的GitHub CLI读取仓库、固定提交的SKILL、脚本、schema及样例。这里只把外部SKILL当研究材料，没有安装、执行其工作流或调用付费模型。明思核对基于77fe766。

## 1. 找到的项目

| 项目 | 核对版本／提交 | 源码展示的用途 | 对明思的判断 |
| --- | --- | --- | --- |
| [女娲 alchaincyf/nuwa-skill](https://github.com/alchaincyf/nuwa-skill) | SKILL 1.0.0；7c7edfeb9d90a28b1f79e7847e1ba27a698cdc24 | 从人物材料提炼心智模型、决策启发式、表达特征、反模式和诚实边界；本地一手材料优先，也有网络研究路径 | 借鉴方法区分、失败模式与边界；不把人物口吻、虚构自传或完整人设带进明思 |
| [仓颉 kangarooking/cangjie-skill](https://github.com/kangarooking/cangjie-skill) | SKILL 2.5.0；a28de55ba881b9928956a55048f743f7a9e3b23e | 从书籍／视频／播客文本提炼能力，来源／执行／增益验证后形成Capability Bundle，再编译Skill | 最符合“书→方法→透镜”；建议采用其内容生产方法与Bundle边界 |
| [另一同名仓颉 Yeadon8888/cangjie-skill](https://github.com/Yeadon8888/cangjie-skill) | 3cc1e6906249849fc66b976ecce7820c06c7f46f | 基于女娲的人物认知材料提炼，强调形成故事、决策与失败经验 | 名字相同但产品方向不同，不与拆书仓颉混同；README中的比较分数是作者报告，未在明思复现 |

三个仓库固定提交的LICENSE均为MIT。工具许可不代表原书文本、译文、插图或上游样例中的素材都能随明思再分发。明思若复制或改写实质性工具／提示词内容，应保留对应MIT许可及归属。

## 2. 仓颉实际具备什么

以下链接固定提交，避免main更新后无法对应结论：

- [SKILL.md](https://github.com/kangarooking/cangjie-skill/blob/a28de55ba881b9928956a55048f743f7a9e3b23e/SKILL.md)：要求取得实际文本，明确不凭模型记忆拆书；先整书理解，再做框架／原则／案例／反例／术语提取、验证、能力晋级、评测与交付。
- [cangjie.py第1–15行](https://github.com/kangarooking/cangjie-skill/blob/a28de55ba881b9928956a55048f743f7a9e3b23e/scripts/cangjie.py#L1)：CLI明确只做确定性编排，蒸馏仍由Agent完成；compile接受已验证Bundle，**不是书名输入后自动读全书的模型服务**。
- [Capability schema](https://github.com/kangarooking/cangjie-skill/blob/a28de55ba881b9928956a55048f743f7a9e3b23e/schemas/capability.schema.json)：稳定capability_id、revision、intents、keywords、能力卡、source_evidence和promotion；可携带显式resources，包括脚本。source_evidence不是该schema的必填项，明思发布门必须更严格地要求来源。
- [Bundle schema](https://github.com/kangarooking/cangjie-skill/blob/a28de55ba881b9928956a55048f743f7a9e3b23e/schemas/capability-bundle.schema.json)：一份事实源可以生成single或pack；输出形态不等于方法数量。
- [独立Skill晋级门](https://github.com/kangarooking/cangjie-skill/blob/a28de55ba881b9928956a55048f743f7a9e3b23e/methodology/03b-stage1.6-promotion-gate.md)：知识有效与值得新增入口是两道门；未晋级内容可保留为路由能力或参考，避免入口泛滥。
- [输出评测脚本](https://github.com/kangarooking/cangjie-skill/blob/a28de55ba881b9928956a55048f743f7a9e3b23e/scripts/run_output_evals.py)：prepare生成匿名任务，score检查已有输出、JSON、数值等；脚本本身不替宿主调用模型或证明用户获益。
- [触发评测脚本](https://github.com/kangarooking/cangjie-skill/blob/a28de55ba881b9928956a55048f743f7a9e3b23e/scripts/run_trigger_evals.py)：生成任务包并计算已有结果；仍需要宿主执行测试。不能只跑prepare/score就称模型效果通过。
- [现有能力卡样例](https://github.com/kangarooking/cangjie-skill/blob/a28de55ba881b9928956a55048f743f7a9e3b23e/books/naval-almanack-skill/.cangjie/capabilities/cards/decision-heuristics.md)：确有可阅读产物；本次仅检查其结构，不将样例的原文、观点或评测分数视作已获得明思发布许可和效果验收。

## 3. 女娲可借鉴的部分

- [固定SKILL](https://github.com/alchaincyf/nuwa-skill/blob/7c7edfeb9d90a28b1f79e7847e1ba27a698cdc24/SKILL.md)：区分“怎么想”与名言合集，要求反模式、局限及来源；也包含表达DNA和人物化输出，后两者不适合直接成为明思系统人格。
- [提取框架](https://github.com/alchaincyf/nuwa-skill/blob/7c7edfeb9d90a28b1f79e7847e1ba27a698cdc24/references/extraction-framework.md)：可参考心智模型、启发式及失效情境的组织。
- [quality_check.py](https://github.com/alchaincyf/nuwa-skill/blob/7c7edfeb9d90a28b1f79e7847e1ba27a698cdc24/scripts/quality_check.py)：多项检查依赖标题、数量、关键词和正则；格式通过不等于来源属实、方法有效或改善实际判断。

## 4. 明思现有接点与缺口

| 接点 | 当前源码证据 | 能复用什么／必须补什么 |
| --- | --- | --- |
| 透镜对象 | Sources/Domain/Models.swift：LensCatalogItem、LensAssetPack、LensLibrary | 已有目的、方法、问题策略、适用／禁用条件和包版本；缺书籍身份、定位、编辑身份与发布范围 |
| 运行时资产 | Sources/App/AppStore.swift：loadLensAssetPacks、importLensAssetPack、runtimeLensItems | 已有导入、持久化、启停和运行时列表；不需另做整套插件市场 |
| 外部包校验 | Sources/Services/PersistenceCore.swift：SQLiteLensAssetPackRepository.validateTrustMetadata | imported／marketplace已有哈希与签名验证；不得把外部包冒充localCustom绕过。来源准确性不能由签名证明 |
| Today请求 | Sources/Services/TodayAIService.swift：structuredPayload、selectedLensItem | 能发送运行时选中方法的独立内容，不必新增ThinkingLens枚举项；需验证来源字段和快照 |
| Today可见入口 | Sources/Features/Today/TodayView.swift：selectLensSection；Models.swift：LensGroup | 当前分别遍历customLensItems和固定ThinkingLens分组，没有直接展示runtimeLensItems；不能相信“导入即出现”的设置文案，须补页面与选择链路 |
| 导师聊天 | Sources/Services/MentorContextBuilder.swift：MentorContextPayload；Sources/Features/MentorFeatureStore.swift | 有教材候选与会话来源，目前没有选中透镜快照字段；导入包不自动等于首页聊天能使用 |
| 导师来源 | Sources/Domain/MentorResponseModels.swift：MentorSourceReference；MentorSourceDetails.swift：MentorSourceResolver | 当前允许item／capture／legacy-nudge／understanding／lesson；不能直接输出未支持的book:引用，更不能将书中人物经历算用户材料 |
| 内容边界 | docs/lens-library-design.md；docs/mingsi-goal-overview.md | 一次一个有价值动作、允许停下、不强迫任务；新来源用于改善方法，不以书目数取代G4/G6/G7真人价值 |

本次没有执行上游CLI、安装依赖、生成书籍透镜、改写App、修改个人数据库或进行新的付费模型调用。因此当前结论是源码可行性判断，所有执行和效果门槛由配套Plan定义。
