# 旧点拨来源查看验收 · 2026-10-03

## 落地行为

旧历史详情和明确带入 Mentor 的旧轮次现在可以打开“查看来源”，展示原始记录日期、原话、问题、回答与当时分析。用户原话保持原始换行和空白，模型问题、分析、变化与建议明确标为 AI；这些内容不被保存成已确认理解。

只读旧历史依据当前打开的 root 与轮次成员关系读取。新会话依据 `mentor_source_links` 和真实 timeline item 的同会话所有权读取，不能仅靠 UUID、前缀或任意历史记录存在来授权。查询仅读取请求的合法轮次及它们明确关联的两个 PromptRun；不会把整库或无关旧链当作来源。

新投影的来源链接写入原记录内容 hash，来源读取再次校验；原始正文变化时不展示不一致内容。已有无 hash 的链接保持可读，但只依赖原有所有权关系，不能宣称这些旧链接获得了历史内容签名。缺失原记录不返回原文；显式 deleted／unavailable 状态优先，版本和 hash 不符仍拒绝。单独借入的会话不拥有原旧链。

来源查看没有网络请求，不创建旧链包装，不修改原始记录或交流生命周期。没有新增数据库迁移或导出表。

## 实际验证

固定 iPhone 17 / iOS 26.5 模拟器；内存数据库和 DEBUG UI 夹具。

| 范围 | 结果 |
| --- | --- |
| LegacyNudgeAdapterTests | 8 项通过；新增选中／无关轮次隔离、真实 item 所有权、两个 PromptRun、只读及内容 hash 断言 |
| MentorFeatureStoreTests | 98 项通过；新增旧历史 → 完整链继续 → 来源读取，零模型请求、无包装副作用、原文改变拒绝及来源缺失拒绝 |
| MentorResponseParserTests | 12 项通过；新增无链接、外会话、无 owner item、hash 错误、deleted、外 root、旧无 hash 兼容和原文角色标识 |
| testDamagedLegacyHistoryOffersRoundLevelRecovery | 1 条 UI 通过；实际打开旧历史来源，返回后明确选择轮次并再次打开来源 |
| git diff --check | 通过 |

合并运行 118 项单元／集成测试与 1 条 UI 用例，0 失败／0 跳过，xcodebuild 退出码 0。结果：`/tmp/mingsi-legacy-source-20261003.xcresult`；日志：`/tmp/mingsi-legacy-source-20261003.log`。

人工查看 [旧历史来源](history-source.png) 与 [借入后的来源](borrowed-source.png)：原话、问题、回答、AI 分析与角色说明一致，返回按钮可用。

## 边界

这是来源查看与归属验证，不是旧模型分析正确性的证明。已有未签名链接没有补造历史 hash。原始来源丢失时，当前交流自身已经保存的 timeline 不在这一读取操作中删除；其他删除及备份治理仍使用既有流程。本次没有发布、没有新增 Release 构建；上一轮 Release 通过不当作本轮新改动的 Release 证据。真实数据迁移、VoiceOver、真机和正式教材／试用验收仍待完成，不能视为 M1 整体验收。
