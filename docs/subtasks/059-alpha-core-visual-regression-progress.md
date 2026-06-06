# Subtask 059 Progress: Alpha Core Visual Regression

Status: CODEX_ACCEPTED

Owner: Codex manager
Delegated implementer: not delegated

PRD: `docs/subtasks/059-alpha-core-visual-regression-prd.md`
Claude prompt: none
Event log: none
Raw log: none

## Manager Setup

- Timestamp: 2026-06-06
- Source state: Subtask 029 safe-area/floating-tab is already visually accepted; Subtask 058 Project Detail display polish is accepted.
- Current slice: final root-tab Alpha visual regression across Today, History, Projects, Growth, and Settings.
- Reason for local implementation: user requested fast local implementation only, and the change is a small Debug-only visual QA launch harness.
- Worktree state at setup:
  - `Sources/App/AppStore.swift` modified
  - `Sources/App/MingSiApp.swift` modified
  - `Tests/App/AppStoreStateMachineTests.swift` modified
  - `docs/subtasks/screenshots/059-alpha-core-visual-regression/` untracked

## Implementation

- Added Debug-only `AppStore.resolveVisualQATab(environment:)`.
- Added Debug-only `AppStore.applyVisualQATabOverride(environment:)`.
- Added Debug-only `AppStore.shouldUseVisualQAProjectDetailFixture(...)` so root-tab screenshot automation ignores stale Project Detail marker files.
- Updated `MingSiApp` Debug startup to apply the root tab override after store creation and after Project Detail fixture application only when that fixture is intentionally active.
- Added focused AppStore tests for:
  - direct environment variable tab resolution;
  - `SIMCTL_CHILD_` environment variable tab resolution;
  - unknown tab values returning nil;
  - root tab override winning after fixture application;
  - root tab launch not being hijacked by a stale Project Detail marker.

## Verification

Commands:

```bash
git status --short
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
xcrun simctl install booted /Users/chenzewei/Library/Developer/Xcode/DerivedData/MingSi-erjzdsaapaoobtcrmiwnfyqrwdqr/Build/Products/Debug-iphonesimulator/MingSi.app
SIMCTL_CHILD_MINGSI_VISUAL_QA_TAB=<tab> xcrun simctl launch --terminate-running-process booted com.codex.mingsi MINGSI_VISUAL_QA_TAB
xcrun simctl io booted screenshot docs/subtasks/screenshots/059-alpha-core-visual-regression/<index>-<tab>-<appearance>.png
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test
git diff --check
xcodebuild -project MingSi.xcodeproj -scheme MingSi -configuration Release -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Results:

- Debug iPhone 17 simulator build: `BUILD SUCCEEDED`.
- Root-tab screenshots captured successfully in light/dark mode.
- `AppStoreStateMachineTests`: 162 tests, 0 failures.
- `git diff --check`: passed.
- Release iPhone 17 simulator build: `BUILD SUCCEEDED`.

## Screenshot Evidence

- `docs/subtasks/screenshots/059-alpha-core-visual-regression/01-current-light.png` - early Today light baseline before the final root-tab matrix recapture
- `docs/subtasks/screenshots/059-alpha-core-visual-regression/02-today-light.png`
- `docs/subtasks/screenshots/059-alpha-core-visual-regression/03-history-light.png`
- `docs/subtasks/screenshots/059-alpha-core-visual-regression/04-projects-light.png`
- `docs/subtasks/screenshots/059-alpha-core-visual-regression/05-growth-light.png`
- `docs/subtasks/screenshots/059-alpha-core-visual-regression/06-settings-light.png`
- `docs/subtasks/screenshots/059-alpha-core-visual-regression/07-today-dark.png`
- `docs/subtasks/screenshots/059-alpha-core-visual-regression/08-history-dark.png`
- `docs/subtasks/screenshots/059-alpha-core-visual-regression/09-projects-dark.png`
- `docs/subtasks/screenshots/059-alpha-core-visual-regression/10-growth-dark.png`
- `docs/subtasks/screenshots/059-alpha-core-visual-regression/11-settings-dark.png`

Visual review:

- Today light/dark launches to Today and keeps the bottom action area above the floating tab.
- History light/dark launches to History; top content stays below the Dynamic Island/status area.
- Projects light/dark launches to the Projects root tab instead of Project Detail.
- Growth light/dark launches to Growth with readable evidence-gated state.
- Settings light/dark launches to Settings; dark placeholder and disabled text are readable enough for Alpha.

## Residual Risk

- The booted simulator data container still contains prior visual QA project evidence, so Projects root screenshots show `Visual QA` fixture data. This does not invalidate the root-tab selector or layout verification, but a later "fresh user" visual pass should uninstall/erase app data before capture.
- This slice verifies first-viewport root-tab rendering. It does not replace full interactive Today core-loop walkthrough or live GLM failure-path confirmation.
