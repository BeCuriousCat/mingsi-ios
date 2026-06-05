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

- `docs/subtasks/057-project-detail-visual-qa-fixture-variants-prd.md`
- `docs/subtasks/057-project-detail-visual-qa-fixture-variants-progress.md`
- `docs/subtasks/049-project-detail-real-simulator-visual-qa-progress.md`
- `docs/subtasks/048-project-detail-visual-smoke-readiness-findings.md`
- `Sources/App/AppStore.swift` around `visualQAMarkerFileName`, `isVisualQAProjectDetailLaunch`, `visualQAProjectDetail`, and `applyVisualQAProjectDetailFixture`
- `Tests/App/AppStoreStateMachineTests.swift` around the visual QA fixture tests
- `Sources/Features/FeatureTabs.swift` around direct-entry behavior only if you believe it is strictly needed

## Hard Constraints

- Use TDD for behavior changes.
- Keep the diff scoped to this subtask.
- Update `docs/subtasks/057-project-detail-visual-qa-fixture-variants-progress.md` at exactly these checkpoints:
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
- Do not edit persistence, migrations, repositories, PromptProvider, parser, LLM clients, Keychain, screenshots, project files, or unrelated docs.
- Do not create fake production data or write fixture data into persistence.
- Release builds must not reference Debug-only visual QA APIs or symbols.
- Do not implement visual polish in this task.
- Do not change Project semantics, ProjectInsight generation, merge behavior, or evidence digest computation.

## Implementation Requirements

Implement exactly the PRD:

1. Add a Debug-only Project Detail visual QA fixture variant selector.
2. Preserve the existing activation flag/marker behavior.
3. Support stable variant ids:
   - `nil_project`
   - `minimal`
   - `normal`
   - `accepted_insight`
   - `pending_insight`
   - `merge_history`
   - `long_timeline`
   - `long_name`
   - `sparse_next_bet`
   - `generating_insight`
4. Keep `.normal` equivalent to today's accepted fixture behavior as much as possible.
5. Ensure every variant starts on Projects and exposes `visualQAProjectDetailDirectEntryProjectID`.
6. Ensure every variant produces a direct-entry Project Detail board item.
7. Ensure `nil_project` has no persisted `Project` for the direct-entry id.
8. Ensure `minimal` has 0-1 confirmed evidence links.
9. Ensure `long_timeline` has at least 10 confirmed project links.
10. Ensure `long_name` uses a long display name suitable for wrap verification.
11. Ensure `generating_insight` sets `isGeneratingProjectInsights`.
12. Add focused AppStore tests for the variant selector and variant data shapes.

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
