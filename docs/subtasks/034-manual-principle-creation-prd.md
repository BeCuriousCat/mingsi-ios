# Subtask 034 PRD: Manual Principle Creation

Date: 2026-06-04

## Purpose

MingSi already lets AI propose one principle candidate at the end of Today. The missing alpha usability feature is direct manual Principle creation: the user should be able to add a reusable principle without waiting for an AI candidate.

This task dogfoods the reusable Codex-to-Claude Code delegation framework. The business requirements are MingSi-specific; the delegation framework must remain generic.

## User Value

The user can preserve a reusable behavior rule whenever they notice it, even if:

- today's AI principle extraction has not run,
- the AI candidate is absent,
- the user is reviewing Growth rather than completing Today's loop.

## Product Contract

- Manual principles are durable `PrincipleAsset` records.
- A manual principle is `active` by default.
- It must be linked to the current `DailyEntryDraft.id` as source evidence through the existing `PrincipleRepository.savePrinciple`.
- Do not add migrations.
- Do not create fake AI provenance.
- Do not call LLM or PromptProvider.
- Do not alter the Today state machine.
- Growth is the MVP entry point because UX docs define Growth as the principles asset entry.

## Expected UX

In Growth:

- Add a compact `原则资产` section.
- Show existing active principles when available.
- Provide an `添加原则` action.
- Present a sheet or modal form with:
  - title
  - summary
  - trigger context
  - actions, one per line
  - success criteria
  - exceptions
- Disable save or reject save when required content is missing.
- After save, dismiss the form and show the new principle in the active principles section.

## Data Behavior

- Add an AppStore action such as `addManualPrinciple(...) async -> Bool`.
- Persist the current `todayDraft` before saving the principle if a `DailyEntryRepository` exists.
- Save through existing `PrincipleRepository.savePrinciple`.
- Refresh active principles after save.
- Keep `store.principles` aligned for today's source record so History for the current day can show the principle.
- If persistence is unavailable, update in-memory state and show a clear message; do not pretend a database write happened.

## Allowed Files

- `Sources/App/AppStore.swift`
- `Sources/Features/FeatureTabs.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/subtasks/034-manual-principle-creation-progress.md`

## Forbidden Files

- Persistence migrations.
- `Sources/Services/PersistenceCore.swift`
- Prompt files/providers.
- LLM clients.
- Keychain code.
- Parser code.
- Project or Growth semantic model changes.

## Required Tests

Add focused AppStore tests:

1. Manual principle save persists an active principle and links it to today's DailyEntry.
2. Missing required text is rejected and does not create a principle.

Then run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test
```

## Manager Acceptance

Codex will accept only after:

- worker progress reaches `HANDOFF`,
- worker reports tests run,
- Codex reruns targeted tests,
- Codex runs `git diff --check`,
- Codex runs an iPhone 17 simulator build if the UI diff is accepted.
