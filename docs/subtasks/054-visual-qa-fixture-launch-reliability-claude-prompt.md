# Claude Code Prompt: Subtask 054 Visual QA Fixture Launch Reliability

You are Claude Code working as a bounded implementation worker for Codex.

Use the Claude skill `codex-delegated-worker` if available.

## Read First

1. `docs/subtasks/054-visual-qa-fixture-launch-reliability-prd.md`
2. `docs/subtasks/054-visual-qa-fixture-launch-reliability-progress.md`
3. Targeted source ranges only:
   - `Sources/App/MingSiApp.swift`
   - `Sources/App/AppStore.swift` around init, visual QA fixture, and `loadPersistedState`
   - `Tests/App/AppStoreStateMachineTests.swift` around the Visual QA Launch Fixture tests

Do not read broad Swift files end-to-end unless targeted ranges are insufficient.

## Task

Implement the PRD exactly.

The real simulator currently launches with `MINGSI_VISUAL_QA_PROJECT_DETAIL` but still displays live empty Projects state. Fix the Debug-only fixture launch path so it is reliable for Subtask 049 screenshots.

## Allowed Files

You may edit only:

- `Sources/App/AppStore.swift`
- `Sources/App/MingSiApp.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/subtasks/054-visual-qa-fixture-launch-reliability-progress.md`

Do not edit screenshots, 049 docs, persistence, migrations, repositories, PromptProvider, parser, LLM clients, Keychain, project files, or unrelated docs.

## Requirements

- Update this progress file with `START` before broad inspection.
- Use TDD: add/update failing tests before implementation.
- Keep fixture behavior Debug-only.
- Normal app launch behavior must remain unchanged.
- Fixture launch must be detectable by argument and by environment variable.
- Fixture store must not be overwritten by startup persisted-state loading.
- Do not persist fixture data to SQLite.

## Verification

Run:

```bash
git diff --check
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test
```

If xcodebuild cannot run in the worker worktree due to the known GRDB worktree issue, record the exact failure in `HANDOFF` and still run `git diff --check`.

## Handoff

End with a `## HANDOFF` section in the progress file and one final status token:

- `Status: DONE`
- `Status: DONE_WITH_CONCERNS`
- `Status: NEEDS_CONTEXT`
- `Status: BLOCKED`

Include changed files, verification commands/results, concerns, and any manager follow-up needed.
