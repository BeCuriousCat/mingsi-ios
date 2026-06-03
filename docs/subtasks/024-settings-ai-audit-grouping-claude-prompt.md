# Claude Prompt: Subtask 024 Settings AI Audit Grouping

You are Claude Code working as a bounded implementation worker for Codex on MingSi / 明思.

Use the Claude skill `codex-delegated-worker` if available.

## Manager Contract

Codex remains product owner, architect, reviewer, and final verifier. You own only this bounded slice.

## Required Reading

Read first:

- `docs/subtasks/024-settings-ai-audit-grouping-prd.md`
- `docs/mvp-current-goal.md`
- `docs/mvp-stage-progress.md`
- `docs/architecture-decisions.md`
- `docs/subtasks/023-visual-smoke-audit-findings.md`

Relevant source files:

- `Sources/Features/FeatureTabs.swift`
- `Sources/App/AppStore.swift`
- `Sources/Domain/Models.swift`
- `Tests/App/AppStoreStateMachineTests.swift`

## Strict Scope

Implement only Settings AI audit list grouping/collapse.

Allowed implementation files:

- `Sources/Features/FeatureTabs.swift`
- `Tests/App/AppStoreStateMachineTests.swift` only if adding a small grouping/helper test is practical.

Allowed docs:

- `docs/subtasks/024-settings-ai-audit-grouping-progress.md`

Do not change:

- database schema or migrations
- PromptRun persistence
- LLM clients
- Today/History/Project/Growth behavior
- app icon/assets
- unrelated UI polish

## Required Behavior

- Settings AI audit card shows compact counts for total / failed / successful recent runs.
- Failed runs are grouped under a default-expanded section.
- Successful runs are grouped under a default-collapsed section.
- Group headers are tappable and show count plus chevron.
- Existing `PromptRunAuditRow` remains the row component.
- Empty state and unavailable message behavior remain unchanged.
- Refresh button remains available.

## Testing

Use TDD where practical:

- Add a pure grouping helper if needed and cover:
  - mixed runs split into failed/success groups
  - default expansion state is failure expanded, success collapsed

Run at least:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadRecentPromptRuns_loadsNewestFirstAuditRunsWithRefsAndErrors test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
git diff --check
```

## Progress File

Update `docs/subtasks/024-settings-ai-audit-grouping-progress.md` at exactly:

- START
- RED
- IMPLEMENTED
- TARGETED_VERIFIED
- HANDOFF

Final status token must be one of:

- DONE
- DONE_WITH_CONCERNS
- NEEDS_CONTEXT
- BLOCKED

Leave unrelated dirty changes alone and report them.
