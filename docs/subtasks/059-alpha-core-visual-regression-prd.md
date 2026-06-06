# Subtask 059 PRD: Alpha Core Visual Regression

Date: 2026-06-06

## Goal

Make the final Alpha root-tab visual regression repeatable on a real iPhone 17 simulator.

The current blocker is not a product flow decision. It is screenshot reliability: macOS coordinate clicks are unreliable, and stale Debug Project Detail marker files can hijack root-tab screenshots into the Project Detail fixture. This slice adds a Debug-only root tab launch selector, then captures Today, History, Projects, Growth, and Settings in light/dark mode.

## Source Evidence

- `docs/mvp-current-goal.md`
- `docs/mvp-stage-progress.md`
- `docs/subtasks/029-safe-area-floating-tab-progress.md`
- `docs/subtasks/049-project-detail-real-simulator-visual-qa-findings.md`
- `docs/subtasks/058-project-detail-display-polish-progress.md`

## Scope

Allowed source files:

- `Sources/App/AppStore.swift`
- `Sources/App/MingSiApp.swift`

Allowed test files:

- `Tests/App/AppStoreStateMachineTests.swift`

Allowed docs and artifacts:

- `docs/subtasks/059-alpha-core-visual-regression-prd.md`
- `docs/subtasks/059-alpha-core-visual-regression-progress.md`
- `docs/subtasks/screenshots/059-alpha-core-visual-regression/*.png`
- process docs that record verification and delegation decisions

Do not modify:

- Persistence, migrations, repositories, GRDB
- PromptProvider, prompt text, parser, LLM clients, Keychain
- Today, History, Projects, Growth, or Settings product semantics
- Project Detail fixture variants
- Release launch behavior

## Acceptance Criteria

- Debug launches support `MINGSI_VISUAL_QA_TAB` and `SIMCTL_CHILD_MINGSI_VISUAL_QA_TAB` for `today`, `history`, `projects`, `growth`, and `settings`.
- Unknown tab values are ignored.
- Root-tab visual QA launch wins over stale Project Detail marker files.
- The selector is guarded by `#if DEBUG`; Release launches continue through `AppStore.live()`.
- iPhone 17 Debug build succeeds.
- iPhone 17 simulator screenshots are captured for all five root tabs in light/dark mode.
- Screenshot review verifies:
  - correct root tab selected;
  - History top content stays below the Dynamic Island/status area;
  - Growth and Settings first viewport are not unusably hidden by the floating tab;
  - Projects does not get stuck in Project Detail fixture;
  - Settings dark placeholder and disabled text remain readable enough for Alpha.
- Focused AppStore tests pass.
- `git diff --check` passes.
- iPhone 17 Release simulator build passes.

## Delegation Decision

Claude Code was not delegated for this slice.

Reason:

- The user explicitly requested fast local implementation only.
- The code change is a small Debug-only test harness and simulator verification slice.
- The final value is produced by Codex running and reviewing real iPhone 17 screenshots, not by worker code volume.
