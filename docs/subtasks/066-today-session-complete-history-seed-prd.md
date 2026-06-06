# Subtask 066 PRD: Today Session Complete History Seed

Date: 2026-06-06

## Goal

Add a narrow Debug-only Today stage seed that can launch the rendered iPhone 17 app directly into `SessionComplete` and optionally open History with a complete in-memory evidence record.

This continues Subtask 065 after host Simulator automation could not click `保存原则`.

## Scope

Allowed files:

- `Sources/App/AppStore.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/subtasks/066-today-session-complete-history-seed-prd.md`
- `docs/subtasks/066-today-session-complete-history-seed-progress.md`
- `docs/subtasks/screenshots/066-today-session-complete-history-seed/*.png`
- Process docs after acceptance

Do not modify:

- Persistence schema or migrations
- PromptProvider, prompt text, parser, LLM clients, Keychain
- Production Today state-machine semantics
- History, Projects, Growth, or Settings product semantics

## Acceptance Criteria

- `MINGSI_VISUAL_QA_TODAY_STAGE=session_complete` and `SIMCTL_CHILD_MINGSI_VISUAL_QA_TODAY_STAGE=session_complete` are supported in Debug builds.
- The seed still requires non-empty `MINGSI_VISUAL_QA_TODAY_INPUT` or `SIMCTL_CHILD_MINGSI_VISUAL_QA_TODAY_INPUT`.
- The seeded complete state includes:
  - raw input
  - confirmed fallback cards
  - first-principles lens
  - at least one answered question
  - main quest
  - principle candidate
  - visible local fallback copy that does not claim AI success
- If `MINGSI_VISUAL_QA_TAB=history` or `SIMCTL_CHILD_MINGSI_VISUAL_QA_TAB=history` is present, the Today seed must honor that tab selection instead of forcing Today.
- History can render a complete in-memory evidence record for the seeded session.
- Focused RED/GREEN test proves the new stage was missing before implementation and passes after implementation.
- Full `AppStoreStateMachineTests`, `git diff --check`, Debug build, Release build, and real iPhone 17 simulator screenshots pass before acceptance.

## Non-Goals

- Do not claim live GLM success.
- Do not claim production persistence has been fully verified from this Debug-only seed.
- Do not solve host coordinate-click automation.
- Do not add UI test target or new automation framework.

## Delegation Decision

Claude Code is not delegated.

Reason:

- The user requested fast local implementation for the current window.
- This is a tiny Debug-only visual QA harness plus Codex-owned simulator verification.
