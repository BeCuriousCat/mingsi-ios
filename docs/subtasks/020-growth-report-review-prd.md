# Subtask 020: Growth Report Review PRD

## Goal

把 Growth 报告从“生成后只显示一句状态”推进为可审查的证据结果：

```text
latest MetricSnapshot
-> accepted MetricContribution ledger
-> report review panel
-> metric detail / history evidence drilldown
```

用户必须能在 Growth 首页回答：

- 最近生成的是周报还是月报？
- 这份报告基于多少次完整闭环？
- 哪些指标在变好或变差？
- 哪些证据贡献了加分或减分？
- 下一步应该训练什么？

## Product Rules

- Growth 是归因账本，不是人格标签。
- 报告审查只能展示已接受、未被用户标记不准确/忽略、且有 sourceId 的贡献。
- 证据不足时展示积累状态，不展示分数或“进步叙事”。
- 不新增数据库表；使用 `MetricSnapshot` 与 `MetricContribution`。
- 不引入图表库、动态 Schema UI、复杂动画或服务端。

## In Scope

1. AppStore state
   - 加载最新 `MetricSnapshot` 后，同时加载该 snapshot 的可审查贡献。
   - 提供按 metric 聚合的 accepted contributions，供 Growth 首页和详情页复用。
   - 生成周/月报告成功后，Growth 首页立即展示报告贡献摘要。

2. Growth UI
   - 在 Growth 首页新增“最近报告审查”面板。
   - 面板展示 period、completeLoopCount、positive/negative contribution count、nextTrainingFocus。
   - 面板按指标列出有证据的贡献摘要，点击可进入对应 Metric Detail。
   - 空状态必须解释为什么没有报告证据，而不是显示假数据。

3. Tests
   - AppStore 加载最新 Growth snapshot 时，会加载该 snapshot 的 accepted review contributions。
   - 用户将贡献标记为不准确后，报告审查列表会刷新并排除该贡献。
   - 生成报告成功后，审查贡献立即可见。

4. Docs
   - 更新 gap audit / task breakdown 状态。
   - 更新 delegation log：本切片由 Codex 直接实现，Claude Code 暂不委派。

## Out of Scope

- 新建 GrowthReport 模型或迁移。
- 长文月报页面。
- 趋势折线图。
- 权重算法重写。
- 个性画像或性格评估。
- 跨月对比图。

## Acceptance Criteria

- Growth 首页有报告审查入口，并且不显示无证据结论。
- 最新报告的贡献在 AppStore 加载后可用于 UI。
- Metric Detail 仍能从报告摘要进入，并能跳转历史证据。
- 标记贡献“不准确”后，首页报告审查和详情页都不再把它当作已接受证据。
- Targeted AppStore tests pass.
- Related Growth/AppStore/Persistence tests pass.
- Full suite passes before claiming completion.
