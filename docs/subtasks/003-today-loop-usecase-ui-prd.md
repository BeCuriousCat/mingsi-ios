# Subtask 003: Today Loop Use Case and UI PRD

## Owner

Worker agent: Today loop orchestration and minimal interaction.

## Context

The Today screen currently advances through placeholder states with preview cards. MVP needs a usable local loop even before real GLM integration is fully polished. The goal is to make the existing UI flow feel coherent and enforce the core training loop.

## Scope

Allowed write scope:

- `Sources/App/AppStore.swift`
- `Sources/Features/Today/TodayView.swift`
- new files under `Sources/Features/Today/`
- small domain additions in `Sources/Domain/Models.swift` if needed

Do not edit:

- GRDB repository internals
- GLM networking internals
- `Vendor/GRDB.swift`

## Requirements

1. Replace blind "advance" behavior with state-aware actions:
   - Verify yesterday saves verification choice.
   - Capture requires non-empty input before organizing.
   - Organizing generates mock cards if LLM is unavailable.
   - Review cards allows confirm/exclude/delete at minimum.
   - Select mode updates session mode.
   - Select lens stores selected lens.
   - Answer questions requires at least one answer.
   - Review quests requires one main quest with completion criteria.
   - Extract principle allows save or skip.
2. Preserve Quick / Standard / Deep mode in the flow.
3. Keep interaction native and simple. No heavy animation in MVP, but use stable IDs and avoid layout jumps.
4. Maintain privacy guardrails in capture.
5. Do not let non-Today tabs become alternate ways to mutate the active loop.

## Architecture Constraints

- AppStore may orchestrate MVP use cases for now, but UI should call intent-like methods rather than mutate many fields directly.
- Keep generated card/quest/principle data in domain models, not UI-only structs.
- No direct GRDB or GLM calls from `TodayView`.

## Acceptance Criteria

- Build succeeds.
- User can complete a full loop using mock data and end in `sessionComplete`.
- Empty capture input blocks progression with a visible message.
- At least one answered question is required before task generation.
- Main quest completion criteria is visible before completion.

## Final Response Required

List:

- files changed
- user flow now supported
- commands run and whether they passed
- risks left for Codex review
