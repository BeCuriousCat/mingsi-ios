# Subtask 062 PRD: Today Debug Seed Input

Date: 2026-06-06

## Goal

Add a minimal Debug-only Today launch seed so Codex can repeat the iPhone 17 rendered Today walkthrough without relying on unstable Simulator coordinate paste or keyboard automation.

Subtask 061 showed that the rendered app can advance from `验证昨日` to `今日输入`, but automated input into `CaptureTextView` is not repeatable from this host. This slice should let Debug simulator launches prefill Today capture text and mode through environment variables while preserving production behavior.

## Scope

Allowed source/test files:

- `Sources/App/AppStore.swift`
- `Sources/App/MingSiApp.swift`
- `Tests/App/AppStoreStateMachineTests.swift`

Allowed docs/screenshots:

- `docs/subtasks/062-today-debug-seed-input-prd.md`
- `docs/subtasks/062-today-debug-seed-input-progress.md`
- `docs/subtasks/screenshots/062-today-debug-seed-input/*.png`
- Process docs after acceptance

Do not modify:

- Persistence schema or migrations
- PromptProvider, prompt text, parser, LLM clients, Keychain
- Today AI semantics
- History, Projects, Growth, or Settings product behavior

## Required Behavior

- In Debug only, `MINGSI_VISUAL_QA_TODAY_INPUT` or `SIMCTL_CHILD_MINGSI_VISUAL_QA_TODAY_INPUT` can seed `todayDraft.rawText`.
- In Debug only, `MINGSI_VISUAL_QA_TODAY_MODE` or `SIMCTL_CHILD_MINGSI_VISUAL_QA_TODAY_MODE` can seed Quick / Standard / Deep.
- Applying the seed moves Today to `Capture`, selects Today tab, marks the mode selected, and disables persisted-state loading for that launch so the seed is not overwritten.
- Unknown/empty input does nothing.
- Unknown mode falls back to `standard` when input is provided.
- Release behavior must not read these variables.

## Acceptance Criteria

- Tests prove env resolution and store mutation.
- Tests prove normal stores still load persisted state on launch.
- `git diff --check` passes.
- Focused `AppStoreStateMachineTests` pass.
- iPhone 17 Debug launch screenshot shows seeded Today input.
- iPhone 17 walkthrough can click the main Today action and reach the organizing/card review path with local fallback visibly marked if no GLM key exists.

## Delegation Decision

Claude Code is not delegated for this slice.

Reason:

- This is a small local Debug harness fix immediately following a Codex-observed verification blocker.
- Codex can implement it faster than creating a worker package, and final simulator walkthrough remains a Codex responsibility.
