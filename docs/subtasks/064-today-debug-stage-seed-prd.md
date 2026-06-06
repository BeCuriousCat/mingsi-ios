# Subtask 064 PRD: Today Debug Stage Seed

Date: 2026-06-06

## Goal

Add a narrow Debug-only Today stage seed so real iPhone 17 visual QA can continue after the Subtask 063 ReviewCards card-confirmation automation blocker.

This is a visual QA harness, not product semantics. It must not make local fallback look like AI success.

## Scope

Allowed files:

- `Sources/App/AppStore.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/subtasks/064-today-debug-stage-seed-prd.md`
- `docs/subtasks/064-today-debug-stage-seed-progress.md`
- `docs/subtasks/screenshots/064-today-debug-stage-seed/*.png`
- Process docs after acceptance

Do not modify:

- Persistence schema or migrations
- PromptProvider, prompt text, parser, LLM clients, Keychain
- History, Projects, Growth, or Settings behavior
- Today product semantics outside Debug-only visual QA launch seeding

## Debug Contract

Environment variables:

- `MINGSI_VISUAL_QA_TODAY_STAGE`
- `SIMCTL_CHILD_MINGSI_VISUAL_QA_TODAY_STAGE`

Accepted stage ids:

- `capture`
- `review_cards`
- `review_cards_confirmed`
- `select_lens`
- `answer_questions`
- `review_quests`
- `extract_principle`

Rules:

- Stage seed is effective only when `MINGSI_VISUAL_QA_TODAY_INPUT` or `SIMCTL_CHILD_MINGSI_VISUAL_QA_TODAY_INPUT` is non-empty.
- Unknown stage values fall back to `capture`.
- Stage seed must select Today, preserve seeded raw input and mode, skip persisted-state loading, and ignore stale Project Detail fixture markers.
- Seeded downstream artifacts must reuse existing local fallback generation helpers and visible fallback/audit messaging.
- Release builds must not read or apply these variables.

## Acceptance Criteria

- Tests prove stage seed does nothing without input.
- Tests prove `SIMCTL_CHILD_` variables are accepted.
- Tests prove `select_lens` seeds confirmed fallback cards and leaves the app ready to choose a lens.
- Tests prove `answer_questions`, `review_quests`, and `extract_principle` can seed the later Today states with the minimum valid local fallback artifacts.
- Focused tests pass.
- `git diff --check` passes.
- iPhone 17 simulator build passes.
- Real iPhone 17 screenshots show at least SelectLens and one later seeded Today stage.

## Delegation Decision

Claude Code is not delegated for this slice.

Reason:

- The user requested fast local implementation only.
- This is a small Debug-only testability harness plus manager-owned simulator acceptance.
- The implementation must be tightly aligned with current AppStore state-machine helpers.
