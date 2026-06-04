# Subtask 038 PRD: Growth Report Drilldown Polish

## Goal

Make the Growth report review easier to understand and audit without changing Growth semantics.

The user should be able to answer, from the Growth tab:

- whether the latest report has enough evidence;
- why a metric changed;
- how many accepted positive and negative contributions support the metric;
- which source evidence can be opened from the metric detail sheet.

## Product Principle

Growth is an attribution ledger, not a personality score.

The UI may summarize existing `MetricSnapshot` and accepted `MetricContribution` records, but it must not invent progress, causes, dates, source titles, or longitudinal conclusions that are not present in stored data.

## Scope

Allowed source files:

- `Sources/Features/FeatureTabs.swift`
- `Tests/Features/HistoryFeatureTests.swift`

Allowed documentation file:

- `docs/subtasks/038-growth-report-drilldown-polish-progress.md`

Expected implementation:

1. Add small display helpers for Growth report review copy, such as:
   - metric display name;
   - positive/negative contribution counts;
   - leading contribution summary;
   - metric reason fallback copy;
   - compact source/evidence ref labels.
2. Use those helpers in `GrowthReportReviewPanel`, `GrowthReportMetricEvidenceRow`, and/or `MetricDetailSheet`.
3. Improve report review rows so they show more than only the leading contribution title:
   - positive and negative counts remain visible;
   - strongest contribution remains visible;
   - a short reason or fallback explanation helps the user understand why the row is worth opening.
4. Improve metric detail sheet explanation so the user can see:
   - current value and previous/delta state;
   - stored metric reason when present;
   - explicit fallback text when the reason is missing but accepted contributions exist;
   - source/evidence labels on contribution rows.
5. Add focused tests for helper behavior.

## Non-Goals

- No Growth score computation changes.
- No AppStore orchestration changes.
- No persistence, migration, repository, parser, prompt, LLM, Keychain, or GLM changes.
- No new AI prompt.
- No fake data or synthetic Growth evidence.
- No simulator screenshot requirement for the worker.

## UX Requirements

Growth report review:

- If scores cannot display, keep the insufficient-evidence explanation.
- If scores can display but no accepted contributions exist, keep the empty-review explanation.
- If accepted contributions exist, each metric row should expose:
  - metric name;
  - positive and negative accepted contribution counts;
  - strongest contribution title;
  - either stored metric reason or a conservative fallback such as "根据已接受贡献归因，点击查看来源证据。"
- Row copy must wrap cleanly and stay readable in light/dark mode using existing design tokens.

Metric detail:

- Keep the existing evidence sections and source navigation behavior.
- Do not hide negative contributions.
- Do not show unsupported personality or ability claims.
- If `snapshot.metricReasons[metric.rawValue]` is empty but contributions exist, show conservative fallback copy in the reason area rather than leaving the explanation blank.

## Acceptance Criteria

- Growth report review rows use testable helpers for:
  - metric display title;
  - accepted contribution counts;
  - leading contribution selection by absolute delta;
  - reason fallback behavior.
- Metric detail can show fallback reason copy when accepted contributions exist but the snapshot has no metric reason.
- Tests cover:
  - positive/negative count summary;
  - leading contribution chooses largest absolute delta;
  - metric reason trims whitespace;
  - fallback reason appears only when reason is missing and contributions exist;
  - no fallback reason appears when there is no reason and no contributions.
- `git diff --check` passes.
- Focused tests pass.

## Verification

Worker should run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/HistoryFeatureTests test
git diff --check
```

If the worker worktree cannot run `xcodebuild` because vendored GRDB test resources are missing, report `NEEDS_CONTEXT` with the exact error instead of modifying dependencies.
