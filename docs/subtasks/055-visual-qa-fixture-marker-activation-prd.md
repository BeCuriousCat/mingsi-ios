# Subtask 055 PRD: Visual QA Fixture Marker Activation

Date: 2026-06-06

## Goal

Make the Debug-only Project Detail visual QA fixture activate reliably in real iPhone 17 simulator launches after Subtask 054 still rendered the live empty Projects state.

Subtask 054 added argument, environment, and UserDefaults activation paths, and manager-side tests passed. Real simulator screenshots still showed `0 个证据项目`, so the launch trigger is still not reliable enough for Subtask 049.

## Delegation Rationale

This is suitable for Claude Code because it is a narrow Debug-only launch-fixture reliability fix with named source/test files and a concrete simulator acceptance path. Codex remains final simulator screenshot and visual acceptance owner.

## Allowed Files

Claude Code may edit only:

- `Sources/App/AppStore.swift`
- `Sources/App/MingSiApp.swift` if needed
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/subtasks/055-visual-qa-fixture-marker-activation-progress.md`

## Forbidden Files

Do not edit:

- SwiftUI feature views
- persistence schema, migrations, repositories, GRDB code
- PromptProvider, prompt text, parser, LLM clients, Keychain
- screenshots or 049 findings
- unrelated docs

## Runtime Evidence From Codex

Codex verified in the manager checkout:

- `git diff --check`: passed.
- `xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test`: passed, 122 tests, 0 failures.
- `xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build`: passed.
- Real iPhone 17 screenshots still showed live Projects empty state after:
  - `xcrun simctl spawn booted defaults write com.codex.mingsi MINGSI_VISUAL_QA_PROJECT_DETAIL -bool YES`
  - `xcrun simctl launch --terminate-running-process booted com.codex.mingsi MINGSI_VISUAL_QA_PROJECT_DETAIL`

Screenshots:

- `docs/subtasks/screenshots/049-project-detail-real-simulator-visual-qa/10-projects-fixture-top-light-userdefaults.png`
- `docs/subtasks/screenshots/049-project-detail-real-simulator-visual-qa/11-projects-fixture-top-light-current-arg.png`

## Required Behavior

1. Keep all visual QA fixture activation Debug-only.
2. Keep normal launches without fixture flags using `AppStore.live()` and loading persisted state.
3. Preserve existing activation paths:
   - launch argument `MINGSI_VISUAL_QA_PROJECT_DETAIL`
   - environment variable `MINGSI_VISUAL_QA_PROJECT_DETAIL`
   - environment variable `SIMCTL_CHILD_MINGSI_VISUAL_QA_PROJECT_DETAIL`
   - `UserDefaults.standard.bool(forKey: "MINGSI_VISUAL_QA_PROJECT_DETAIL")`
4. Add a reliable simulator-controllable marker-file activation path.
5. The marker path must be easy for Codex to create before launch using the app data container, for example:

```bash
xcrun simctl get_app_container booted com.codex.mingsi data
```

then create a marker file under a documented location inside that container.

6. The marker-file check must be unit-testable without relying on the actual simulator filesystem.
7. The fixture store must still opt out of `loadPersistedState()`.
8. Do not persist fixture data to SQLite.

## Suggested Shape

Prefer extending `AppStore.isVisualQAProjectDetailLaunch(...)` with a testable marker parameter, such as:

```swift
markerFileExists: () -> Bool = { ... }
```

or a marker URL parameter. Keep the default implementation Debug-only and local to `AppStore`.

The default marker location should be deterministic and documented in code/tests enough for Codex to create it in simulator before launch.

## Acceptance Commands

Worker should run:

```bash
git diff --check
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test
```

If the worker worktree cannot resolve GRDB packages, record that concern in `HANDOFF`; Codex will rerun verification in the manager checkout.

## Codex Acceptance

Codex will accept only after:

- manager checkout `git diff --check` passes;
- manager checkout focused AppStore tests pass;
- iPhone 17 Debug build passes;
- Codex creates the marker in the simulator app data container, relaunches the app, and captures a screenshot showing the fixture project instead of the live empty Projects state.
