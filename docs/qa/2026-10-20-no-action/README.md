# 允许不安排行动的回顾 · 2026-10-20 / 21

继续处理明思的主要问题：产品为了走完训练闭环，可能把用户的思考变成必须完成的作业。generateQuests 1.12.0 已明确允许没有合适行动或用户拒绝时返回 `main_quest: null`，客户端却将其判为空结果。两条修改前回归均失败于 `emptyResult`，见[反例](evidence/before-summary.json)。这使正确遵守边界的模型输出反而需要用户重试。

## 当前实现，已完成本轮有限验证

当前协议只接纳显式的 `main_quest: null`、`side_quests: []`、`observation_quest: null`。缺字段、损坏的主行动、非空侧任务或隐藏观察仍报错；历史默认解析保持原先空结果行为。有效空行动直接作为模型结果，不以旧透镜/就绪度要求强行补出行动；有效非空行动的质量门不变，没有自动重发请求或改动 Prompt/模型。

新增持久化流程状态 `reviewWithoutAction`，页面提供“保存回顾，今天先到这里”和“回到复盘，查看或补充材料”。它不自动结束，不声称判断已经正确、问题已经解决，也不生成原则、验证提醒或成长贡献。辅助字号沿用本轮已修正的滚动操作区。没有行动的完成页不再声称输入已转成明日动作或展示成长快照。

保存前落盘原文、卡片和已有复盘；失败保留页面和内容，重试保存不重新请求模型。事项会保留可回看状态，有此前待验证行动则仍保持待验证；无此前行动时不伪造待验证任务。事项会话保留 `reviewWithoutAction` 供重启回看，不触发新的本地训练诊断。旧行动/结果留在原仓储，当前空行动及回到复盘的草稿保存不应删除已确认资产。新增草稿保存合并保留遗漏的非 draft 行动，显式修改同 ID 仍按当前记录保存。

## 已有证据

首轮专项 146 通过、0 失败/跳过，包括解析、服务、SQLite 保存/恢复及普通字号/最大辅助字号页面保存和返回，见[摘要](evidence/focused-initial-summary.json)。该轮尚未覆盖之后增加的保存失败与旧资产保留边界，不能代替最终验证。后续使用真实 SQLite 中断完成写入，检查重复提交锁、失败原文保留、同一模型结果重试，以及同事项旧 active/completed 行动在保存、重启、返回补充材料后仍存在。

补充边界的专项复核仍 **146 通过、0 失败/跳过**，见[复核摘要](evidence/focused-final-summary.json)。Codex AI 已打开[普通字号浅色和最大辅助字号深色截图](evidence/ui-confirm/manifest.json)：说明可完整读完；普通字号保存常驻，辅助字号操作区随正文滚动，测试实际保存并返回复盘。最大字号仍要多次滚动，不据此宣称低阅读负担或全页面无障碍通过。

之后包含完整单元与两条 UI 的联合执行虽然进程退出码为 0，Xcode 明确报告 `Failed to construct test run summaries ... mkstemp: No space left on device`；结果为 unknown、0 条可读取的测试，见[原摘要](evidence/full-unit-ui-summary.json)和[结果复核](evidence/incomplete-result-review.json)。不把它作为全部通过或零测试执行的证明。保留原结果包，移除本任务可重建缓存后，改为不重新构建、串行分开单元和 UI 复验。

一次修改前构建和两次后续构建遇到磁盘不足相关签名失败，未执行测试；还有一次新增状态未补齐 SwiftUI switch 导致编译失败，已补齐。仅移除本任务可重建缓存；将四个早期任务结果包压缩后逐文件核对 SHA256 与符号链接，成功才移除原目录，恢复路径见[存储记录](evidence/storage-recovery.json)。一次空间不足的压缩只移除了自己的未完成归档，原包保留。没有清理模拟器、用户数据或凭据。

## 最终验证与范围

分开复验的最终完整单元 **1431 通过、0 失败、11 项显式 opt-in 跳过**，见[完整单元摘要](evidence/full-unit-final-summary.json)，`/tmp/mingsi-no-action-unit-only-20261021.xcresult`。跳过的均为外部模型/导入入口；普通回归没有启用 live 或导入环境。最终两条 UI **2 通过、0 失败/跳过**，见[UI 摘要](evidence/ui-final-summary.json)，`/tmp/mingsi-no-action-ui-only-20261021.xcresult`。覆盖普通字号浅色/最大辅助字号深色的行动阅读保存及无行动保存返回。Codex AI 已打开四张最终截图，见[阅读复核](evidence/ui-final/reading-review.json)；其他行动截图的早期逐张复核见[行动清晰度报告](../2026-10-18-action-clarity/README.md)。

当前无行动样本使用隔离测试模型，未重复外部付费调用；它证明客户端遵守合同，不能证明真实模型总能正确决定不行动。跨仓储写入仍非一个原子事务，不声称进程崩溃恢复保证。未增加数据库列或迁移；新 state 原始值需当前版本读取，不承诺旧构建能够回退读取。手机、VoiceOver、长期真实材料与全 App 可用性仍未证明，总体目标继续进行。

`git diff --check` 与接入脚本语法检查通过；[凭据扫描记录](evidence/security-check.json)未检出当时所用密钥字面值或临时凭据 xctestrun。正常无夹具 App 已恢复，当前复核进程仍存活，见[启动记录](evidence/normal-launch.json)；这只证明进程存活。未发布安装包。
