# Subtask 009 Claude Progress: Growth Attribution Layer

Purpose:

- This file is the progress handshake for Claude Code delegation.
- Claude Code must update this file at the start and after each checklist step.
- Codex uses this file for low-frequency progress checks instead of polling Claude output.

Status: complete_after_codex_review

Checklist:

- [x] Read `docs/subtasks/009-growth-attribution-layer-prd.md`.
- [x] Inspect current `MetricSnapshot`, `FeatureTabs` Growth UI, and persistence patterns.
- [x] Add Growth attribution domain models.
- [x] Add Growth repository protocol and SQLite implementation.
- [x] Add `v5_growth_attribution_layer` migration.
- [x] Add validation for contribution source ids and reconstructable metric deltas.
- [x] Add persistence and migration tests.
- [x] Run `xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' test`.
- [x] Write final result and incomplete items.

Last update:

- Claude Code finished its delegated pass and reported 109 tests passing.
- Codex then reviewed the model semantics, corrected the attribution schema, and reran the full test suite.
- Final verified result: 109 tests passed, 0 failures.

## Final Result

### Changed Files (Claude pass plus Codex review)

- `Sources/Domain/Models.swift` — Added `MetricSnapshotStatus`, `GrowthMetric`, `MetricContributionStatus`, `MetricContributionDirection`, `MetricContributionSourceType`, `MetricContributionFeedback`, and evidence-backed `MetricContribution`; expanded `MetricSnapshot` with period bounds, previous/delta scores, metric reasons, contribution refs, status, loop count, and display guard.
- `Sources/Services/PersistenceCore.swift` — Added `MetricSnapshotRepository` and `MetricContributionRepository`; added SQLite implementations; added `v5_growth_attribution_layer` migration for `metric_snapshots` and `metric_contributions`; validation requires non-empty `sourceId`.
- `Tests/Services/PersistenceCoreTests.swift` — Added persistence tests for snapshot attribution fields, insufficient evidence, contribution CRUD, empty source validation, status/feedback updates, reconstruction from accepted deltas, and migration v5 columns.
- `Sources/App/AppStore.swift` — Wired live `SQLiteMetricSnapshotRepository` / `SQLiteMetricContributionRepository` and loads the latest growth snapshot on startup.
- `Sources/Features/FeatureTabs.swift` — GrowthView guards metric display behind `canDisplayScores`; shows "证据积累中" panel instead of scores when evidence is insufficient.
- `docs/subtasks/009-growth-attribution-claude-progress.md` — This file.

### Test Result

```
** TEST SUCCEEDED **
Executed 109 tests, with 0 failures (0 unexpected) in 3.088 seconds
```

### Codex Review Corrections

- Rejected Claude's initial single `ContributionStatus` model because it mixed candidate lifecycle with user feedback.
- Replaced generic `sourceIds` with explicit `sourceType`, `sourceId`, and `sourceDailyEntryId` so Growth Detail can deep-link to History evidence.
- Replaced unstructured snapshot `reasons` with `metricReasons`, contribution refs, snapshot status, loop count, and `canDisplayScores`.

### Incomplete Items (follow-up scope)

- Growth detail view (per-metric drill-down with positive/negative contribution breakdown) is not yet implemented — deferred to UI iteration.
- "Complete daily loops < 3" heuristic is represented in the snapshot domain model through `completeLoopCount`; runtime aggregation can be wired in the Growth UI/use-case pass.
