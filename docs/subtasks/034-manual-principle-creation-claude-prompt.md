# Claude Prompt: Subtask 034 Manual Principle Creation

You are the bounded implementation worker for Codex.

Invoke and follow the Claude skill `codex-delegated-worker` if available.

## Read First

1. `docs/subtasks/034-manual-principle-creation-prd.md`
2. `docs/subtasks/034-manual-principle-creation-progress.md`

Then inspect only targeted source ranges with `rg` and `sed`. Do not read huge Swift files end to end before marking `START`.

## Progress Contract

Update `docs/subtasks/034-manual-principle-creation-progress.md` at exactly:

- `START`
- `RED`
- `IMPLEMENTED`
- `TARGETED_VERIFIED`
- `HANDOFF`

At `HANDOFF`, include exactly one final status token:

- `DONE`
- `DONE_WITH_CONCERNS`
- `NEEDS_CONTEXT`
- `BLOCKED`

## Hard Boundaries

Allowed files:

- `Sources/App/AppStore.swift`
- `Sources/Features/FeatureTabs.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/subtasks/034-manual-principle-creation-progress.md`

Forbidden:

- Persistence migrations.
- `Sources/Services/PersistenceCore.swift`
- Prompt providers or prompt specs.
- LLM clients.
- Keychain code.
- Parser code.
- Project/Growth semantic model changes.
- Broad UI redesign.

## Required Implementation

Add direct manual Principle creation:

- AppStore action, preferably `addManualPrinciple(...) async -> Bool`.
- Required fields should be validated; missing required text should not create or persist a principle.
- Save the current `todayDraft` first when `DailyEntryRepository` exists.
- Save through existing `PrincipleRepository.savePrinciple`.
- Keep today's `principles` in memory aligned so current-day History can expose the principle.
- Maintain a Growth-visible active principle list, either by a dedicated published property or a clearly equivalent existing path.
- Add Growth UI entry:
  - `原则资产` section.
  - `添加原则` action.
  - sheet/form for title, summary, trigger context, actions one per line, success criteria, exceptions.
  - save is disabled or rejected when required content is missing.

Do not create fake AI provenance.

## TDD Requirement

Before production code, add failing tests in `Tests/App/AppStoreStateMachineTests.swift`:

1. Manual principle save persists an active principle and links it to today's DailyEntry.
2. Missing required text is rejected and does not create a principle.

Run the test command and record the expected failing result in `RED`.

## Required Verification

Run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test
```

If this is too slow, still run the focused new tests first, then the full AppStoreStateMachineTests before handoff.

## Final Handoff

Do not commit.

At `HANDOFF`, summarize:

- files changed
- tests run and result
- behavior implemented
- concerns or follow-up suggestions
