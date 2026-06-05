# Subtask 050 PRD: Project Detail Visual QA Launch Fixture

Date: 2026-06-06

## Goal

Add a Debug/UITest-only launch fixture that lets Codex open MingSi directly into Projects with evidence-backed Project Detail data for real iPhone 17 screenshot verification.

This is a verification harness, not a product feature.

## Context

Subtask 049 proved:

- iPhone 17 build/install/launch works.
- Projects empty state can be screenshot-tested.
- Current simulator data has no Projects, so Project Detail is not reachable through normal state.
- `simctl` has no tap command and macOS coordinate clicking is unreliable because Simulator may not expose a foreground window.

Subtask 048 identified Project Detail visual risks that still require real screenshots.

## Required Behavior

When launched with a Debug-only argument such as:

```text
MINGSI_VISUAL_QA_PROJECT_DETAIL
```

the app should:

- use an in-memory `AppStore` fixture, not live SQLite persistence;
- start on the Projects tab;
- include at least one project with confirmed source-linked evidence;
- include enough history records/project links to render Project Detail overview, progress signals, evidence timeline, merge audit, and accepted project insight states;
- preserve normal production launch behavior when the argument is absent.

## Allowed Files

- `Sources/App/MingSiApp.swift`
- `Sources/App/AppStore.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/subtasks/050-project-detail-visual-qa-launch-fixture-progress.md`

## Forbidden Files

- `Sources/Services/PersistenceCore.swift`
- migrations or schema files
- PromptProvider / prompt text
- LLM clients
- parser files
- Keychain
- project files
- screenshots
- unrelated docs

## Architecture Constraints

- The fixture must be compiled or activated only for Debug/UITest style launches.
- It must not insert fixture data into SQLite.
- It must not change repository contracts or production persistence behavior.
- It must use existing domain models: `DailyEntryDraft`, `ThinkingCard`, `Quest`, `Project`, `ProjectLink`, `ProjectInsight`, `HistoryRecord`.
- SwiftUI views must still consume state through `AppStore`.

## Acceptance Tests

Worker must run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test
git diff --check
```

Codex will rerun focused tests and iPhone 17 build before acceptance.

## Acceptance Criteria

- A launch argument can build a visual QA fixture store.
- Without the launch argument, app startup still uses `AppStore.live()`.
- Fixture store starts on Projects and has at least one evidence-backed project item.
- Focused tests cover both argument and non-argument behavior.
- No production persistence, prompt, parser, LLM, Keychain, or migration behavior changes.

