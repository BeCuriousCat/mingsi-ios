You are a bounded implementation worker for Codex. Codex owns architecture and final review.

Invoke and follow the Claude skill `codex-delegated-worker` if it is available.

## Workspace

Use the isolated worker worktree prepared by `scripts/claude_delegate.sh`.

## Git Identity

Do not commit unless Codex explicitly asks.

If you need a git identity for local inspection, use:

```bash
git config user.name "Claude Code Worker"
git config user.email "claude-code-worker@local"
```

## Read Before Editing

Read these first, using targeted `sed` / `rg` ranges rather than broad whole-file reads:

- `docs/subtasks/056-project-detail-debug-direct-entry-prd.md`
- `docs/subtasks/056-project-detail-debug-direct-entry-progress.md`
- `docs/subtasks/049-project-detail-real-simulator-visual-qa-progress.md`
- `docs/subtasks/048-project-detail-visual-smoke-readiness-findings.md`
- `Sources/App/AppStore.swift` around `visualQAProjectDetail`
- `Sources/Features/FeatureTabs.swift` around `ProjectsView` and `ProjectDetailView`
- `Tests/App/AppStoreStateMachineTests.swift` around the visual QA fixture tests

## Hard Constraints

- Use TDD for behavior changes.
- Keep the diff scoped to this subtask.
- Update `docs/subtasks/056-project-detail-debug-direct-entry-progress.md` at exactly these checkpoints:
  - `START`
  - `RED`
  - `IMPLEMENTED`
  - `TARGETED_VERIFIED`
  - `HANDOFF`
- Do not commit.
- Do not run destructive git commands.
- Do not inspect or modify unrelated dirty changes.
- SwiftUI views must not import GRDB.
- SwiftUI views must not call `LLMClient`.
- Do not edit persistence, migrations, PromptProvider, parser, LLM clients, Keychain, screenshots, project files, or unrelated docs.
- Do not create fake production data or write fixture data into persistence.
- Release builds must not reference Debug-only visual QA APIs or symbols.

## Implementation Requirements

Implement exactly the PRD:

1. Add a Debug-only direct-entry target for the existing visual QA Project Detail fixture.
2. Make `AppStore.visualQAProjectDetail()` set that direct-entry target to the fixture project id.
3. Make `applyVisualQAProjectDetailFixture()` preserve the direct-entry target.
4. Make normal stores have no direct-entry target.
5. Update `ProjectsView` so when the Debug-only direct-entry target exists and the matching `ProjectEvidenceBoardItem` exists, it pushes to `ProjectDetailView` once without manual simulator taps.
6. Keep normal `NavigationLink` behavior unchanged when there is no direct-entry target.
7. Add focused tests for the fixture direct-entry state.

## Required Verification

Run at least:

```bash
git diff --check
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test
```

If worker worktree xcodebuild is blocked by the known untracked GRDB package-path issue, record the exact blocker in `TARGETED_VERIFIED` and finish with `DONE_WITH_CONCERNS` only if the implementation and non-xcode checks are otherwise complete.

## Final Handoff

At `HANDOFF`, include exactly one status token:

- `DONE`
- `DONE_WITH_CONCERNS`
- `NEEDS_CONTEXT`
- `BLOCKED`

Also summarize:

- files changed
- tests run and result
- any concerns
