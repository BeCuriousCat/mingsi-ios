# Subtask 037 Progress: Project Merge Audit Display

Status: DONE
Timestamp: 2026-06-04T14:25Z

Planned files:
- Sources/Features/FeatureTabs.swift (display helpers + ProjectMergeCandidateReviewRow + ProjectDetailView merge audit section)
- Tests/Features/HistoryFeatureTests.swift (focused tests for helpers)

Assumptions:
- mergeHistory is [String], stored as-is from AppStore line 3672
- overlappingEvidenceRefs is [String] on ProjectMergeCandidate
- Display helpers will be internal free functions in FeatureTabs.swift so @testable import can reach them
- No schema or behavior changes

Final status token: DONE

Owner: Codex manager
Delegated implementer: Claude Code

Required PRD: `docs/subtasks/037-project-merge-audit-display-prd.md`
Required prompt: `docs/subtasks/037-project-merge-audit-display-claude-prompt.md`

## Scope

- Improve display-only Project merge audit clarity.
- Keep Project merge behavior unchanged.
- Do not change AppStore orchestration, persistence, migrations, PromptProvider, LLM clients, parser, Keychain, or retry semantics.

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

## Manager Notes

- Codex consumes this progress file first.
- Event/raw flow logs live under `docs/subtasks/logs/037-project-merge-audit-display-*`.
- Raw/event logs should be opened only if progress stalls, handoff is missing, or acceptance fails.
- Do not inspect or accept partial worker diffs before `HANDOFF`.

## RED

Timestamp: 2026-06-04T14:15Z
Command: `xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/HistoryFeatureTests test`
Result: Build fails — `Cannot find 'mergeAuditDisplayLines' in scope`, `Cannot find 'candidateEvidenceSummary' in scope`, `Cannot find 'candidateConsequenceLine' in scope`
Note: Worktree needed GRDB Tests restored from main repo (gitignored vendor content) to resolve SPM.

## IMPLEMENTED

Timestamp: 2026-06-04T14:20Z

Changed files:
- `Sources/Features/FeatureTabs.swift` — added `mergeAuditDisplayLines(from:)`, `candidateEvidenceSummary(_:)`, `candidateConsequenceLine()`, `mergeAuditDisplayLinesIfNonEmpty(from:)` helpers; updated `ProjectMergeCandidateReviewRow` to use helpers and added consequence line; added `mergeAuditSection` to `ProjectDetailView`
- `Tests/Features/HistoryFeatureTests.swift` — added 6 focused tests for merge audit display helpers

Summary:
- `mergeAuditDisplayLines(from:)` filters empty/whitespace-only entries and trims surrounding whitespace
- `candidateEvidenceSummary(_:)` returns "N 条证据" for empty refs, "N 条证据：preview" for non-empty
- `candidateConsequenceLine()` returns "目标议题保持活跃；源议题归档；已有证据链接保留。"
- `ProjectMergeCandidateReviewRow` now shows evidence summary and consequence line, replaces inline evidence preview
- `ProjectDetailView` shows `合并审计` section only when `project.mergeHistory` has non-empty trimmed lines

## TARGETED_VERIFIED

Timestamp: 2026-06-04T14:25Z
Commands:
- `xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/HistoryFeatureTests test` — 42 tests passed, 0 failures
- `git diff --check` — clean, no whitespace issues

## HANDOFF

Status: DONE

Changed files:
- Sources/Features/FeatureTabs.swift
- Tests/Features/HistoryFeatureTests.swift

Verification:
- xcodebuild HistoryFeatureTests: 42 passed, 0 failures (36 existing + 6 new)
- git diff --check: clean

Implementation summary:
- Added 4 internal display helpers for merge audit copy
- Updated ProjectMergeCandidateReviewRow with consequence line and evidence summary from helpers
- Added 合并审计 section to ProjectDetailView (conditionally shown)
- 6 focused tests cover: empty history, whitespace-only, trim+preserve, evidence count+refs, empty refs, consequence line correctness

Handoff notes:
- Worktree needed GRDB Tests (gitignored) copied from main repo to resolve SPM. This is a worktree infrastructure issue, not a dependency change.
- No behavior changes to AppStore, persistence, migrations, prompts, or LLM clients.

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/HistoryFeatureTests test
git diff --check
```

If the worker touches additional tests, it must run the touched focused tests too.

## Codex Acceptance

Decision: accepted.

Accepted:

- Display-only helper direction.
- `ProjectMergeCandidateReviewRow` consequence/evidence copy.
- Conditional `合并审计` section in `ProjectDetailView`.
- Focused helper tests in `HistoryFeatureTests`.

Codex review notes:

- No AppStore, persistence, migration, PromptProvider, LLM, parser, Keychain, or Growth semantic changes were present.
- The worker initially surfaced `Status: DONE` before the status command showed a formal `HANDOFF` section; Codex waited until the worker progress contained `## HANDOFF` before inspecting and accepting the final diff.

Codex verification:

- `xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/HistoryFeatureTests test`: passed, 42 tests, 0 failures.
- `git diff --check`: passed.
- `xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build`: passed.
