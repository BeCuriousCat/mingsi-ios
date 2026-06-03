# Subtask 013: Growth AI Report PRD

## Goal

把 Growth 从“本地规则归因快照”推进到 MVP 可验证的 AI 辅助周/月报告能力，同时保持证据优先：

```text
History evidence
-> typed Growth context
-> weeklyCalibration / monthlyGrowth Prompt
-> strict schema parse
-> MetricSnapshot draft
-> MetricContribution candidates
-> user-visible Growth explanation
```

MVP 不需要漂亮报表生成器，但必须证明：Growth 的每个分数变化都来自可追溯证据，而不是模型泛泛评价用户。

## Current Baseline

Already implemented:

- `MetricSnapshot`
- `MetricContribution`
- SQLite repositories and migrations
- local rule-based snapshot generation
- Growth metric detail sheet
- contribution feedback: `accepted / inaccurate / dismissed`
- History deep link from contribution source
- `TodayAIResponseParser.parseMetricContributions(from:snapshotId:)`
- Prompt IDs: `weeklyCalibration`, `monthlyGrowth`

Current gap:

- `weeklyCalibration` / `monthlyGrowth` are prompt specs only.
- No AI use case assembles weekly/monthly evidence into a typed request.
- No strict report-level parser creates a `MetricSnapshot` plus contribution candidates.
- Existing local snapshot is useful fallback, not the final AI-assisted Growth report.

## Product Rules

- Growth is an attribution ledger, not a personality test.
- Fewer than 3 complete loops: return insufficient evidence, no numeric score.
- Every score delta must be explained by positive or negative `MetricContribution`.
- Every contribution must have `sourceType`, `sourceId`, and `sourceDailyEntryId`.
- A contribution without source evidence must be rejected.
- AI can create draft/candidate contributions; accepted trend requires validator and/or user review.
- User feedback `inaccurate` or `dismissed` must be included in future report context.
- Growth context must not be injected into `organizeCards`, `generateQuestions`, or `generateQuests` in MVP.

## In Scope

1. Prompt schema hardening
   - Define explicit weekly and monthly JSON schemas in `docs/prompt-spec.md`.
   - Include `insufficient_evidence`, `summary`, metric values, deltas, reasons, contribution arrays, and `next_training_focus`.

2. Parser
   - Add parser coverage for report-level response:
     - valid weekly report -> `MetricSnapshot` + `[MetricContribution]`
     - insufficient evidence -> `MetricSnapshot(status: .insufficientEvidence)` and no numeric display
     - missing source refs -> reject invalid contribution
     - delta clamp remains explainable and conservative

3. Service/use case boundary
   - Add a Growth report generation use case behind existing service boundaries.
   - Prefer a separate `GrowthAIService` or clearly separated extension rather than bloating `AppStore`.
   - Use `PromptProvider` and `LLMClient`, not direct GLM calls from UI.
   - Use structured context payload or a typed Growth context object that can later move to `PromptContextPayload.growth`.

4. AppStore integration
   - Add a single intent-style method, e.g. `generateWeeklyGrowthReport()` or equivalent.
   - Persist `MetricSnapshot` and `MetricContribution` through repositories.
   - On AI failure, keep current local snapshot and show retryable failure state.

5. Tests
   - Parser tests for valid, insufficient, and invalid source cases.
   - AppStore/service tests proving evidence refs are passed and persisted.
   - Existing full test suite must pass.

## Out of Scope

- New Growth page redesign.
- Charts.
- Server PromptProvider.
- Embedding retrieval.
- Personality profiling.
- Automatically changing Today task generation based on Growth score.
- Project insight generation.

## Suggested Files

Likely touched:

- `Sources/Services/CoreProtocols.swift`
- `Sources/Services/TodayAIService.swift` or new `Sources/Services/GrowthAIService.swift`
- `Sources/Services/TodayAIResponseParser.swift`
- `Sources/App/AppStore.swift`
- `Tests/Services/TodayAIResponseParserTests.swift`
- `Tests/Services/TodayAIServiceContextTests.swift` or new Growth service tests
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/prompt-spec.md`
- `docs/prompt-context-engineering-prd.md`

Avoid touching:

- Today UI unless only adding a button later.
- Persistence migrations unless the existing schema cannot represent the report.
- Project UI/data.

## Acceptance Criteria

- AI weekly/monthly report generation is behind protocol/service boundaries.
- Report parser rejects unsupported Growth claims without evidence ids.
- Insufficient evidence is represented explicitly and does not show numeric scores.
- Generated `MetricContribution` records persist with `sourceDailyEntryId`.
- User can still rely on local fallback snapshot if AI fails.
- All tests pass:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' test
```

## Delegation Notes

This is suitable for Claude Code after Subtask 012 finishes because it is mostly service/parser/test work and should not conflict with UI polish if kept scoped.
