# Subtask 061 PRD: Today Core Loop Walkthrough

Date: 2026-06-06

## Goal

Verify whether a fresh MingSi Alpha build is actually usable through the core Today loop on a real iPhone 17 simulator, beyond first-viewport screenshots.

Subtasks 059 and 060 proved deterministic root-tab visuals. This slice checks whether the user can start with messy input and move into the AI/local-fallback card review path without being blocked by layout, missing state, or untestable interaction.

## Scope

Allowed artifacts:

- `docs/subtasks/061-today-core-loop-walkthrough-prd.md`
- `docs/subtasks/061-today-core-loop-walkthrough-progress.md`
- `docs/subtasks/screenshots/061-today-core-loop-walkthrough/*.png`
- Process docs if this slice is accepted

Do not modify unless a separate implementation slice is opened:

- Swift source
- Tests
- Persistence, migrations, repositories, GRDB
- PromptProvider, prompt text, parser, LLM clients, Keychain
- Today product semantics

## Verification Path

Minimum walkthrough:

1. Clear or reinstall app data on the booted iPhone 17 simulator.
2. Launch Today.
3. Enter a short non-sensitive reflection input.
4. Select Standard or use the current selected mode.
5. Trigger card organization.
6. Verify the user reaches an organizing/review-cards path with visible cards or visible AI/local-fallback failure state.
7. Capture screenshots at key states.

Stretch walkthrough if interaction remains stable:

- Confirm at least one card.
- Select the built-in `第一性原理` lens.
- Reach the question step and verify questions are visible or failure is visible/retryable.

## Acceptance Criteria

- The walkthrough evidence is captured on iPhone 17 simulator screenshots.
- If local fallback is used because no GLM API Key is configured, the state is recorded as fallback, not AI success.
- Any blocker is recorded with the exact state, screenshot, and next implementation slice.
- No fake data is presented as product evidence.
- No source changes are accepted without separate build/test verification.

## Delegation Decision

Claude Code is not delegated for initial walkthrough.

Reason:

- This is simulator interaction and product acceptance work.
- Codex must directly observe and judge the alpha usability path.
- If a narrow implementation bug is found, a later bounded slice can be delegated.
