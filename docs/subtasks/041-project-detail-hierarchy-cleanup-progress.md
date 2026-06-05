# Subtask 041 Progress: Project Detail Hierarchy Cleanup

Status: CODEX_ACCEPTED
Timestamp: 2026-06-05

Owner: Codex manager
Delegated implementer: Claude Code

Required PRD: `docs/subtasks/041-project-detail-hierarchy-cleanup-prd.md`
Required prompt: `docs/subtasks/041-project-detail-hierarchy-cleanup-claude-prompt.md`
Expected event log: `docs/subtasks/logs/041-project-detail-hierarchy-cleanup-events.jsonl`
Expected raw log: `docs/subtasks/logs/041-project-detail-hierarchy-cleanup-claude-run.jsonl`

## Scope

- Display-only Project Detail hierarchy cleanup.
- Allowed source files:
  - `Sources/Features/FeatureTabs.swift`
  - `Tests/Features/HistoryFeatureTests.swift`
- Allowed documentation file:
  - `docs/subtasks/041-project-detail-hierarchy-cleanup-progress.md`
- No AppStore, persistence, migrations, repositories, prompt, parser, LLM, Keychain, Today, History, Growth, Settings, assets, or screenshots edits.

## Checkpoints

Claude Code must update this file at exactly:

- `START`
- `RED`
- `IMPLEMENTED`
- `TARGETED_VERIFIED`
- `HANDOFF`

At `HANDOFF`, include exactly one final status token:

- `DONE`
- `DONE_WITH_CONCERNS`
- `NEEDS_CONTEXT`
- `BLOCKED`

## START

Timestamp: 2026-06-05

Planned files:
- `Sources/Features/FeatureTabs.swift` — display helpers + section hierarchy restructure
- `Tests/Features/HistoryFeatureTests.swift` — helper unit tests

Assumptions:
- `ProjectEvidenceDigest` has `hasBeforeAfterEvidence: Bool`, `nextBet: String?`, `evidenceGapMessage: String?`, `progressSignals: [Signal]`
- `Project` has optional fields: `goal`, `successCriteria`, `currentBottleneck`
- Helpers will be internal functions/structs testable from test target
- No AppStore, persistence, or domain model changes

## RED

Timestamp: 2026-06-05

Tests added to `Tests/Features/HistoryFeatureTests.swift`:
- `testProjectThinkingChangeHeadline_returnsInsufficientEvidence_whenNoBeforeAfter`
- `testProjectThinkingChangeHeadline_returnsAwaitingInsight_whenBeforeAfterExists`
- `testProjectThinkingChangeBody_isNonEmptyInBothCases`
- `testProjectOverviewFactLines_includesRealProjectFields`
- `testProjectOverviewFactLines_omitsMissingOptionalPlaceholders`
- `testProjectOverviewFactLines_includesDigestDerivedRowsWhenAvailable`
- `testProjectOverviewFactLines_emptyWhenNoRealData`

xcodebuild blocked: `Could not resolve package dependencies: invalid custom path 'Tests' for target 'GRDBTests'` (known worktree issue).
Compilation will fail because helper functions do not exist yet.

## IMPLEMENTED

Timestamp: 2026-06-05

Changed files:
- `Sources/Features/FeatureTabs.swift` — display helpers + section hierarchy + conditional rendering
- `Tests/Features/HistoryFeatureTests.swift` — 7 new test cases for display helpers

Changes:
1. Added `ProjectOverviewFactLine` struct and `projectOverviewFactLines(...)` helper — only produces fact lines for real data, omits nil/empty placeholders.
2. Added `projectThinkingChangeHeadline(hasBeforeAfterEvidence:)` — returns `证据不足` when no evidence, `等待确认洞察` when evidence exists.
3. Added `projectThinkingChangeBody(hasBeforeAfterEvidence:)` — corresponding body copy.
4. Updated `overviewSection` to use `projectOverviewFactLines` instead of hardcoded fallback text.
5. Updated `thinkingChangeSection` to use headline/body helpers instead of always showing `证据不足`.
6. Updated `progressSignalsSection` to hide entirely when `digest.progressSignals.isEmpty` (was showing equal-weight empty state).
7. Restructured `body` into 3 visual tiers with 28pt inter-tier spacing: Primary (header/overview/signals), Secondary (insights/thinking change), Tertiary (merge audit/timeline).

## TARGETED_VERIFIED

Timestamp: 2026-06-05

- `xcodebuild`: BLOCKED — `Could not resolve package dependencies: invalid custom path 'Tests' for target 'GRDBTests'` (known worker worktree issue).
- `git diff --check`: PASSED — no trailing whitespace or merge conflict markers.

## HANDOFF

Status: DONE_WITH_CONCERNS

Changed files:
- `Sources/Features/FeatureTabs.swift`
- `Tests/Features/HistoryFeatureTests.swift`

Verification:
- `xcodebuild`: BLOCKED by GRDB worktree dependency resolution issue. Tests reference helpers that exist in source; Codex must rerun to confirm compilation and green tests.
- `git diff --check`: PASSED

Implementation summary:
- Thinking-change copy now correctly distinguishes between no evidence (`证据不足`) and evidence awaiting insight confirmation (`等待确认洞察`).
- Overview section only shows fact lines with real data; missing optional fields no longer appear as equal-weight placeholder rows.
- Progress signals section is hidden when empty, removing visual noise.
- Project Detail sections grouped into 3 visual tiers (28pt inter-tier, 18pt intra-tier).
- All behavior changes are backed by extractable, testable helper functions.
- No AppStore, persistence, domain model, or non-allowed-file changes.

Handoff notes:
- xcodebuild cannot resolve GRDB package in worker worktree. Codex must rerun `xcodebuild -only-testing:MingSiTests/HistoryFeatureTests` in main worktree to verify compilation and test results.
- The `projectOverviewFactLines` helper filters out nil/empty fields at the display layer only. Existing `ProjectEvidenceDigest` computation is unchanged.

## Codex Acceptance

Codex accepted:

- Display-only Project Detail hierarchy cleanup.
- Thinking-change copy now distinguishes insufficient evidence from evidence awaiting confirmed insight.
- Overview fact lines no longer show all missing optional fields as equal-weight placeholders.
- Empty progress signals section is hidden.
- Project Detail is grouped into three visual tiers without adding new data semantics.

Codex manager fix:

- `projectOverviewFactLines` now trims string values and omits whitespace-only values.
- `overviewSection` no longer renders an empty Overview surface when no real fact lines exist.
- Added regression coverage for trimming and whitespace-only filtering.

Codex did not accept or add:

- Project status segment filtering.
- Evidence timeline pagination.
- AppStore, persistence, migrations, repository, PromptProvider, parser, LLM, Keychain, Today, History, Growth, or Settings changes.

Codex verification in the main checkout:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/HistoryFeatureTests test
git diff --check
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Result:

- `HistoryFeatureTests` passed: 61 tests, 0 failures.
- `git diff --check` passed.
- iPhone 17 simulator build passed.

## Manager Notes

- Codex consumes this progress file first.
- Raw/event flow logs are diagnostic only.
- Codex will not inspect or accept partial worker diffs before `HANDOFF`.
- This implementation follows Subtask 040 findings; do not expand into status filters or evidence timeline pagination.
