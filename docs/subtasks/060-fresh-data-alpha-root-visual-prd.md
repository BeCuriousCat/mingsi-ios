# Subtask 060 PRD: Fresh Data Alpha Root Visual Pass

Date: 2026-06-06

## Goal

Close the Subtask 059 residual risk by repeating the root-tab Alpha visual pass after clearing the app data container on the booted iPhone 17 simulator.

Subtask 059 proved deterministic root-tab screenshot automation, but Projects still showed prior visual QA project evidence because the simulator data container was not clean. This slice captures the same root tabs from a freshly reinstalled app so Alpha visual evidence is not contaminated by old QA fixture records.

## Source Evidence

- `docs/subtasks/059-alpha-core-visual-regression-progress.md`
- `docs/verification-log.md`
- `docs/mvp-stage-progress.md`
- `docs/mvp-current-goal.md`
- `docs/architecture-decisions.md`

## Scope

Allowed artifacts:

- `docs/subtasks/060-fresh-data-alpha-root-visual-prd.md`
- `docs/subtasks/060-fresh-data-alpha-root-visual-progress.md`
- `docs/subtasks/screenshots/060-fresh-data-alpha-root-visual/*.png`
- process docs that record verification and delegation decisions

Do not modify:

- Swift source
- Tests
- Persistence, migrations, repositories, GRDB
- PromptProvider, prompt text, parser, LLM clients, Keychain
- Today, History, Projects, Growth, or Settings product semantics

## Acceptance Criteria

- The booted iPhone 17 simulator app data container is cleared by uninstalling the app before reinstall.
- Debug app installs and launches through the existing Subtask 059 root-tab selector.
- Screenshots are captured for Today, History, Projects, Growth, and Settings in light/dark mode.
- Projects root screenshot shows a fresh empty or evidence-gated state, not the prior `Visual QA` project fixture.
- History root screenshot shows no stale visual QA evidence.
- Growth and Settings remain readable in dark mode and are not unusably hidden by the floating tab.
- No source code changes are introduced.
- `git diff --check` passes after documentation updates.

## Delegation Decision

Claude Code is not delegated.

Reason:

- The user requested fast local implementation only.
- This is a simulator verification/documentation slice, not a coding slice.
- Codex must own final visual acceptance.
