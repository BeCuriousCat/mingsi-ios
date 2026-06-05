# Subtask 056 Progress: Project Detail Debug Direct Entry

Owner: Codex

Delegated implementer: Claude Code

Required PRD: `docs/subtasks/056-project-detail-debug-direct-entry-prd.md`
Required prompt: `docs/subtasks/056-project-detail-debug-direct-entry-claude-prompt.md`

## Scope

- Add a Debug-only direct-entry path for the existing Project Detail visual QA fixture.
- Keep production Projects behavior unchanged.
- Do not touch persistence, migrations, PromptProvider, parser, LLM clients, Keychain, screenshots, or unrelated docs.

## Manager Notes

- Subtask 049 remains the parent visual QA task.
- Subtask 048 supplies the screenshot matrix.
- This task only removes the navigation blocker so Codex can capture real simulator Project Detail screenshots.
- Manager review consumes this progress file first. Raw/event logs are diagnostic-only.

## Checkpoints

### START

- Timestamp: 2026-06-06T02:00Z
- Planned files:
  - `Sources/App/AppStore.swift`
  - `Sources/Features/FeatureTabs.swift`
  - `Tests/App/AppStoreStateMachineTests.swift`
- Notes:
  - Worker planned a Debug-only direct-entry property on `AppStore`.
  - Worker planned a local `NavigationStack(path:)` push inside `ProjectsView`.
  - Normal stores must keep nil direct-entry state.

### RED

- Timestamp: 2026-06-06T02:29Z
- Failing test command: `xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test`
- Observed failure:
  - Expected compile failure after worker added tests first.
  - Tests referenced missing `visualQAProjectDetailDirectEntryProjectID`.

### IMPLEMENTED

- Timestamp: 2026-06-06T02:33Z
- Changed files:
  - `Sources/App/AppStore.swift`
  - `Sources/Features/FeatureTabs.swift`
  - `Tests/App/AppStoreStateMachineTests.swift`
- Notes:
  - Added Debug-only `visualQAProjectDetailDirectEntryProjectID`.
  - Set fixture direct-entry id to the fixture project id.
  - Preserved the direct-entry id when applying fixture state.
  - Added one-shot direct-entry navigation in `ProjectsView`.
  - Added four focused AppStore tests.

### TARGETED_VERIFIED

- Timestamp: 2026-06-06T02:33Z
- Command:
  - `git diff --check`
  - `xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test`
- Result:
  - Worker reported `git diff --check` clean.
  - Worker reported AppStoreStateMachineTests passed: 132 tests, 0 failures.

### HANDOFF

- Timestamp: 2026-06-06T02:34Z
- Status: `DONE_WITH_CONCERNS`
- Summary:
  - Claude Code delivered the bounded Debug-only direct-entry implementation.
  - Changed files remained inside the allowed source/test/progress set.
  - Codex reviewed the final diff after HANDOFF and accepted the direction.
- Concerns:
  - Worker xcodebuild needed the known GRDB worktree test-resource workaround.
  - Direct-entry push timing still required real simulator verification.
  - `ProjectDetailDirectEntryTarget` is an unconditional private helper type, but Release build verification is required to confirm no Debug-only API leak.

## Codex Acceptance

- Timestamp: 2026-06-06T02:37Z
- Status: CODEX_ACCEPTED
- Accepted files:
  - `Sources/App/AppStore.swift`
  - `Sources/Features/FeatureTabs.swift`
  - `Tests/App/AppStoreStateMachineTests.swift`
  - `docs/subtasks/056-project-detail-debug-direct-entry-*`
  - `docs/subtasks/logs/056-project-detail-debug-direct-entry-*`
- Codex fixes:
  - None. Codex applied the worker diff as-is after review.
- Fresh verification:
  - `git diff --check`: passed.
  - `xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test`: passed, 132 tests, 0 failures.
  - `xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build`: passed.
  - `xcodebuild -project MingSi.xcodeproj -scheme MingSi -configuration Release -destination 'platform=iOS Simulator,name=iPhone 17' build`: passed.
  - Real iPhone 17 marker launch screenshot: `docs/subtasks/screenshots/049-project-detail-real-simulator-visual-qa/16-project-detail-direct-entry-light.png`.
- Acceptance note:
  - Screenshot confirms the app launches into Project Detail (`长期议题`) for the visual QA fixture.
  - Screenshot also confirms the known Subtask 048 status-chip risk: the header still shows English `active`; that remains a follow-up display issue, not part of 056.
