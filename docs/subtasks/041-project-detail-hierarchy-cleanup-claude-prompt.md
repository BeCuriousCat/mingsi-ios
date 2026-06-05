# Claude Code Prompt: Subtask 041 Project Detail Hierarchy Cleanup

You are Claude Code working as a bounded implementation worker for Codex on MingSi / 明思.

Use the Claude skill `codex-delegated-worker` if available.

Codex owns product judgment, architecture, final review, and final verification. You own only this scoped implementation slice.

## Read First

Read:

- `docs/subtasks/041-project-detail-hierarchy-cleanup-prd.md`
- `docs/subtasks/041-project-detail-hierarchy-cleanup-progress.md`
- `docs/subtasks/040-project-overview-hierarchy-audit-findings.md`
- `docs/mvp-current-goal.md`
- `docs/architecture-decisions.md`

Then update `docs/subtasks/041-project-detail-hierarchy-cleanup-progress.md` with `START` before broad source inspection.

## Source Inspection Rules

Do not read all of `FeatureTabs.swift` at once. Use targeted ranges:

- `Sources/Features/FeatureTabs.swift` lines 3270-3525
- `Sources/Features/FeatureTabs.swift` lines 3640-3695
- `Sources/Features/FeatureTabs.swift` lines 5010-5070
- `Tests/Features/HistoryFeatureTests.swift` lines 450-790

Use `rg` for any additional targeted lookup.

## Progress Contract

Update `docs/subtasks/041-project-detail-hierarchy-cleanup-progress.md` at exactly:

- `START`: after reading required docs and before broad source inspection.
- `RED`: after adding failing tests.
- `IMPLEMENTED`: after source changes.
- `TARGETED_VERIFIED`: after required verification.
- `HANDOFF`: final report with one status token.

At `HANDOFF`, include exactly one final status token:

- `DONE`
- `DONE_WITH_CONCERNS`
- `NEEDS_CONTEXT`
- `BLOCKED`

## Allowed Writes

Allowed:

- `Sources/Features/FeatureTabs.swift`
- `Tests/Features/HistoryFeatureTests.swift`
- `docs/subtasks/041-project-detail-hierarchy-cleanup-progress.md`

Do not edit any other file. If another file appears necessary, write `NEEDS_CONTEXT`.

Do not commit.

## Required Behavior

Implement only the accepted Subtask 040 display cleanup:

1. Fix thinking-change copy so a project with before/after evidence is not labeled `证据不足`.
2. Reduce overview placeholder noise:
   - Real project fields remain visible.
   - Missing optional project fields should not all appear as equal-weight fact lines.
   - Evidence-derived `下一步押注` and `证据缺口` remain visible only when they contain real digest values.
3. Hide `progressSignalsSection` when `digest.progressSignals` is empty.
4. Group Project Detail sections into clearer visual tiers using existing SwiftUI/DS patterns.

Do not:

- Add Project status filters.
- Add evidence timeline pagination.
- Change AppStore actions.
- Change ProjectEvidenceDigest computation.
- Change ProjectInsight generation/review behavior.
- Change merge audit behavior.
- Add persistence or migration changes.

## Tests

Use TDD. Add tests before implementation in `Tests/Features/HistoryFeatureTests.swift`.

Required tests:

- Thinking-change display helper returns `证据不足` when there is no before/after evidence.
- Thinking-change display helper returns a different headline when before/after evidence exists.
- Overview display helper includes real project fields and omits missing optional placeholders from primary fact lines.
- Overview display helper includes real digest-derived rows when available.

Prefer small internal helper structs/functions in `FeatureTabs.swift` for display copy; they should be independent of SwiftUI where practical.

## Verification

Run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/HistoryFeatureTests test
git diff --check
```

If `xcodebuild` is blocked by worker worktree infrastructure, record the exact error in `HANDOFF` and still run `git diff --check`.

## Handoff Format

At the end, update the progress file with `HANDOFF` and include:

- final status token;
- files changed;
- implementation summary;
- verification commands and results;
- any concerns or non-goals left for Codex.
