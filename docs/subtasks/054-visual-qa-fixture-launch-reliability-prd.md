# Subtask 054 PRD: Visual QA Fixture Launch Reliability

Date: 2026-06-06

## Goal

Make the Debug-only Project Detail visual QA fixture reliably activate during real iPhone 17 simulator launches so Subtask 049 can capture Project Detail screenshots.

Subtask 050 added `MINGSI_VISUAL_QA_PROJECT_DETAIL`, but Subtask 049 real simulator launch still showed the live empty Projects state. The fixture store either is not being selected from the runtime launch environment or is being overwritten by normal persisted-state loading.

## Delegation Rationale

This is suitable for Claude Code because it is a narrow Debug-only launch-fixture reliability fix with named source/test files and clear acceptance checks. Codex remains final simulator screenshot and visual acceptance owner.

## Allowed Files

Claude Code may edit only:

- `Sources/App/AppStore.swift`
- `Sources/App/MingSiApp.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/subtasks/054-visual-qa-fixture-launch-reliability-progress.md`

## Forbidden Files

Do not edit:

- SwiftUI feature views outside `MingSiApp.swift`
- persistence schema, migrations, repositories, GRDB code
- PromptProvider, prompt text, parser, LLM clients, Keychain
- screenshots or 049 findings
- unrelated docs

## Required Behavior

1. The visual QA fixture remains Debug-only.
2. Normal app launches without fixture flags still use `AppStore.live()` and still load persisted state.
3. Fixture launches must activate through at least one reliable simulator path:
   - launch argument: `MINGSI_VISUAL_QA_PROJECT_DETAIL`
   - environment variable: `MINGSI_VISUAL_QA_PROJECT_DETAIL=1` or equivalent `SIMCTL_CHILD_MINGSI_VISUAL_QA_PROJECT_DETAIL=1` passed by `simctl`
4. Fixture store must not be overwritten by `loadPersistedState()` during app startup.
5. Fixture store must continue to start on Projects and include at least one evidence-backed project plus accepted/pending insights.
6. Do not add fake production data or persist fixture data to SQLite.

## Suggested Shape

Prefer a small AppStore-level flag such as `loadsPersistedStateOnLaunch` or `isVisualQAFixture`, defaulting to normal production behavior. `MingSiApp` should only call `loadPersistedState()` when the store says it should.

Add focused tests for:

- fixture launch detection through arguments;
- fixture launch detection through environment;
- fixture store opts out of persisted launch loading;
- normal `AppStore()` or `AppStore.live()` behavior remains configured to load persisted state.

If a better minimal shape exists, use it, but keep it Debug-only where appropriate and keep production behavior unchanged.

## Acceptance Commands

Worker should run:

```bash
git diff --check
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test
```

If the worker worktree cannot resolve GRDB packages, record that concern in `HANDOFF`; Codex will rerun verification in the manager checkout.
