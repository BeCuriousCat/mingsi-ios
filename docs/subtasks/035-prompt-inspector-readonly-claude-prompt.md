# Claude Prompt: Subtask 035 Prompt Inspector Read-Only View

You are the bounded implementation worker for Codex.

Invoke and follow the Claude skill `codex-delegated-worker` if available.

## Read First

1. `docs/subtasks/035-prompt-inspector-readonly-prd.md`
2. `docs/subtasks/035-prompt-inspector-readonly-progress.md`

Then inspect only targeted source ranges with `rg` and `sed`. Do not read huge Swift files end to end before marking `START`.

Suggested targeted reads:

- `Sources/Services/CoreProtocols.swift` around `PromptID`, `PromptTemplate`, `PromptProvider`, and `LocalPromptProvider`.
- `Sources/App/AppStore.swift` around Settings-related state and `loadRecentPromptRuns`.
- `Sources/Features/FeatureTabs.swift` around `SettingsView`, `promptAuditCard`, and `PromptRunAuditRow`.
- `Tests/Services/LocalPromptProviderTests.swift`.

## Progress Contract

Update `docs/subtasks/035-prompt-inspector-readonly-progress.md` at exactly:

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
- `Tests/Services/LocalPromptProviderTests.swift`
- `Tests/App/AppStoreStateMachineTests.swift` only if a helper is added there and needs coverage
- `docs/subtasks/035-prompt-inspector-readonly-progress.md`

Forbidden:

- Persistence migrations.
- `Sources/Services/PersistenceCore.swift`.
- Prompt text changes in `LocalPromptProvider`.
- LLM clients.
- Keychain code.
- Parser code.
- Historical retry behavior.
- Broad Settings redesign.

## Required Implementation

Implement exactly the PRD:

- Add a collapsed read-only `Prompt 模板` inspector in Settings.
- Prompt picker: all `PromptID` values.
- Mode picker: Quick / Standard / Deep.
- Metadata: prompt display name, raw id, version, output schema version, mode.
- Collapsible/disclosure display for system text.
- Collapsible/disclosure display for user text.
- Use existing `DS` tokens and Settings style.
- Do not expose API Key.
- Do not display user raw input through this inspector.
- Do not send any model request.
- Do not compose prompt literals in `FeatureTabs.swift`; obtain templates through `PromptProvider` / `LocalPromptProvider` via a small read-only boundary.

## TDD Requirement

Before production code, add a failing test in `Tests/Services/LocalPromptProviderTests.swift`:

- every `PromptID` for every `SessionMode` returns a non-empty `systemText`, non-empty `userText`, non-empty `version`, and positive `outputSchemaVersion`.

Run the focused test and record the expected failing or already-passing result in `RED`. If the existing provider already passes, record that RED is satisfied by the current missing UI gap plus the inventory test passing before UI work.

## Required Verification

Run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/LocalPromptProviderTests test
git diff --check
```

If you touch AppStore tests, run the touched focused AppStore test too.

## Final Handoff

Do not commit.

At `HANDOFF`, summarize:

- files changed;
- tests run and result;
- behavior implemented;
- any concerns or follow-up suggestions.
