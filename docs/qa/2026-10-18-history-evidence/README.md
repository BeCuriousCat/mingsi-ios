# 历史结果不等于思考方法有效 · 2026-10-18

历史自评曾被自动转换为思考方法的强化或避用指令：done/high 得到 reinforce，missed/low 得到 avoid，随后 Prompt 和客户端质量门要求重复或避开该方法。完成、自评价值和某次判断的实际结果都不能证明一个方法有效。本轮移除这类推断，并把完整结果和不确定状态传入后续问题、行动及成长报告。整体思考/引导改进目标继续进行。

## 复现与修复

修复前，正面自评即使配有 observed 未决、missing 或 conflicting 的评估，仍返回 reinforce。[修复前摘要](evidence/before-summary.json)记录实际反例失败，摘要明确显示 observed 仍返回 reinforce；修复后的专项覆盖三种状态。

- CoachLensLearningPolicy 改为 review_evidence / self_report_only，前者要求查看实际保存评估，后者说明旧记录没有结构化评估；不从自评补造历史判断。
- 后续 lensFeedback 按每个历史事项的透镜会话、行动和验证对应，去除重复，保留验证/事项 ID、结果原文、模型评估和完整反馈。只有本次实际选入上下文的历史 ID 进入上下文审计。
- 成长上下文按范围保留全部 Verification，不用最后一条正面自评覆盖其他结果；每条保留来源、实际结果、评估及明确的自评身份。独立周指导请求同样使用来源标识的完整结果。
- 问题 Prompt 1.25.0、行动 1.10.0、周/月成长 1.1.0 使用统一历史证据合同；保留前一版原文供回退。缺失、冲突、无法验收、判断未决必须保留，observed/met/supported 也不证明方法因果或能力提升。旧 reinforce/avoid/adjust 只是历史标签。
- 移除按历史标签强制重复/调整/避用方法的质量门，保留历史审计枚举。首轮专项 604 通过、3 条旧预期失败，见[摘要](evidence/focused-initial-summary.json)；更新这些过时预期后，专项 734 通过、零失败/跳过，见[摘要](evidence/focused-final-summary.json)。

## 实际伊莉丝调用中的客户端误拦

复用已授权 CC Switch 当前选中的伊莉丝，HTTPS Responses，模型别名 gpt-6.1-sol；别名不证明上游身份。仅固定 iPhone 17 / iOS 26.5。

第一次实际运行收到两条完整回应：问题为空；行动为用已有记录比较两次任务范围，允许记录不足，不追加测试，不以范围相近证明书面验收有效。Codex AI 阅读认为它符合这个合成场景的边界，但客户端因 alternative_explanation 与所选 judgment_calibration 标签不同而拒绝。月报请求因此没有执行。[失败摘要](evidence/live-initial-summary.json)、[实际请求和回应](evidence/live-initial/manifest.json)、[AI 内容复核](evidence/live-initial/semantic-review.json)均保留。

当前行动 Prompt 本来已规定透镜仅作适配参考。现单行动服务明确关闭强制方法标签匹配；仍检查来源、单行动、验收信号、目标判断和就绪边界。通用质量策略保留显式方法要求选项，问题生成现有当前透镜检查也未因此改变。新增回归用这条真实合成回应证明有效来源可通过，改为其他事项标题仍被拒绝。没有用改测试材料绕过真实失败。

## 最终验证

最终完整单元 **1395 通过、0 失败、8 项显式 opt-in 跳过**，见[摘要](evidence/unit-summary.json)，`/tmp/mingsi-history-evidence-full-unit-20261018.xcresult`。包含多事项历史结果对应、同一范围全部验证记录保留、新旧 Prompt 回放、旧方法标签不强制方法，以及实际行动回应的来源回归。8 项均为需显式启用的真实模型/导入测试，没有在完整回归内调用外部模型。

修复后重新执行三次合成请求，**1 条验收测试通过、0 失败/跳过**，见[执行摘要](evidence/live-final-summary.json)，`/tmp/mingsi-history-evidence-live-final-20261018.xcresult`。本轮两次运行共收到五条回应；首次失败保留，不据此计算稳定成功率。三条最终实际回应均由 Codex AI 逐条阅读：

| 场景 | 实际响应及有限认可 |
| --- | --- |
| 历史冲突但带有 done/high/reinforce 标签 | 返回空问题集，不强行重做历史方法或追加问题 |
| 用户愿意比较现有任务范围，不追加测试 | 单一范围对照行动，允许未知、不补访、不追加测试；范围相近也不证明书面验收有效；客户端实际接受 alternative_explanation |
| 三个完整循环、正面自评、均无实际结果 | 证据不足，无分数/贡献，不把记录数或自评当能力提升，也不推断下降或保持不变 |

见[完整请求/回应清单](evidence/live-final/manifest.json)和[AI 内容复核](evidence/live-final/semantic-review.json)。行动正文仍偏长，reflection_question 用两句表达同一更新，月报未来焦点仍偏训练口吻，不能据此宣称整体易用性通过。附件保存完整合成上下文、Prompt 和生产适配器归一助手信封，未留原始线上 SSE；不是人工复核、独立事实核查或稳定质量评估。独立周指导未在本轮真实调用。

Python 脚本语法检查与 `git diff --check` 通过。最终以无测试夹具参数重启正常 App；连接继续使用模拟器 Keychain 中的伊莉丝，没有重新导入或改动 CC Switch。

## 限制与后续

本轮没有 UI 修改或新的页面验收。响应正文仍有阅读负担；先前最大字号页头、VoiceOver、手机、个人日常场景和长期效果仍待验收。所选原则是否实际实践、结果重复提交和跨事项迟到响应仍需审查。结果输入仍带有“支持这个选择”的确认性引导；下一步应中性收集结果、反例和未知。旧本地成长计算仍有消费原始自评的路径，不能从生产模型上下文修复宣称所有历史计分路径都已解决。

本轮继承[结果保存/回顾修复](../2026-10-18-result-calibration/README.md)；未发布安装包，也不宣称全 App 或整体目标完成。

后续已完成中性结果输入、暂不能判断及提交/取消/迟到响应/进程内存储重试的专项修复，详见[结果输入与可靠提交](../2026-10-18-neutral-result-submission/README.md)。这只更新前述对应缺口；原则实践、旧本地成长计分和个人真实使用效果仍未完成。

所选原则实践归属已继续按行为证据独立修复并完成有限真实模型复核，见[原则行为证据](../2026-10-18-principle-practice-evidence/README.md)；未据此关闭旧计分、后台归属及真实使用效果等缺口。
