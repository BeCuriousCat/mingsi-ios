# Subtask 058 Progress: Project Detail Display Polish

Status: CODEX_ACCEPTED

Owner: Codex manager
Delegated implementer: not launched; resource guard blocked worker launch

PRD: `docs/subtasks/058-project-detail-display-polish-prd.md`
Claude prompt: `docs/subtasks/058-project-detail-display-polish-claude-prompt.md`
Event log: `docs/subtasks/logs/058-project-detail-display-polish-events.jsonl`
Expected raw log: `docs/subtasks/logs/058-project-detail-display-polish-claude-run.jsonl`

## Manager Setup

- Timestamp: 2026-06-06
- Source evidence: Subtask 049 real iPhone 17 screenshot matrix and findings.
- Worktree state at setup: clean.
- Resource health at setup: `codex_tree_zombies=23/20`, `total_zombies=25/80`; wrapper health warns against launching new workers.
- Current decision at setup: prepare the delegation package but do not launch Claude Code until resource health recovers.
- Acceptance-time health: `codex_direct_zombies=53/20`, `codex_tree_zombies=53/20`, `total_zombies=55/80`; wrapper still warns against launching new workers.
- Final implementation path: Codex accepted a direct manager implementation because the task was already present in the manager worktree and a new worker launch would compound the known Codex process-tree zombie leak.

## Planned Write Scope

- `Sources/Features/FeatureTabs.swift`
- `Sources/DesignSystem/Theme.swift` only if strictly needed for a local Project Detail surface treatment
- Existing focused test file only if a helper regression fits local patterns
- This progress file

## Worker Checkpoints

Claude Code was not launched, so no worker checkpoints exist.

If relaunched in a future similar slice, Claude Code must update its progress file at exactly these checkpoints after launch:

- `START`
- `RED`
- `IMPLEMENTED`
- `TARGETED_VERIFIED`
- `HANDOFF`

At `HANDOFF`, include one final status token:

- `DONE`
- `DONE_WITH_CONCERNS`
- `NEEDS_CONTEXT`
- `BLOCKED`

## Acceptance Targets

- Chinese status labels in Project Detail: accepted.
- Warmer Project Detail dark card surface: accepted through local `projectDetailSurface()` using existing design tokens.
- Empty thinking-change evidence card hidden or demoted: accepted; the section is hidden unless before/after evidence or accepted insight exists.
- Long timeline bounded with explicit show-all affordance: accepted; evidence timeline is capped until expanded.
- Long progress signals bounded with explicit show-all affordance: accepted; progress signals are capped to two rows until expanded.
- Bottom content can scroll above the floating tab bar: code uses `DS.primaryScrollBottomReserve`; dedicated bottom-scroll screenshot was not captured for this slice.
- No AppStore, persistence, prompt, parser, LLM, Keychain, or Project semantic changes: accepted.

## Current Status

- Codex direct implementation accepted.
- Claude Code was not delegated because resource health remained over the wrapper threshold.
- Source changes are display-only in `Sources/Features/FeatureTabs.swift`.
- Tests were added in `Tests/App/AppStoreStateMachineTests.swift`.
- Screenshots captured under `docs/subtasks/screenshots/058-project-detail-display-polish/`.

## Verification

Commands:

```bash
scripts/claude_delegate.sh health 058-project-detail-display-polish docs/subtasks/058-project-detail-display-polish-progress.md
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test
git diff --check
xcodebuild -project MingSi.xcodeproj -scheme MingSi -configuration Release -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Results:

- Resource health blocked delegation: `codex_direct_zombies=53/20`, `codex_tree_zombies=53/20`, `total_zombies=55/80`; `active_processes=0`.
- `AppStoreStateMachineTests`: 157 tests, 0 failures.
- `git diff --check`: passed.
- iPhone 17 Release simulator build: `BUILD SUCCEEDED`.

Screenshot evidence:

- `docs/subtasks/screenshots/058-project-detail-display-polish/01-project-detail-normal-light.png`
- `docs/subtasks/screenshots/058-project-detail-display-polish/02-project-detail-normal-dark.png`
- `docs/subtasks/screenshots/058-project-detail-display-polish/03-project-detail-long_timeline-light.png`
- `docs/subtasks/screenshots/058-project-detail-display-polish/04-project-detail-long_timeline-dark.png`
- `docs/subtasks/screenshots/058-project-detail-display-polish/05-project-detail-sparse_next_bet-light.png`
- `docs/subtasks/screenshots/058-project-detail-display-polish/06-project-detail-sparse_next_bet-dark.png`

Residual risk:

- This slice uses first-viewport screenshot evidence plus shared bottom scroll reserve. A dedicated bottom-scroll screenshot was attempted earlier but not retained because the keyboard-scroll attempt did not move the view.
- Delegation remains blocked until Codex process-tree zombie pressure is cleared or the wrapper is moved behind a supervisor that is not a direct child of the Codex app process.
