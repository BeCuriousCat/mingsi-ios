# Claude Code Prompt: Subtask 055 Visual QA Fixture Marker Activation

You are Claude Code working as a bounded implementation worker for Codex.

Use the Claude skill `codex-delegated-worker` if available.

## Read First

1. `docs/subtasks/055-visual-qa-fixture-marker-activation-prd.md`
2. `docs/subtasks/055-visual-qa-fixture-marker-activation-progress.md`
3. Targeted source ranges only:
   - `Sources/App/MingSiApp.swift`
   - `Sources/App/AppStore.swift` around `isVisualQAProjectDetailLaunch`, `visualQAProjectDetail`, and `loadsPersistedStateOnLaunch`
   - `Tests/App/AppStoreStateMachineTests.swift` around Visual QA Launch Fixture tests

Do not read broad Swift files end-to-end unless targeted ranges are insufficient.

## Task

Implement the PRD exactly.

Subtask 054 passed unit tests but failed real iPhone 17 simulator activation. Add a Debug-only marker-file activation path that Codex can control by writing a marker file into the simulator app data container before launch.

## Allowed Files

You may edit only:

- `Sources/App/AppStore.swift`
- `Sources/App/MingSiApp.swift` if needed
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/subtasks/055-visual-qa-fixture-marker-activation-progress.md`

Do not edit screenshots, 049 docs, persistence, migrations, repositories, PromptProvider, parser, LLM clients, Keychain, project files, or unrelated docs.

## Requirements

- Update the progress file with `START` before broad inspection.
- Use TDD: add/update failing tests before implementation.
- Keep fixture behavior Debug-only.
- Normal app launch behavior must remain unchanged.
- Preserve argument, env, simctl env, and UserDefaults activation.
- Add marker-file activation that is unit-testable without simulator filesystem access.
- Document the marker location in the handoff so Codex can create it with `xcrun simctl get_app_container booted com.codex.mingsi data`.
- Fixture store must still not call `loadPersistedState()` on startup.
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

Include changed files, verification commands/results, marker file path, concerns, and any manager follow-up needed.
