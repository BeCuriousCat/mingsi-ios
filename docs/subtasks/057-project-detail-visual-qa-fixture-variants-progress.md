# Subtask 057 Progress: Project Detail Visual QA Fixture Variants

Owner: Codex

Delegated implementer: Claude Code

Required PRD: `docs/subtasks/057-project-detail-visual-qa-fixture-variants-prd.md`
Required prompt: `docs/subtasks/057-project-detail-visual-qa-fixture-variants-claude-prompt.md`

## Scope

- Add Debug-only Project Detail visual QA fixture variants for the Subtask 048 screenshot matrix.
- Keep fixture data in memory only; do not modify persistence, migrations, prompts, parser, LLM, Keychain, or production semantics.
- Codex owns final screenshot capture and visual acceptance.

## Manager Setup

- Timestamp: 2026-06-06T02:48:27+0800
- Current repo source: `docs/mvp-stage-progress.md`, `docs/subtasks/049-project-detail-real-simulator-visual-qa-progress.md`, and `docs/subtasks/048-project-detail-visual-smoke-readiness-findings.md`.
- Worktree state at setup: clean.
- Resource health at setup: `codex_tree_zombies=19/20`, `total_zombies=21/80`; no active worker. Launch must re-check health before starting.
- Planned allowed source/test files: `Sources/App/AppStore.swift`, `Tests/App/AppStoreStateMachineTests.swift`; `Sources/Features/FeatureTabs.swift` only if strictly needed.
- Manager consumption rule: progress file is the conclusion source. Flow logs are retained and opened only for diagnostics.

## Checkpoints

### START

- Timestamp: 2026-06-06T03:10:00+0800
- Planned files:
  - `Sources/App/AppStore.swift`
  - `Tests/App/AppStoreStateMachineTests.swift`
- Notes:
  - Worker planned a Debug-only variant enum, selector helper, variant-aware fixture factory, and variant data-shape tests.
  - No `FeatureTabs.swift` changes expected.

### RED

- Timestamp: 2026-06-06T03:12:00+0800
- Failing test command: `xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test`
- Observed failure: expected build failures for missing `VisualQAProjectDetailVariant`, variant resolver, and variant-aware fixture APIs.

### IMPLEMENTED

- Timestamp: 2026-06-06T03:25:00+0800
- Changed files:
  - `Sources/App/AppStore.swift`
  - `Tests/App/AppStoreStateMachineTests.swift`
- Notes:
  - Worker added 10 Debug-only variant ids, variant resolver, variant-aware fixture factory, and tests.
  - Worker did not change `Sources/Features/FeatureTabs.swift`.
  - Codex manager review found two acceptance gaps after `HANDOFF`: fixture helper links did not always resolve to real History sources, and `sparse_next_bet` was not actually sparse or next-bet-derived.
  - Codex manager fixed both by making helper-created `ProjectLink` ids resolve to real fixture cards/quests, setting long-timeline cards to matching ids, and making `sparse_next_bet` use sparse project fields plus quest/task evidence.

### TARGETED_VERIFIED

- Timestamp: 2026-06-06T03:04:18+0800
- Command: `git diff --check`
- Result: passed.
- Command: `xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test`
- Result: passed in manager checkout; 153 tests, 0 failures.
- Command: `xcodebuild -project MingSi.xcodeproj -scheme MingSi -configuration Release -destination 'platform=iOS Simulator,name=iPhone 17' build`
- Result: passed.

### HANDOFF

- Timestamp: 2026-06-06T03:30:00+0800
- Status: DONE
- Summary: Claude Code delivered Debug-only Project Detail visual QA fixture variants; Codex accepted the direction after manager fixes and fresh verification. Stable ids: `nil_project`, `minimal`, `normal`, `accepted_insight`, `pending_insight`, `merge_history`, `long_timeline`, `long_name`, `sparse_next_bet`, `generating_insight`.
- Concerns:
  - Wrapper print-mode launch exited with code 75 and claimed no `HANDOFF`, even though `status` later surfaced the worker progress file with `HANDOFF/DONE`. Record as a delegation framework follow-up: print launch exit detection should use the same worker-progress conclusion source as `status`.
  - Real iPhone 17 screenshots are still required before Subtask 049 can be closed.

## Codex Acceptance

- Timestamp: 2026-06-06T03:04:18+0800
- Accepted files:
  - `Sources/App/AppStore.swift`
  - `Tests/App/AppStoreStateMachineTests.swift`
  - `docs/subtasks/057-project-detail-visual-qa-fixture-variants-prd.md`
  - `docs/subtasks/057-project-detail-visual-qa-fixture-variants-progress.md`
  - `docs/subtasks/057-project-detail-visual-qa-fixture-variants-claude-prompt.md`
  - `docs/subtasks/logs/057-project-detail-visual-qa-fixture-variants-events.jsonl`
  - `docs/subtasks/logs/057-project-detail-visual-qa-fixture-variants-claude-run.jsonl`
- Codex fixes:
  - Ensured fixture ProjectLinks resolve to actual card/quest sources in History evidence.
  - Ensured `sparse_next_bet` has sparse overview fields and derives `nextBet` from quest/task evidence.
  - Added manager tests for source resolution and sparse next-bet derivation.
- Result: accepted.
