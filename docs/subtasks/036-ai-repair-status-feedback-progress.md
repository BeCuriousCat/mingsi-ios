# Subtask 036 Progress: AI Repair Status Feedback Polish

Status: CODEX_ACCEPTED
Final status token: DONE

Owner: Codex manager
Delegated implementer: Claude Code

Required PRD: `docs/subtasks/036-ai-repair-status-feedback-prd.md`
Required prompt: `docs/subtasks/036-ai-repair-status-feedback-claude-prompt.md`

## Scope

- Improve per-run/per-candidate AI repair status feedback in History and Settings.
- Keep behavior display-only.
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
- Event/raw flow logs live under `docs/subtasks/logs/036-ai-repair-status-feedback-*`.
- Raw/event logs should be opened only if progress stalls, handoff is missing, or acceptance fails.
- Do not inspect or accept partial worker diffs before `HANDOFF`.

## Manager Launch Attempts

- Attempt 1: launched 2026-06-04 with `CLAUDE_DELEGATE_MAX_BUDGET_USD=30.00`; worker started and consumed GLM tokens but exited before `START` with `API Error: The socket connection was closed unexpectedly`. No source diff accepted. Prompt tightened so `START` must be written immediately after reading PRD/progress.

## Expected Worker Verification

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/HistoryFeatureTests test
git diff --check
```

If the worker touches additional tests, it must run the touched focused tests too.

---

## START

**Timestamp:** 2026-06-04
**Planned files:**
- `Sources/Features/FeatureTabs.swift` — add display helpers for repair/audit status copy
- `Tests/Features/HistoryFeatureTests.swift` — add focused tests for new helpers
- `docs/subtasks/036-ai-repair-status-feedback-progress.md` — this file

**Assumptions:**
- `HistoricalRetryCandidateStatus` is an enum with cases: pending, retrying, candidateReady, accepted, dismissed, blocked, failed.
- `PromptRun` has fields for success/failure, prompt type, and source ids.
- Existing `DS` token system provides localized strings; helpers return `String` or `Text`.

**Plan:**
1. Inspect targeted source ranges in FeatureTabs.swift and HistoryFeatureTests.swift.
2. Write failing tests first (RED).
3. Implement minimal display helpers to pass (GREEN).
4. Wire helpers into UI rows in FeatureTabs.swift.
5. Run targeted verification.
6. Hand off.

Commit permission: no.

## RED

**Timestamp:** 2026-06-04
**Command:** `xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/HistoryFeatureTests test`
**Result:** Build failed — compilation errors: `historyRepairDetail` not found on `HistoricalRetryCandidateStatus`, `PromptRunAuditOutcome` not found, `HistoryRepairSummary` not found, `PromptRun` init missing parameters. Fixed init params, confirmed RED with optional unwrapping errors on `summaryLine` before helpers existed.

## IMPLEMENTED

**Timestamp:** 2026-06-04
**Changed files:**
- `Sources/Features/FeatureTabs.swift` — added `HistoricalRetryCandidateStatus.historyRepairDetail`, `PromptRunAuditOutcome` enum, `PromptRun.auditOutcome`/`auditOutcomeLine`, `HistoryRepairSummary`
- `Tests/Features/HistoryFeatureTests.swift` — added 5 new tests for all helpers
- `docs/subtasks/036-ai-repair-status-feedback-progress.md` — this file

**Behavior implemented:**
- `historyRepairDetail`: non-empty detail/next-step string for all 7 statuses
- `PromptRunAuditOutcome`: distinguishes success, repairableFromHistory, auditOnlyFailure
- `auditOutcomeLine`: compact outcome text for each case
- `HistoryRepairSummary`: compact count summary, nil when empty
- UI wired: repair summary line in `aiRepairSection`, status/next-step in `historyRepairableRunRow`, detail line in `historicalCandidateRow`, outcome line in `PromptRunAuditRow`

## TARGETED_VERIFIED

**Timestamp:** 2026-06-04
**Command 1:** `xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/HistoryFeatureTests test`
**Result:** Executed 35 tests, 0 failures — TEST SUCCEEDED
**Command 2:** `git diff --check`
**Result:** no output (clean)

## HANDOFF

Status: DONE

Changed files:
- `Sources/Features/FeatureTabs.swift`
- `Tests/Features/HistoryFeatureTests.swift`
- `docs/subtasks/036-ai-repair-status-feedback-progress.md`

Verification:
- `xcodebuild -only-testing:MingSiTests/HistoryFeatureTests test`: 35 tests, 0 failures
- `git diff --check`: clean

Behavior implemented:
- `HistoricalRetryCandidateStatus.historyRepairDetail` — non-empty next-step string for all 7 statuses (pending, retrying, candidateReady, accepted, dismissed, blocked, failed)
- `PromptRunAuditOutcome` enum + `PromptRun.auditOutcome` / `auditOutcomeLine` — distinguishes success, repairable-from-history, audit-only failure
- `HistoryRepairSummary` — compact count summary (unresolved/reviewable/completed/problem), nil when empty
- History repair section: compact summary line when repair content exists
- Unresolved failed run rows: status/next-step line ("待生成候选" or "仅审计")
- Historical candidate rows: detail/next-step line for every status
- Settings PromptRun audit rows: compact outcome line

Handoff notes:
- Worktree had a pre-existing build issue: GRDB `Tests/` directory was missing, fixed with a symlink to the main worktree. Codex should ensure the worktree has the full GRDB vendor tree before building.
- Commit permission: no — not committing as instructed.

## Codex Acceptance

Decision: accepted with manager fix.

Accepted:

- History repair summary line.
- Status/next-step line for unresolved failed PromptRun rows.
- Candidate status detail line for every HistoricalRetryCandidate status.
- Settings PromptRun audit outcome line.
- Helper/test direction in `HistoryFeatureTests`.

Manager fix:

- Rejected the worker's `accepted` copy saying candidate cards were written into the day record. Current AppStore behavior marks the candidate accepted but does not write candidate cards into card facts in this slice.
- Changed accepted detail copy to say the result is retained as historical repair audit.
- Changed failed detail copy to avoid promising a direct retry action that the current row does not expose.
- Counted dismissed candidates as completed terminal outcomes in the History repair summary.
- Added a regression test to prevent overstating persistence behavior.

Codex verification:

- `git diff --check`: passed.
- First parallel focused-test attempt failed because a simultaneous iPhone 17 build locked Xcode's build database; this was a verification orchestration issue, not a code failure.
- Sequential rerun of `xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/HistoryFeatureTests test`: passed, 36 tests, 0 failures.
- `xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build`: passed.
