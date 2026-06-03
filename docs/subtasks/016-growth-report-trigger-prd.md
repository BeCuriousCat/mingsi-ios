# Subtask 016: Growth Report Trigger and Evidence Gate

## Goal

把 Growth 从“本地归因快照 + 指标详情”推进到一个可操作的周/月报告入口：

```text
completed daily loops
-> evidence-gated GrowthAIService
-> saved MetricSnapshot + MetricContribution ledger
-> Growth UI report actions and status feedback
```

这个切片的目标不是做复杂月报页面，而是让用户能主动触发“周度校准 / 月度成长”，并证明报告不会在证据不足时编造分数。

## Product Rules

- Growth 是归因账本，不是人格测评。
- 少于 3 次完整闭环时不能展示分数，也不能保存无来源贡献。
- AI 生成的每条 `MetricContribution` 必须带 `sourceType`、`sourceId`、`sourceDailyEntryId`。
- 周/月报告可以覆盖当前 Growth snapshot，但必须保留证据链接。
- UI 必须明确显示生成中、证据不足、生成失败、生成完成。
- 不引入服务端，不引入账号，不做复杂图表。

## In Scope

1. AppStore behavior hardening
   - Add state for Growth report generation status.
   - Weekly/monthly generation should expose user-visible status messages.
   - Insufficient evidence result should save an insufficient snapshot but no contributions.
   - Successful AI result should persist snapshot and contributions, then refresh visible Growth state.

2. Growth UI action
   - Add compact “周度校准” and “月度成长” actions.
   - Disable or explain while generation is running.
   - Keep visual style quiet and evidence-led.

3. Tests
   - Prove weekly report with >= 3 completed loops saves snapshot and accepted contributions.
   - Prove insufficient evidence does not create contributions or display scores.
   - Prove UI-facing status changes are observable through AppStore state.

4. Delegation record
   - Add progress file.
   - Add Claude prompt file for possible external implementation/review.
   - Update `docs/agent-delegation-log.md`.

## Out of Scope

- New charting system.
- Server PromptProvider.
- Calendar/Reminder sync.
- Personality labels.
- Long-form rich monthly report layout.
- Dynamic schema-driven UI.

## Acceptance Criteria

- Growth tab exposes report generation actions.
- AppStore tests cover success and insufficient-evidence paths.
- No Growth score appears when `MetricSnapshot.canDisplayScores == false`.
- Contributions with missing source evidence remain rejected by parser/service path.
- Full test suite passes.
